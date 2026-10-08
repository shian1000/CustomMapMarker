import 'dart:isolate';

/// Runs [task] in a new isolate, forwarding the progress it reports to
/// [onProgress] on the calling isolate. [task] must be sendable (e.g. a
/// top-level function or a closure capturing only sendable values).
Future<T> runWithProgress<T>(
  T Function(void Function(double progress) report) task, {
  void Function(double progress)? onProgress,
}) async {
  final port = ReceivePort();
  final subscription = port.listen((p) => onProgress?.call(p as double));
  try {
    return await _runInIsolate(task, port.sendPort);
  } finally {
    await subscription.cancel();
    port.close();
  }
}

// Separate function so the isolate closure's context holds only [task] and
// [sendPort], not the ReceivePort or [onProgress] from the caller.
Future<T> _runInIsolate<T>(
  T Function(void Function(double progress) report) task,
  SendPort sendPort,
) => Isolate.run(() => task(sendPort.send));
