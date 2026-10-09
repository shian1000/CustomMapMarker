import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// A file opened in this app from another one ("Open with…", "Share"),
/// already copied to a local [path], or the [error] that prevented that.
typedef IncomingFile = ({String? path, String? error});

/// Map files opened from other apps (see android/.../IncomingFiles.kt). The
/// platform side copies each file into the cache; whoever imports it deletes
/// the copy afterwards.
class IncomingFiles {
  const IncomingFiles();

  static const _channel = MethodChannel('custom_map_marker/incoming');

  /// Files received so far and from now on, including the one the app was
  /// launched with. Listen to it only once.
  Stream<IncomingFile> files() {
    if (!Platform.isAndroid) return const Stream.empty();
    late final StreamController<IncomingFile> controller;

    Future<void> takePending() async {
      final pending = await _channel.invokeListMethod<Map>('takePending');
      for (final entry in pending ?? const <Map>[]) {
        controller.add((
          path: entry['path'] as String?,
          error: entry['error'] as String?,
        ));
      }
    }

    controller = StreamController(
      onListen: () {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'filesAvailable') await takePending();
        });
        takePending();
      },
      onCancel: () => _channel.setMethodCallHandler(null),
    );
    return controller.stream;
  }
}
