// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MapsTable extends Maps with TableInfo<$MapsTable, MapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageFileMeta = const VerificationMeta(
    'imageFile',
  );
  @override
  late final GeneratedColumn<String> imageFile = GeneratedColumn<String>(
    'image_file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthPxMeta = const VerificationMeta(
    'widthPx',
  );
  @override
  late final GeneratedColumn<int> widthPx = GeneratedColumn<int>(
    'width_px',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightPxMeta = const VerificationMeta(
    'heightPx',
  );
  @override
  late final GeneratedColumn<int> heightPx = GeneratedColumn<int>(
    'height_px',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tileMaxZoomMeta = const VerificationMeta(
    'tileMaxZoom',
  );
  @override
  late final GeneratedColumn<int> tileMaxZoom = GeneratedColumn<int>(
    'tile_max_zoom',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    imageFile,
    widthPx,
    heightPx,
    createdAt,
    tileMaxZoom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<MapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image_file')) {
      context.handle(
        _imageFileMeta,
        imageFile.isAcceptableOrUnknown(data['image_file']!, _imageFileMeta),
      );
    } else if (isInserting) {
      context.missing(_imageFileMeta);
    }
    if (data.containsKey('width_px')) {
      context.handle(
        _widthPxMeta,
        widthPx.isAcceptableOrUnknown(data['width_px']!, _widthPxMeta),
      );
    } else if (isInserting) {
      context.missing(_widthPxMeta);
    }
    if (data.containsKey('height_px')) {
      context.handle(
        _heightPxMeta,
        heightPx.isAcceptableOrUnknown(data['height_px']!, _heightPxMeta),
      );
    } else if (isInserting) {
      context.missing(_heightPxMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('tile_max_zoom')) {
      context.handle(
        _tileMaxZoomMeta,
        tileMaxZoom.isAcceptableOrUnknown(
          data['tile_max_zoom']!,
          _tileMaxZoomMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MapRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      imageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_file'],
      )!,
      widthPx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width_px'],
      )!,
      heightPx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height_px'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      tileMaxZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tile_max_zoom'],
      ),
    );
  }

  @override
  $MapsTable createAlias(String alias) {
    return $MapsTable(attachedDatabase, alias);
  }
}

class MapRow extends DataClass implements Insertable<MapRow> {
  final String id;
  final String name;

  /// Image path relative to the app documents directory, which can move
  /// between app updates on iOS.
  final String imageFile;
  final int widthPx;
  final int heightPx;
  final DateTime createdAt;

  /// Top zoom level of the tile pyramid in `tiles/` next to the image, or
  /// null when the map is small enough to be drawn as a single image.
  final int? tileMaxZoom;
  const MapRow({
    required this.id,
    required this.name,
    required this.imageFile,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
    this.tileMaxZoom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['image_file'] = Variable<String>(imageFile);
    map['width_px'] = Variable<int>(widthPx);
    map['height_px'] = Variable<int>(heightPx);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || tileMaxZoom != null) {
      map['tile_max_zoom'] = Variable<int>(tileMaxZoom);
    }
    return map;
  }

  MapsCompanion toCompanion(bool nullToAbsent) {
    return MapsCompanion(
      id: Value(id),
      name: Value(name),
      imageFile: Value(imageFile),
      widthPx: Value(widthPx),
      heightPx: Value(heightPx),
      createdAt: Value(createdAt),
      tileMaxZoom: tileMaxZoom == null && nullToAbsent
          ? const Value.absent()
          : Value(tileMaxZoom),
    );
  }

  factory MapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MapRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      imageFile: serializer.fromJson<String>(json['imageFile']),
      widthPx: serializer.fromJson<int>(json['widthPx']),
      heightPx: serializer.fromJson<int>(json['heightPx']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      tileMaxZoom: serializer.fromJson<int?>(json['tileMaxZoom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'imageFile': serializer.toJson<String>(imageFile),
      'widthPx': serializer.toJson<int>(widthPx),
      'heightPx': serializer.toJson<int>(heightPx),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'tileMaxZoom': serializer.toJson<int?>(tileMaxZoom),
    };
  }

  MapRow copyWith({
    String? id,
    String? name,
    String? imageFile,
    int? widthPx,
    int? heightPx,
    DateTime? createdAt,
    Value<int?> tileMaxZoom = const Value.absent(),
  }) => MapRow(
    id: id ?? this.id,
    name: name ?? this.name,
    imageFile: imageFile ?? this.imageFile,
    widthPx: widthPx ?? this.widthPx,
    heightPx: heightPx ?? this.heightPx,
    createdAt: createdAt ?? this.createdAt,
    tileMaxZoom: tileMaxZoom.present ? tileMaxZoom.value : this.tileMaxZoom,
  );
  MapRow copyWithCompanion(MapsCompanion data) {
    return MapRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      imageFile: data.imageFile.present ? data.imageFile.value : this.imageFile,
      widthPx: data.widthPx.present ? data.widthPx.value : this.widthPx,
      heightPx: data.heightPx.present ? data.heightPx.value : this.heightPx,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      tileMaxZoom: data.tileMaxZoom.present
          ? data.tileMaxZoom.value
          : this.tileMaxZoom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MapRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imageFile: $imageFile, ')
          ..write('widthPx: $widthPx, ')
          ..write('heightPx: $heightPx, ')
          ..write('createdAt: $createdAt, ')
          ..write('tileMaxZoom: $tileMaxZoom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    imageFile,
    widthPx,
    heightPx,
    createdAt,
    tileMaxZoom,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.imageFile == this.imageFile &&
          other.widthPx == this.widthPx &&
          other.heightPx == this.heightPx &&
          other.createdAt == this.createdAt &&
          other.tileMaxZoom == this.tileMaxZoom);
}

class MapsCompanion extends UpdateCompanion<MapRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> imageFile;
  final Value<int> widthPx;
  final Value<int> heightPx;
  final Value<DateTime> createdAt;
  final Value<int?> tileMaxZoom;
  final Value<int> rowid;
  const MapsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.imageFile = const Value.absent(),
    this.widthPx = const Value.absent(),
    this.heightPx = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.tileMaxZoom = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MapsCompanion.insert({
    required String id,
    required String name,
    required String imageFile,
    required int widthPx,
    required int heightPx,
    required DateTime createdAt,
    this.tileMaxZoom = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       imageFile = Value(imageFile),
       widthPx = Value(widthPx),
       heightPx = Value(heightPx),
       createdAt = Value(createdAt);
  static Insertable<MapRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? imageFile,
    Expression<int>? widthPx,
    Expression<int>? heightPx,
    Expression<DateTime>? createdAt,
    Expression<int>? tileMaxZoom,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (imageFile != null) 'image_file': imageFile,
      if (widthPx != null) 'width_px': widthPx,
      if (heightPx != null) 'height_px': heightPx,
      if (createdAt != null) 'created_at': createdAt,
      if (tileMaxZoom != null) 'tile_max_zoom': tileMaxZoom,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MapsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? imageFile,
    Value<int>? widthPx,
    Value<int>? heightPx,
    Value<DateTime>? createdAt,
    Value<int?>? tileMaxZoom,
    Value<int>? rowid,
  }) {
    return MapsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      imageFile: imageFile ?? this.imageFile,
      widthPx: widthPx ?? this.widthPx,
      heightPx: heightPx ?? this.heightPx,
      createdAt: createdAt ?? this.createdAt,
      tileMaxZoom: tileMaxZoom ?? this.tileMaxZoom,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imageFile.present) {
      map['image_file'] = Variable<String>(imageFile.value);
    }
    if (widthPx.present) {
      map['width_px'] = Variable<int>(widthPx.value);
    }
    if (heightPx.present) {
      map['height_px'] = Variable<int>(heightPx.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (tileMaxZoom.present) {
      map['tile_max_zoom'] = Variable<int>(tileMaxZoom.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MapsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imageFile: $imageFile, ')
          ..write('widthPx: $widthPx, ')
          ..write('heightPx: $heightPx, ')
          ..write('createdAt: $createdAt, ')
          ..write('tileMaxZoom: $tileMaxZoom, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarkersTable extends Markers with TableInfo<$MarkersTable, MarkerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mapIdMeta = const VerificationMeta('mapId');
  @override
  late final GeneratedColumn<String> mapId = GeneratedColumn<String>(
    'map_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES maps (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mapId,
    x,
    y,
    label,
    description,
    colorValue,
    createdAt,
    icon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'markers';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarkerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('map_id')) {
      context.handle(
        _mapIdMeta,
        mapId.isAcceptableOrUnknown(data['map_id']!, _mapIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mapIdMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MarkerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarkerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}map_id'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
    );
  }

  @override
  $MarkersTable createAlias(String alias) {
    return $MarkersTable(attachedDatabase, alias);
  }
}

class MarkerRow extends DataClass implements Insertable<MarkerRow> {
  final String id;
  final String mapId;

  /// Position normalized to the image (0..1, origin top-left).
  final double x;
  final double y;
  final String label;
  final String? description;

  /// ARGB color value.
  final int colorValue;
  final DateTime createdAt;

  /// Key from `markerIcons`, or null for the plain pin.
  final String? icon;
  const MarkerRow({
    required this.id,
    required this.mapId,
    required this.x,
    required this.y,
    required this.label,
    this.description,
    required this.colorValue,
    required this.createdAt,
    this.icon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['map_id'] = Variable<String>(mapId);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    return map;
  }

  MarkersCompanion toCompanion(bool nullToAbsent) {
    return MarkersCompanion(
      id: Value(id),
      mapId: Value(mapId),
      x: Value(x),
      y: Value(y),
      label: Value(label),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      colorValue: Value(colorValue),
      createdAt: Value(createdAt),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
    );
  }

  factory MarkerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarkerRow(
      id: serializer.fromJson<String>(json['id']),
      mapId: serializer.fromJson<String>(json['mapId']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      label: serializer.fromJson<String>(json['label']),
      description: serializer.fromJson<String?>(json['description']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      icon: serializer.fromJson<String?>(json['icon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mapId': serializer.toJson<String>(mapId),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'label': serializer.toJson<String>(label),
      'description': serializer.toJson<String?>(description),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'icon': serializer.toJson<String?>(icon),
    };
  }

  MarkerRow copyWith({
    String? id,
    String? mapId,
    double? x,
    double? y,
    String? label,
    Value<String?> description = const Value.absent(),
    int? colorValue,
    DateTime? createdAt,
    Value<String?> icon = const Value.absent(),
  }) => MarkerRow(
    id: id ?? this.id,
    mapId: mapId ?? this.mapId,
    x: x ?? this.x,
    y: y ?? this.y,
    label: label ?? this.label,
    description: description.present ? description.value : this.description,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt ?? this.createdAt,
    icon: icon.present ? icon.value : this.icon,
  );
  MarkerRow copyWithCompanion(MarkersCompanion data) {
    return MarkerRow(
      id: data.id.present ? data.id.value : this.id,
      mapId: data.mapId.present ? data.mapId.value : this.mapId,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      label: data.label.present ? data.label.value : this.label,
      description: data.description.present
          ? data.description.value
          : this.description,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      icon: data.icon.present ? data.icon.value : this.icon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarkerRow(')
          ..write('id: $id, ')
          ..write('mapId: $mapId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('label: $label, ')
          ..write('description: $description, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('icon: $icon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mapId,
    x,
    y,
    label,
    description,
    colorValue,
    createdAt,
    icon,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkerRow &&
          other.id == this.id &&
          other.mapId == this.mapId &&
          other.x == this.x &&
          other.y == this.y &&
          other.label == this.label &&
          other.description == this.description &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt &&
          other.icon == this.icon);
}

class MarkersCompanion extends UpdateCompanion<MarkerRow> {
  final Value<String> id;
  final Value<String> mapId;
  final Value<double> x;
  final Value<double> y;
  final Value<String> label;
  final Value<String?> description;
  final Value<int> colorValue;
  final Value<DateTime> createdAt;
  final Value<String?> icon;
  final Value<int> rowid;
  const MarkersCompanion({
    this.id = const Value.absent(),
    this.mapId = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.label = const Value.absent(),
    this.description = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.icon = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarkersCompanion.insert({
    required String id,
    required String mapId,
    required double x,
    required double y,
    required String label,
    this.description = const Value.absent(),
    required int colorValue,
    required DateTime createdAt,
    this.icon = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mapId = Value(mapId),
       x = Value(x),
       y = Value(y),
       label = Value(label),
       colorValue = Value(colorValue),
       createdAt = Value(createdAt);
  static Insertable<MarkerRow> custom({
    Expression<String>? id,
    Expression<String>? mapId,
    Expression<double>? x,
    Expression<double>? y,
    Expression<String>? label,
    Expression<String>? description,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
    Expression<String>? icon,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mapId != null) 'map_id': mapId,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (label != null) 'label': label,
      if (description != null) 'description': description,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
      if (icon != null) 'icon': icon,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarkersCompanion copyWith({
    Value<String>? id,
    Value<String>? mapId,
    Value<double>? x,
    Value<double>? y,
    Value<String>? label,
    Value<String?>? description,
    Value<int>? colorValue,
    Value<DateTime>? createdAt,
    Value<String?>? icon,
    Value<int>? rowid,
  }) {
    return MarkersCompanion(
      id: id ?? this.id,
      mapId: mapId ?? this.mapId,
      x: x ?? this.x,
      y: y ?? this.y,
      label: label ?? this.label,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      icon: icon ?? this.icon,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mapId.present) {
      map['map_id'] = Variable<String>(mapId.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkersCompanion(')
          ..write('id: $id, ')
          ..write('mapId: $mapId, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('label: $label, ')
          ..write('description: $description, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('icon: $icon, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LegendTable extends Legend with TableInfo<$LegendTable, LegendRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LegendTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mapIdMeta = const VerificationMeta('mapId');
  @override
  late final GeneratedColumn<String> mapId = GeneratedColumn<String>(
    'map_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES maps (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [mapId, colorValue, name, hidden];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'legend';
  @override
  VerificationContext validateIntegrity(
    Insertable<LegendRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('map_id')) {
      context.handle(
        _mapIdMeta,
        mapId.isAcceptableOrUnknown(data['map_id']!, _mapIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mapIdMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mapId, colorValue};
  @override
  LegendRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LegendRow(
      mapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}map_id'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $LegendTable createAlias(String alias) {
    return $LegendTable(attachedDatabase, alias);
  }
}

class LegendRow extends DataClass implements Insertable<LegendRow> {
  final String mapId;

  /// ARGB color value, as in [Markers.colorValue].
  final int colorValue;
  final String? name;
  final bool hidden;
  const LegendRow({
    required this.mapId,
    required this.colorValue,
    this.name,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['map_id'] = Variable<String>(mapId);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  LegendCompanion toCompanion(bool nullToAbsent) {
    return LegendCompanion(
      mapId: Value(mapId),
      colorValue: Value(colorValue),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      hidden: Value(hidden),
    );
  }

  factory LegendRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LegendRow(
      mapId: serializer.fromJson<String>(json['mapId']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      name: serializer.fromJson<String?>(json['name']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mapId': serializer.toJson<String>(mapId),
      'colorValue': serializer.toJson<int>(colorValue),
      'name': serializer.toJson<String?>(name),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  LegendRow copyWith({
    String? mapId,
    int? colorValue,
    Value<String?> name = const Value.absent(),
    bool? hidden,
  }) => LegendRow(
    mapId: mapId ?? this.mapId,
    colorValue: colorValue ?? this.colorValue,
    name: name.present ? name.value : this.name,
    hidden: hidden ?? this.hidden,
  );
  LegendRow copyWithCompanion(LegendCompanion data) {
    return LegendRow(
      mapId: data.mapId.present ? data.mapId.value : this.mapId,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      name: data.name.present ? data.name.value : this.name,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LegendRow(')
          ..write('mapId: $mapId, ')
          ..write('colorValue: $colorValue, ')
          ..write('name: $name, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mapId, colorValue, name, hidden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LegendRow &&
          other.mapId == this.mapId &&
          other.colorValue == this.colorValue &&
          other.name == this.name &&
          other.hidden == this.hidden);
}

class LegendCompanion extends UpdateCompanion<LegendRow> {
  final Value<String> mapId;
  final Value<int> colorValue;
  final Value<String?> name;
  final Value<bool> hidden;
  final Value<int> rowid;
  const LegendCompanion({
    this.mapId = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.name = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LegendCompanion.insert({
    required String mapId,
    required int colorValue,
    this.name = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mapId = Value(mapId),
       colorValue = Value(colorValue);
  static Insertable<LegendRow> custom({
    Expression<String>? mapId,
    Expression<int>? colorValue,
    Expression<String>? name,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mapId != null) 'map_id': mapId,
      if (colorValue != null) 'color_value': colorValue,
      if (name != null) 'name': name,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LegendCompanion copyWith({
    Value<String>? mapId,
    Value<int>? colorValue,
    Value<String?>? name,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return LegendCompanion(
      mapId: mapId ?? this.mapId,
      colorValue: colorValue ?? this.colorValue,
      name: name ?? this.name,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mapId.present) {
      map['map_id'] = Variable<String>(mapId.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LegendCompanion(')
          ..write('mapId: $mapId, ')
          ..write('colorValue: $colorValue, ')
          ..write('name: $name, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MapsTable maps = $MapsTable(this);
  late final $MarkersTable markers = $MarkersTable(this);
  late final $LegendTable legend = $LegendTable(this);
  late final Index markersMapId = Index(
    'markers_map_id',
    'CREATE INDEX markers_map_id ON markers (map_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    maps,
    markers,
    legend,
    markersMapId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'maps',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('markers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'maps',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('legend', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MapsTableCreateCompanionBuilder = MapsCompanion Function({
  required String id,
  required String name,
  required String imageFile,
  required int widthPx,
  required int heightPx,
  required DateTime createdAt,
  Value<int?> tileMaxZoom,
  Value<int> rowid,
});
typedef $$MapsTableUpdateCompanionBuilder = MapsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> imageFile,
  Value<int> widthPx,
  Value<int> heightPx,
  Value<DateTime> createdAt,
  Value<int?> tileMaxZoom,
  Value<int> rowid,
});

final class $$MapsTableReferences
    extends BaseReferences<_$AppDatabase, $MapsTable, MapRow> {
  $$MapsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MarkersTable, List<MarkerRow>> _markersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.markers,
    aliasName: 'maps__id__markers__map_id',
  );

  $$MarkersTableProcessedTableManager get markersRefs {
    final manager = $$MarkersTableTableManager(
      $_db,
      $_db.markers,
    ).filter((f) => f.mapId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_markersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LegendTable, List<LegendRow>> _legendRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.legend,
    aliasName: 'maps__id__legend__map_id',
  );

  $$LegendTableProcessedTableManager get legendRefs {
    final manager = $$LegendTableTableManager(
      $_db,
      $_db.legend,
    ).filter((f) => f.mapId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_legendRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MapsTableFilterComposer extends Composer<_$AppDatabase, $MapsTable> {
  $$MapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get widthPx => $composableBuilder(
    column: $table.widthPx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightPx => $composableBuilder(
    column: $table.heightPx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tileMaxZoom => $composableBuilder(
    column: $table.tileMaxZoom,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> markersRefs(
    Expression<bool> Function($$MarkersTableFilterComposer f) f,
  ) {
    final $$MarkersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarkersTableFilterComposer(
            $db: $db,
            $table: $db.markers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> legendRefs(
    Expression<bool> Function($$LegendTableFilterComposer f) f,
  ) {
    final $$LegendTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.legend,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LegendTableFilterComposer(
            $db: $db,
            $table: $db.legend,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MapsTableOrderingComposer extends Composer<_$AppDatabase, $MapsTable> {
  $$MapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get widthPx => $composableBuilder(
    column: $table.widthPx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightPx => $composableBuilder(
    column: $table.heightPx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tileMaxZoom => $composableBuilder(
    column: $table.tileMaxZoom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MapsTable> {
  $$MapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imageFile =>
      $composableBuilder(column: $table.imageFile, builder: (column) => column);

  GeneratedColumn<int> get widthPx =>
      $composableBuilder(column: $table.widthPx, builder: (column) => column);

  GeneratedColumn<int> get heightPx =>
      $composableBuilder(column: $table.heightPx, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get tileMaxZoom => $composableBuilder(
    column: $table.tileMaxZoom,
    builder: (column) => column,
  );

  Expression<T> markersRefs<T extends Object>(
    Expression<T> Function($$MarkersTableAnnotationComposer a) f,
  ) {
    final $$MarkersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarkersTableAnnotationComposer(
            $db: $db,
            $table: $db.markers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> legendRefs<T extends Object>(
    Expression<T> Function($$LegendTableAnnotationComposer a) f,
  ) {
    final $$LegendTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.legend,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LegendTableAnnotationComposer(
            $db: $db,
            $table: $db.legend,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MapsTable,
          MapRow,
          $$MapsTableFilterComposer,
          $$MapsTableOrderingComposer,
          $$MapsTableAnnotationComposer,
          $$MapsTableCreateCompanionBuilder,
          $$MapsTableUpdateCompanionBuilder,
          (MapRow, $$MapsTableReferences),
          MapRow,
          PrefetchHooks Function({bool markersRefs, bool legendRefs})
        > {
  $$MapsTableTableManager(_$AppDatabase db, $MapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> imageFile = const Value.absent(),
                Value<int> widthPx = const Value.absent(),
                Value<int> heightPx = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> tileMaxZoom = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MapsCompanion(
                id: id,
                name: name,
                imageFile: imageFile,
                widthPx: widthPx,
                heightPx: heightPx,
                createdAt: createdAt,
                tileMaxZoom: tileMaxZoom,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String imageFile,
                required int widthPx,
                required int heightPx,
                required DateTime createdAt,
                Value<int?> tileMaxZoom = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MapsCompanion.insert(
                id: id,
                name: name,
                imageFile: imageFile,
                widthPx: widthPx,
                heightPx: heightPx,
                createdAt: createdAt,
                tileMaxZoom: tileMaxZoom,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MapsTable, MapRow>(table),
                  $$MapsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({markersRefs = false, legendRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (markersRefs) db.markers,
                if (legendRefs) db.legend,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (markersRefs)
                    await $_getPrefetchedData<MapRow, $MapsTable, MarkerRow>(
                      currentTable: table,
                      referencedTable: $$MapsTableReferences._markersRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$MapsTableReferences(db, table, p0).markersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mapId == item.id),
                      typedResults: items,
                    ),
                  if (legendRefs)
                    await $_getPrefetchedData<MapRow, $MapsTable, LegendRow>(
                      currentTable: table,
                      referencedTable: $$MapsTableReferences._legendRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$MapsTableReferences(db, table, p0).legendRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mapId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MapsTable,
      MapRow,
      $$MapsTableFilterComposer,
      $$MapsTableOrderingComposer,
      $$MapsTableAnnotationComposer,
      $$MapsTableCreateCompanionBuilder,
      $$MapsTableUpdateCompanionBuilder,
      (MapRow, $$MapsTableReferences),
      MapRow,
      PrefetchHooks Function({bool markersRefs, bool legendRefs})
    >;
typedef $$MarkersTableCreateCompanionBuilder = MarkersCompanion Function({
  required String id,
  required String mapId,
  required double x,
  required double y,
  required String label,
  Value<String?> description,
  required int colorValue,
  required DateTime createdAt,
  Value<String?> icon,
  Value<int> rowid,
});
typedef $$MarkersTableUpdateCompanionBuilder = MarkersCompanion Function({
  Value<String> id,
  Value<String> mapId,
  Value<double> x,
  Value<double> y,
  Value<String> label,
  Value<String?> description,
  Value<int> colorValue,
  Value<DateTime> createdAt,
  Value<String?> icon,
  Value<int> rowid,
});

final class $$MarkersTableReferences
    extends BaseReferences<_$AppDatabase, $MarkersTable, MarkerRow> {
  $$MarkersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MapsTable _mapIdTable(_$AppDatabase db) =>
      db.maps.createAlias('markers__map_id__maps__id');

  $$MapsTableProcessedTableManager get mapId {
    final $_column = $_itemColumn<String>('map_id')!;

    final manager = $$MapsTableTableManager(
      $_db,
      $_db.maps,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mapIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MarkersTableFilterComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  $$MapsTableFilterComposer get mapId {
    final $$MapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.maps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapsTableFilterComposer(
            $db: $db,
            $table: $db.maps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableOrderingComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  $$MapsTableOrderingComposer get mapId {
    final $$MapsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.maps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapsTableOrderingComposer(
            $db: $db,
            $table: $db.maps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  $$MapsTableAnnotationComposer get mapId {
    final $$MapsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.maps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapsTableAnnotationComposer(
            $db: $db,
            $table: $db.maps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarkersTable,
          MarkerRow,
          $$MarkersTableFilterComposer,
          $$MarkersTableOrderingComposer,
          $$MarkersTableAnnotationComposer,
          $$MarkersTableCreateCompanionBuilder,
          $$MarkersTableUpdateCompanionBuilder,
          (MarkerRow, $$MarkersTableReferences),
          MarkerRow,
          PrefetchHooks Function({bool mapId})
        > {
  $$MarkersTableTableManager(_$AppDatabase db, $MarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mapId = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarkersCompanion(
                id: id,
                mapId: mapId,
                x: x,
                y: y,
                label: label,
                description: description,
                colorValue: colorValue,
                createdAt: createdAt,
                icon: icon,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mapId,
                required double x,
                required double y,
                required String label,
                Value<String?> description = const Value.absent(),
                required int colorValue,
                required DateTime createdAt,
                Value<String?> icon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarkersCompanion.insert(
                id: id,
                mapId: mapId,
                x: x,
                y: y,
                label: label,
                description: description,
                colorValue: colorValue,
                createdAt: createdAt,
                icon: icon,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MarkersTable, MarkerRow>(table),
                  $$MarkersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mapId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mapId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.mapId,
                        referencedTable: $$MarkersTableReferences._mapIdTable(
                          db,
                        ),
                        referencedColumn: $$MarkersTableReferences
                            ._mapIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarkersTable,
      MarkerRow,
      $$MarkersTableFilterComposer,
      $$MarkersTableOrderingComposer,
      $$MarkersTableAnnotationComposer,
      $$MarkersTableCreateCompanionBuilder,
      $$MarkersTableUpdateCompanionBuilder,
      (MarkerRow, $$MarkersTableReferences),
      MarkerRow,
      PrefetchHooks Function({bool mapId})
    >;
typedef $$LegendTableCreateCompanionBuilder = LegendCompanion Function({
  required String mapId,
  required int colorValue,
  Value<String?> name,
  Value<bool> hidden,
  Value<int> rowid,
});
typedef $$LegendTableUpdateCompanionBuilder = LegendCompanion Function({
  Value<String> mapId,
  Value<int> colorValue,
  Value<String?> name,
  Value<bool> hidden,
  Value<int> rowid,
});

final class $$LegendTableReferences
    extends BaseReferences<_$AppDatabase, $LegendTable, LegendRow> {
  $$LegendTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MapsTable _mapIdTable(_$AppDatabase db) =>
      db.maps.createAlias('legend__map_id__maps__id');

  $$MapsTableProcessedTableManager get mapId {
    final $_column = $_itemColumn<String>('map_id')!;

    final manager = $$MapsTableTableManager(
      $_db,
      $_db.maps,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mapIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LegendTableFilterComposer
    extends Composer<_$AppDatabase, $LegendTable> {
  $$LegendTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  $$MapsTableFilterComposer get mapId {
    final $$MapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.maps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapsTableFilterComposer(
            $db: $db,
            $table: $db.maps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LegendTableOrderingComposer
    extends Composer<_$AppDatabase, $LegendTable> {
  $$LegendTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  $$MapsTableOrderingComposer get mapId {
    final $$MapsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.maps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapsTableOrderingComposer(
            $db: $db,
            $table: $db.maps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LegendTableAnnotationComposer
    extends Composer<_$AppDatabase, $LegendTable> {
  $$LegendTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  $$MapsTableAnnotationComposer get mapId {
    final $$MapsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.maps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapsTableAnnotationComposer(
            $db: $db,
            $table: $db.maps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LegendTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LegendTable,
          LegendRow,
          $$LegendTableFilterComposer,
          $$LegendTableOrderingComposer,
          $$LegendTableAnnotationComposer,
          $$LegendTableCreateCompanionBuilder,
          $$LegendTableUpdateCompanionBuilder,
          (LegendRow, $$LegendTableReferences),
          LegendRow,
          PrefetchHooks Function({bool mapId})
        > {
  $$LegendTableTableManager(_$AppDatabase db, $LegendTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LegendTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LegendTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LegendTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mapId = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LegendCompanion(
                mapId: mapId,
                colorValue: colorValue,
                name: name,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mapId,
                required int colorValue,
                Value<String?> name = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LegendCompanion.insert(
                mapId: mapId,
                colorValue: colorValue,
                name: name,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LegendTable, LegendRow>(table),
                  $$LegendTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mapId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mapId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.mapId,
                        referencedTable: $$LegendTableReferences._mapIdTable(
                          db,
                        ),
                        referencedColumn: $$LegendTableReferences
                            ._mapIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LegendTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LegendTable,
      LegendRow,
      $$LegendTableFilterComposer,
      $$LegendTableOrderingComposer,
      $$LegendTableAnnotationComposer,
      $$LegendTableCreateCompanionBuilder,
      $$LegendTableUpdateCompanionBuilder,
      (LegendRow, $$LegendTableReferences),
      LegendRow,
      PrefetchHooks Function({bool mapId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MapsTableTableManager get maps => $$MapsTableTableManager(_db, _db.maps);
  $$MarkersTableTableManager get markers =>
      $$MarkersTableTableManager(_db, _db.markers);
  $$LegendTableTableManager get legend =>
      $$LegendTableTableManager(_db, _db.legend);
}
