// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, AppMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaData extends DataClass implements Insertable<AppMetaData> {
  final int id;
  final String key;
  final String? value;
  const AppMetaData({required this.id, required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(
      id: Value(id),
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaData(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppMetaData copyWith({
    int? id,
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppMetaData(
    id: id ?? this.id,
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppMetaData copyWithCompanion(AppMetaCompanion data) {
    return AppMetaData(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaData(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaData &&
          other.id == this.id &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaData> {
  final Value<int> id;
  final Value<String> key;
  final Value<String?> value;
  const AppMetaCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  AppMetaCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    this.value = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppMetaData> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  AppMetaCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String?>? value,
  }) {
    return AppMetaCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $VehicleRecordsTable extends VehicleRecords
    with TableInfo<$VehicleRecordsTable, VehicleRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
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
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licensePlateMeta = const VerificationMeta(
    'licensePlate',
  );
  @override
  late final GeneratedColumn<String> licensePlate = GeneratedColumn<String>(
    'license_plate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vinMeta = const VerificationMeta('vin');
  @override
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelTypeMeta = const VerificationMeta(
    'fuelType',
  );
  @override
  late final GeneratedColumn<String> fuelType = GeneratedColumn<String>(
    'fuel_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mileageMeta = const VerificationMeta(
    'mileage',
  );
  @override
  late final GeneratedColumn<double> mileage = GeneratedColumn<double>(
    'mileage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mileageUnitMeta = const VerificationMeta(
    'mileageUnit',
  );
  @override
  late final GeneratedColumn<String> mileageUnit = GeneratedColumn<String>(
    'mileage_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mi'),
  );
  static const VerificationMeta _purchaseDateMeta = const VerificationMeta(
    'purchaseDate',
  );
  @override
  late final GeneratedColumn<DateTime> purchaseDate = GeneratedColumn<DateTime>(
    'purchase_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchasePriceMeta = const VerificationMeta(
    'purchasePrice',
  );
  @override
  late final GeneratedColumn<double> purchasePrice = GeneratedColumn<double>(
    'purchase_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoLocalPathMeta = const VerificationMeta(
    'photoLocalPath',
  );
  @override
  late final GeneratedColumn<String> photoLocalPath = GeneratedColumn<String>(
    'photo_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoMediaIdMeta = const VerificationMeta(
    'photoMediaId',
  );
  @override
  late final GeneratedColumn<String> photoMediaId = GeneratedColumn<String>(
    'photo_media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('owned'),
  );
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  @override
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    nickname,
    make,
    model,
    year,
    licensePlate,
    vin,
    color,
    fuelType,
    mileage,
    mileageUnit,
    purchaseDate,
    purchasePrice,
    photoLocalPath,
    photoMediaId,
    archived,
    archivedAt,
    updatedAt,
    createdAt,
    source,
    permission,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('make')) {
      context.handle(
        _makeMeta,
        make.isAcceptableOrUnknown(data['make']!, _makeMeta),
      );
    } else if (isInserting) {
      context.missing(_makeMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('license_plate')) {
      context.handle(
        _licensePlateMeta,
        licensePlate.isAcceptableOrUnknown(
          data['license_plate']!,
          _licensePlateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_licensePlateMeta);
    }
    if (data.containsKey('vin')) {
      context.handle(
        _vinMeta,
        vin.isAcceptableOrUnknown(data['vin']!, _vinMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('fuel_type')) {
      context.handle(
        _fuelTypeMeta,
        fuelType.isAcceptableOrUnknown(data['fuel_type']!, _fuelTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fuelTypeMeta);
    }
    if (data.containsKey('mileage')) {
      context.handle(
        _mileageMeta,
        mileage.isAcceptableOrUnknown(data['mileage']!, _mileageMeta),
      );
    } else if (isInserting) {
      context.missing(_mileageMeta);
    }
    if (data.containsKey('mileage_unit')) {
      context.handle(
        _mileageUnitMeta,
        mileageUnit.isAcceptableOrUnknown(
          data['mileage_unit']!,
          _mileageUnitMeta,
        ),
      );
    }
    if (data.containsKey('purchase_date')) {
      context.handle(
        _purchaseDateMeta,
        purchaseDate.isAcceptableOrUnknown(
          data['purchase_date']!,
          _purchaseDateMeta,
        ),
      );
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchasePriceMeta,
        purchasePrice.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchasePriceMeta,
        ),
      );
    }
    if (data.containsKey('photo_local_path')) {
      context.handle(
        _photoLocalPathMeta,
        photoLocalPath.isAcceptableOrUnknown(
          data['photo_local_path']!,
          _photoLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('photo_media_id')) {
      context.handle(
        _photoMediaIdMeta,
        photoMediaId.isAcceptableOrUnknown(
          data['photo_media_id']!,
          _photoMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      make: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}make'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      licensePlate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_plate'],
      )!,
      vin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vin'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      fuelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_type'],
      )!,
      mileage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mileage'],
      )!,
      mileageUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mileage_unit'],
      )!,
      purchaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}purchase_date'],
      ),
      purchasePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_price'],
      ),
      photoLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_local_path'],
      ),
      photoMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_media_id'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      ),
    );
  }

  @override
  $VehicleRecordsTable createAlias(String alias) {
    return $VehicleRecordsTable(attachedDatabase, alias);
  }
}

class VehicleRecord extends DataClass implements Insertable<VehicleRecord> {
  final String id;
  final String userId;
  final String name;
  final String? nickname;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final String fuelType;
  final double mileage;
  final String mileageUnit;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? photoLocalPath;
  final String? photoMediaId;
  final bool archived;
  final DateTime? archivedAt;
  final DateTime updatedAt;
  final DateTime createdAt;
  final String source;
  final String? permission;
  const VehicleRecord({
    required this.id,
    required this.userId,
    required this.name,
    this.nickname,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.vin,
    this.color,
    required this.fuelType,
    required this.mileage,
    required this.mileageUnit,
    this.purchaseDate,
    this.purchasePrice,
    this.photoLocalPath,
    this.photoMediaId,
    required this.archived,
    this.archivedAt,
    required this.updatedAt,
    required this.createdAt,
    required this.source,
    this.permission,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['make'] = Variable<String>(make);
    map['model'] = Variable<String>(model);
    map['year'] = Variable<int>(year);
    map['license_plate'] = Variable<String>(licensePlate);
    if (!nullToAbsent || vin != null) {
      map['vin'] = Variable<String>(vin);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['fuel_type'] = Variable<String>(fuelType);
    map['mileage'] = Variable<double>(mileage);
    map['mileage_unit'] = Variable<String>(mileageUnit);
    if (!nullToAbsent || purchaseDate != null) {
      map['purchase_date'] = Variable<DateTime>(purchaseDate);
    }
    if (!nullToAbsent || purchasePrice != null) {
      map['purchase_price'] = Variable<double>(purchasePrice);
    }
    if (!nullToAbsent || photoLocalPath != null) {
      map['photo_local_path'] = Variable<String>(photoLocalPath);
    }
    if (!nullToAbsent || photoMediaId != null) {
      map['photo_media_id'] = Variable<String>(photoMediaId);
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || permission != null) {
      map['permission'] = Variable<String>(permission);
    }
    return map;
  }

  VehicleRecordsCompanion toCompanion(bool nullToAbsent) {
    return VehicleRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      make: Value(make),
      model: Value(model),
      year: Value(year),
      licensePlate: Value(licensePlate),
      vin: vin == null && nullToAbsent ? const Value.absent() : Value(vin),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      fuelType: Value(fuelType),
      mileage: Value(mileage),
      mileageUnit: Value(mileageUnit),
      purchaseDate: purchaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseDate),
      purchasePrice: purchasePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasePrice),
      photoLocalPath: photoLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoLocalPath),
      photoMediaId: photoMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(photoMediaId),
      archived: Value(archived),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
      source: Value(source),
      permission: permission == null && nullToAbsent
          ? const Value.absent()
          : Value(permission),
    );
  }

  factory VehicleRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      make: serializer.fromJson<String>(json['make']),
      model: serializer.fromJson<String>(json['model']),
      year: serializer.fromJson<int>(json['year']),
      licensePlate: serializer.fromJson<String>(json['licensePlate']),
      vin: serializer.fromJson<String?>(json['vin']),
      color: serializer.fromJson<String?>(json['color']),
      fuelType: serializer.fromJson<String>(json['fuelType']),
      mileage: serializer.fromJson<double>(json['mileage']),
      mileageUnit: serializer.fromJson<String>(json['mileageUnit']),
      purchaseDate: serializer.fromJson<DateTime?>(json['purchaseDate']),
      purchasePrice: serializer.fromJson<double?>(json['purchasePrice']),
      photoLocalPath: serializer.fromJson<String?>(json['photoLocalPath']),
      photoMediaId: serializer.fromJson<String?>(json['photoMediaId']),
      archived: serializer.fromJson<bool>(json['archived']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      source: serializer.fromJson<String>(json['source']),
      permission: serializer.fromJson<String?>(json['permission']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'nickname': serializer.toJson<String?>(nickname),
      'make': serializer.toJson<String>(make),
      'model': serializer.toJson<String>(model),
      'year': serializer.toJson<int>(year),
      'licensePlate': serializer.toJson<String>(licensePlate),
      'vin': serializer.toJson<String?>(vin),
      'color': serializer.toJson<String?>(color),
      'fuelType': serializer.toJson<String>(fuelType),
      'mileage': serializer.toJson<double>(mileage),
      'mileageUnit': serializer.toJson<String>(mileageUnit),
      'purchaseDate': serializer.toJson<DateTime?>(purchaseDate),
      'purchasePrice': serializer.toJson<double?>(purchasePrice),
      'photoLocalPath': serializer.toJson<String?>(photoLocalPath),
      'photoMediaId': serializer.toJson<String?>(photoMediaId),
      'archived': serializer.toJson<bool>(archived),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'source': serializer.toJson<String>(source),
      'permission': serializer.toJson<String?>(permission),
    };
  }

  VehicleRecord copyWith({
    String? id,
    String? userId,
    String? name,
    Value<String?> nickname = const Value.absent(),
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    Value<String?> vin = const Value.absent(),
    Value<String?> color = const Value.absent(),
    String? fuelType,
    double? mileage,
    String? mileageUnit,
    Value<DateTime?> purchaseDate = const Value.absent(),
    Value<double?> purchasePrice = const Value.absent(),
    Value<String?> photoLocalPath = const Value.absent(),
    Value<String?> photoMediaId = const Value.absent(),
    bool? archived,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
    String? source,
    Value<String?> permission = const Value.absent(),
  }) => VehicleRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    nickname: nickname.present ? nickname.value : this.nickname,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    licensePlate: licensePlate ?? this.licensePlate,
    vin: vin.present ? vin.value : this.vin,
    color: color.present ? color.value : this.color,
    fuelType: fuelType ?? this.fuelType,
    mileage: mileage ?? this.mileage,
    mileageUnit: mileageUnit ?? this.mileageUnit,
    purchaseDate: purchaseDate.present ? purchaseDate.value : this.purchaseDate,
    purchasePrice: purchasePrice.present
        ? purchasePrice.value
        : this.purchasePrice,
    photoLocalPath: photoLocalPath.present
        ? photoLocalPath.value
        : this.photoLocalPath,
    photoMediaId: photoMediaId.present ? photoMediaId.value : this.photoMediaId,
    archived: archived ?? this.archived,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
    source: source ?? this.source,
    permission: permission.present ? permission.value : this.permission,
  );
  VehicleRecord copyWithCompanion(VehicleRecordsCompanion data) {
    return VehicleRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      year: data.year.present ? data.year.value : this.year,
      licensePlate: data.licensePlate.present
          ? data.licensePlate.value
          : this.licensePlate,
      vin: data.vin.present ? data.vin.value : this.vin,
      color: data.color.present ? data.color.value : this.color,
      fuelType: data.fuelType.present ? data.fuelType.value : this.fuelType,
      mileage: data.mileage.present ? data.mileage.value : this.mileage,
      mileageUnit: data.mileageUnit.present
          ? data.mileageUnit.value
          : this.mileageUnit,
      purchaseDate: data.purchaseDate.present
          ? data.purchaseDate.value
          : this.purchaseDate,
      purchasePrice: data.purchasePrice.present
          ? data.purchasePrice.value
          : this.purchasePrice,
      photoLocalPath: data.photoLocalPath.present
          ? data.photoLocalPath.value
          : this.photoLocalPath,
      photoMediaId: data.photoMediaId.present
          ? data.photoMediaId.value
          : this.photoMediaId,
      archived: data.archived.present ? data.archived.value : this.archived,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      source: data.source.present ? data.source.value : this.source,
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('vin: $vin, ')
          ..write('color: $color, ')
          ..write('fuelType: $fuelType, ')
          ..write('mileage: $mileage, ')
          ..write('mileageUnit: $mileageUnit, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('photoLocalPath: $photoLocalPath, ')
          ..write('photoMediaId: $photoMediaId, ')
          ..write('archived: $archived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('source: $source, ')
          ..write('permission: $permission')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    userId,
    name,
    nickname,
    make,
    model,
    year,
    licensePlate,
    vin,
    color,
    fuelType,
    mileage,
    mileageUnit,
    purchaseDate,
    purchasePrice,
    photoLocalPath,
    photoMediaId,
    archived,
    archivedAt,
    updatedAt,
    createdAt,
    source,
    permission,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.nickname == this.nickname &&
          other.make == this.make &&
          other.model == this.model &&
          other.year == this.year &&
          other.licensePlate == this.licensePlate &&
          other.vin == this.vin &&
          other.color == this.color &&
          other.fuelType == this.fuelType &&
          other.mileage == this.mileage &&
          other.mileageUnit == this.mileageUnit &&
          other.purchaseDate == this.purchaseDate &&
          other.purchasePrice == this.purchasePrice &&
          other.photoLocalPath == this.photoLocalPath &&
          other.photoMediaId == this.photoMediaId &&
          other.archived == this.archived &&
          other.archivedAt == this.archivedAt &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt &&
          other.source == this.source &&
          other.permission == this.permission);
}

class VehicleRecordsCompanion extends UpdateCompanion<VehicleRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<String?> nickname;
  final Value<String> make;
  final Value<String> model;
  final Value<int> year;
  final Value<String> licensePlate;
  final Value<String?> vin;
  final Value<String?> color;
  final Value<String> fuelType;
  final Value<double> mileage;
  final Value<String> mileageUnit;
  final Value<DateTime?> purchaseDate;
  final Value<double?> purchasePrice;
  final Value<String?> photoLocalPath;
  final Value<String?> photoMediaId;
  final Value<bool> archived;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<String> source;
  final Value<String?> permission;
  final Value<int> rowid;
  const VehicleRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.nickname = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.licensePlate = const Value.absent(),
    this.vin = const Value.absent(),
    this.color = const Value.absent(),
    this.fuelType = const Value.absent(),
    this.mileage = const Value.absent(),
    this.mileageUnit = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.photoLocalPath = const Value.absent(),
    this.photoMediaId = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.source = const Value.absent(),
    this.permission = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleRecordsCompanion.insert({
    required String id,
    required String userId,
    required String name,
    this.nickname = const Value.absent(),
    required String make,
    required String model,
    required int year,
    required String licensePlate,
    this.vin = const Value.absent(),
    this.color = const Value.absent(),
    required String fuelType,
    required double mileage,
    this.mileageUnit = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.photoLocalPath = const Value.absent(),
    this.photoMediaId = const Value.absent(),
    this.archived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.source = const Value.absent(),
    this.permission = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       make = Value(make),
       model = Value(model),
       year = Value(year),
       licensePlate = Value(licensePlate),
       fuelType = Value(fuelType),
       mileage = Value(mileage),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<VehicleRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? nickname,
    Expression<String>? make,
    Expression<String>? model,
    Expression<int>? year,
    Expression<String>? licensePlate,
    Expression<String>? vin,
    Expression<String>? color,
    Expression<String>? fuelType,
    Expression<double>? mileage,
    Expression<String>? mileageUnit,
    Expression<DateTime>? purchaseDate,
    Expression<double>? purchasePrice,
    Expression<String>? photoLocalPath,
    Expression<String>? photoMediaId,
    Expression<bool>? archived,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<String>? source,
    Expression<String>? permission,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (nickname != null) 'nickname': nickname,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (licensePlate != null) 'license_plate': licensePlate,
      if (vin != null) 'vin': vin,
      if (color != null) 'color': color,
      if (fuelType != null) 'fuel_type': fuelType,
      if (mileage != null) 'mileage': mileage,
      if (mileageUnit != null) 'mileage_unit': mileageUnit,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (photoLocalPath != null) 'photo_local_path': photoLocalPath,
      if (photoMediaId != null) 'photo_media_id': photoMediaId,
      if (archived != null) 'archived': archived,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (source != null) 'source': source,
      if (permission != null) 'permission': permission,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String?>? nickname,
    Value<String>? make,
    Value<String>? model,
    Value<int>? year,
    Value<String>? licensePlate,
    Value<String?>? vin,
    Value<String?>? color,
    Value<String>? fuelType,
    Value<double>? mileage,
    Value<String>? mileageUnit,
    Value<DateTime?>? purchaseDate,
    Value<double?>? purchasePrice,
    Value<String?>? photoLocalPath,
    Value<String?>? photoMediaId,
    Value<bool>? archived,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<String>? source,
    Value<String?>? permission,
    Value<int>? rowid,
  }) {
    return VehicleRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      licensePlate: licensePlate ?? this.licensePlate,
      vin: vin ?? this.vin,
      color: color ?? this.color,
      fuelType: fuelType ?? this.fuelType,
      mileage: mileage ?? this.mileage,
      mileageUnit: mileageUnit ?? this.mileageUnit,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      photoMediaId: photoMediaId ?? this.photoMediaId,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      permission: permission ?? this.permission,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (licensePlate.present) {
      map['license_plate'] = Variable<String>(licensePlate.value);
    }
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (fuelType.present) {
      map['fuel_type'] = Variable<String>(fuelType.value);
    }
    if (mileage.present) {
      map['mileage'] = Variable<double>(mileage.value);
    }
    if (mileageUnit.present) {
      map['mileage_unit'] = Variable<String>(mileageUnit.value);
    }
    if (purchaseDate.present) {
      map['purchase_date'] = Variable<DateTime>(purchaseDate.value);
    }
    if (purchasePrice.present) {
      map['purchase_price'] = Variable<double>(purchasePrice.value);
    }
    if (photoLocalPath.present) {
      map['photo_local_path'] = Variable<String>(photoLocalPath.value);
    }
    if (photoMediaId.present) {
      map['photo_media_id'] = Variable<String>(photoMediaId.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehicleRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('vin: $vin, ')
          ..write('color: $color, ')
          ..write('fuelType: $fuelType, ')
          ..write('mileage: $mileage, ')
          ..write('mileageUnit: $mileageUnit, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('photoLocalPath: $photoLocalPath, ')
          ..write('photoMediaId: $photoMediaId, ')
          ..write('archived: $archived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('source: $source, ')
          ..write('permission: $permission, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeVehicleIdMeta = const VerificationMeta(
    'activeVehicleId',
  );
  @override
  late final GeneratedColumn<String> activeVehicleId = GeneratedColumn<String>(
    'active_vehicle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('my'),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('MMK'),
  );
  static const VerificationMeta _lengthUnitMeta = const VerificationMeta(
    'lengthUnit',
  );
  @override
  late final GeneratedColumn<String> lengthUnit = GeneratedColumn<String>(
    'length_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('km'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    activeVehicleId,
    language,
    currency,
    lengthUnit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('active_vehicle_id')) {
      context.handle(
        _activeVehicleIdMeta,
        activeVehicleId.isAcceptableOrUnknown(
          data['active_vehicle_id']!,
          _activeVehicleIdMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('length_unit')) {
      context.handle(
        _lengthUnitMeta,
        lengthUnit.isAcceptableOrUnknown(data['length_unit']!, _lengthUnitMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      activeVehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_vehicle_id'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      lengthUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}length_unit'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final String userId;
  final String? activeVehicleId;
  final String language;
  final String currency;
  final String lengthUnit;
  const UserProfile({
    required this.userId,
    this.activeVehicleId,
    required this.language,
    required this.currency,
    required this.lengthUnit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || activeVehicleId != null) {
      map['active_vehicle_id'] = Variable<String>(activeVehicleId);
    }
    map['language'] = Variable<String>(language);
    map['currency'] = Variable<String>(currency);
    map['length_unit'] = Variable<String>(lengthUnit);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      userId: Value(userId),
      activeVehicleId: activeVehicleId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeVehicleId),
      language: Value(language),
      currency: Value(currency),
      lengthUnit: Value(lengthUnit),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      userId: serializer.fromJson<String>(json['userId']),
      activeVehicleId: serializer.fromJson<String?>(json['activeVehicleId']),
      language: serializer.fromJson<String>(json['language']),
      currency: serializer.fromJson<String>(json['currency']),
      lengthUnit: serializer.fromJson<String>(json['lengthUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'activeVehicleId': serializer.toJson<String?>(activeVehicleId),
      'language': serializer.toJson<String>(language),
      'currency': serializer.toJson<String>(currency),
      'lengthUnit': serializer.toJson<String>(lengthUnit),
    };
  }

  UserProfile copyWith({
    String? userId,
    Value<String?> activeVehicleId = const Value.absent(),
    String? language,
    String? currency,
    String? lengthUnit,
  }) => UserProfile(
    userId: userId ?? this.userId,
    activeVehicleId: activeVehicleId.present
        ? activeVehicleId.value
        : this.activeVehicleId,
    language: language ?? this.language,
    currency: currency ?? this.currency,
    lengthUnit: lengthUnit ?? this.lengthUnit,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      userId: data.userId.present ? data.userId.value : this.userId,
      activeVehicleId: data.activeVehicleId.present
          ? data.activeVehicleId.value
          : this.activeVehicleId,
      language: data.language.present ? data.language.value : this.language,
      currency: data.currency.present ? data.currency.value : this.currency,
      lengthUnit: data.lengthUnit.present
          ? data.lengthUnit.value
          : this.lengthUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('userId: $userId, ')
          ..write('activeVehicleId: $activeVehicleId, ')
          ..write('language: $language, ')
          ..write('currency: $currency, ')
          ..write('lengthUnit: $lengthUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, activeVehicleId, language, currency, lengthUnit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.userId == this.userId &&
          other.activeVehicleId == this.activeVehicleId &&
          other.language == this.language &&
          other.currency == this.currency &&
          other.lengthUnit == this.lengthUnit);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<String> userId;
  final Value<String?> activeVehicleId;
  final Value<String> language;
  final Value<String> currency;
  final Value<String> lengthUnit;
  final Value<int> rowid;
  const UserProfilesCompanion({
    this.userId = const Value.absent(),
    this.activeVehicleId = const Value.absent(),
    this.language = const Value.absent(),
    this.currency = const Value.absent(),
    this.lengthUnit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    required String userId,
    this.activeVehicleId = const Value.absent(),
    this.language = const Value.absent(),
    this.currency = const Value.absent(),
    this.lengthUnit = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<UserProfile> custom({
    Expression<String>? userId,
    Expression<String>? activeVehicleId,
    Expression<String>? language,
    Expression<String>? currency,
    Expression<String>? lengthUnit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (activeVehicleId != null) 'active_vehicle_id': activeVehicleId,
      if (language != null) 'language': language,
      if (currency != null) 'currency': currency,
      if (lengthUnit != null) 'length_unit': lengthUnit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCompanion copyWith({
    Value<String>? userId,
    Value<String?>? activeVehicleId,
    Value<String>? language,
    Value<String>? currency,
    Value<String>? lengthUnit,
    Value<int>? rowid,
  }) {
    return UserProfilesCompanion(
      userId: userId ?? this.userId,
      activeVehicleId: activeVehicleId ?? this.activeVehicleId,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      lengthUnit: lengthUnit ?? this.lengthUnit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (activeVehicleId.present) {
      map['active_vehicle_id'] = Variable<String>(activeVehicleId.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (lengthUnit.present) {
      map['length_unit'] = Variable<String>(lengthUnit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('userId: $userId, ')
          ..write('activeVehicleId: $activeVehicleId, ')
          ..write('language: $language, ')
          ..write('currency: $currency, ')
          ..write('lengthUnit: $lengthUnit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientTsMeta = const VerificationMeta(
    'clientTs',
  );
  @override
  late final GeneratedColumn<DateTime> clientTs = GeneratedColumn<DateTime>(
    'client_ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    entityType,
    entityId,
    op,
    payload,
    clientTs,
    attemptCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('client_ts')) {
      context.handle(
        _clientTsMeta,
        clientTs.isAcceptableOrUnknown(data['client_ts']!, _clientTsMeta),
      );
    } else if (isInserting) {
      context.missing(_clientTsMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      clientTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_ts'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;
  final String userId;
  final String entityType;
  final String entityId;
  final String op;
  final String payload;
  final DateTime clientTs;
  final int attemptCount;
  final String? lastError;
  const OutboxEntry({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.clientTs,
    required this.attemptCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    map['payload'] = Variable<String>(payload);
    map['client_ts'] = Variable<DateTime>(clientTs);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      id: Value(id),
      userId: Value(userId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      op: Value(op),
      payload: Value(payload),
      clientTs: Value(clientTs),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      payload: serializer.fromJson<String>(json['payload']),
      clientTs: serializer.fromJson<DateTime>(json['clientTs']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'payload': serializer.toJson<String>(payload),
      'clientTs': serializer.toJson<DateTime>(clientTs),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxEntry copyWith({
    int? id,
    String? userId,
    String? entityType,
    String? entityId,
    String? op,
    String? payload,
    DateTime? clientTs,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxEntry(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    payload: payload ?? this.payload,
    clientTs: clientTs ?? this.clientTs,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      clientTs: data.clientTs.present ? data.clientTs.value : this.clientTs,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('clientTs: $clientTs, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    entityType,
    entityId,
    op,
    payload,
    clientTs,
    attemptCount,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.payload == this.payload &&
          other.clientTs == this.clientTs &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> op;
  final Value<String> payload;
  final Value<DateTime> clientTs;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  const OutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.clientTs = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String entityType,
    required String entityId,
    required String op,
    required String payload,
    required DateTime clientTs,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : userId = Value(userId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       op = Value(op),
       payload = Value(payload),
       clientTs = Value(clientTs);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<String>? payload,
    Expression<DateTime>? clientTs,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (clientTs != null) 'client_ts': clientTs,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? userId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? op,
    Value<String>? payload,
    Value<DateTime>? clientTs,
    Value<int>? attemptCount,
    Value<String?>? lastError,
  }) {
    return OutboxEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      clientTs: clientTs ?? this.clientTs,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (clientTs.present) {
      map['client_ts'] = Variable<DateTime>(clientTs.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('clientTs: $clientTs, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $PlanItemRecordsTable extends PlanItemRecords
    with TableInfo<$PlanItemRecordsTable, PlanItemRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanItemRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
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
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalDistanceMeta = const VerificationMeta(
    'intervalDistance',
  );
  @override
  late final GeneratedColumn<double> intervalDistance = GeneratedColumn<double>(
    'interval_distance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueMileageMeta = const VerificationMeta(
    'nextDueMileage',
  );
  @override
  late final GeneratedColumn<double> nextDueMileage = GeneratedColumn<double>(
    'next_due_mileage',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueOnMeta = const VerificationMeta(
    'nextDueOn',
  );
  @override
  late final GeneratedColumn<DateTime> nextDueOn = GeneratedColumn<DateTime>(
    'next_due_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catalogKeyMeta = const VerificationMeta(
    'catalogKey',
  );
  @override
  late final GeneratedColumn<String> catalogKey = GeneratedColumn<String>(
    'catalog_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    name,
    intervalDays,
    intervalDistance,
    nextDueMileage,
    nextDueOn,
    enabled,
    notes,
    catalogKey,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanItemRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('interval_distance')) {
      context.handle(
        _intervalDistanceMeta,
        intervalDistance.isAcceptableOrUnknown(
          data['interval_distance']!,
          _intervalDistanceMeta,
        ),
      );
    }
    if (data.containsKey('next_due_mileage')) {
      context.handle(
        _nextDueMileageMeta,
        nextDueMileage.isAcceptableOrUnknown(
          data['next_due_mileage']!,
          _nextDueMileageMeta,
        ),
      );
    }
    if (data.containsKey('next_due_on')) {
      context.handle(
        _nextDueOnMeta,
        nextDueOn.isAcceptableOrUnknown(data['next_due_on']!, _nextDueOnMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('catalog_key')) {
      context.handle(
        _catalogKeyMeta,
        catalogKey.isAcceptableOrUnknown(data['catalog_key']!, _catalogKeyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanItemRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanItemRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      ),
      intervalDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interval_distance'],
      ),
      nextDueMileage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}next_due_mileage'],
      ),
      nextDueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due_on'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      catalogKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalog_key'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlanItemRecordsTable createAlias(String alias) {
    return $PlanItemRecordsTable(attachedDatabase, alias);
  }
}

class PlanItemRecord extends DataClass implements Insertable<PlanItemRecord> {
  final String id;
  final String vehicleId;
  final String name;
  final int? intervalDays;
  final double? intervalDistance;
  final double? nextDueMileage;
  final DateTime? nextDueOn;
  final bool enabled;
  final String? notes;
  final String? catalogKey;
  final DateTime updatedAt;
  final DateTime createdAt;
  const PlanItemRecord({
    required this.id,
    required this.vehicleId,
    required this.name,
    this.intervalDays,
    this.intervalDistance,
    this.nextDueMileage,
    this.nextDueOn,
    required this.enabled,
    this.notes,
    this.catalogKey,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || intervalDays != null) {
      map['interval_days'] = Variable<int>(intervalDays);
    }
    if (!nullToAbsent || intervalDistance != null) {
      map['interval_distance'] = Variable<double>(intervalDistance);
    }
    if (!nullToAbsent || nextDueMileage != null) {
      map['next_due_mileage'] = Variable<double>(nextDueMileage);
    }
    if (!nullToAbsent || nextDueOn != null) {
      map['next_due_on'] = Variable<DateTime>(nextDueOn);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || catalogKey != null) {
      map['catalog_key'] = Variable<String>(catalogKey);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlanItemRecordsCompanion toCompanion(bool nullToAbsent) {
    return PlanItemRecordsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      name: Value(name),
      intervalDays: intervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalDays),
      intervalDistance: intervalDistance == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalDistance),
      nextDueMileage: nextDueMileage == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueMileage),
      nextDueOn: nextDueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueOn),
      enabled: Value(enabled),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      catalogKey: catalogKey == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogKey),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory PlanItemRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanItemRecord(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      name: serializer.fromJson<String>(json['name']),
      intervalDays: serializer.fromJson<int?>(json['intervalDays']),
      intervalDistance: serializer.fromJson<double?>(json['intervalDistance']),
      nextDueMileage: serializer.fromJson<double?>(json['nextDueMileage']),
      nextDueOn: serializer.fromJson<DateTime?>(json['nextDueOn']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      notes: serializer.fromJson<String?>(json['notes']),
      catalogKey: serializer.fromJson<String?>(json['catalogKey']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'name': serializer.toJson<String>(name),
      'intervalDays': serializer.toJson<int?>(intervalDays),
      'intervalDistance': serializer.toJson<double?>(intervalDistance),
      'nextDueMileage': serializer.toJson<double?>(nextDueMileage),
      'nextDueOn': serializer.toJson<DateTime?>(nextDueOn),
      'enabled': serializer.toJson<bool>(enabled),
      'notes': serializer.toJson<String?>(notes),
      'catalogKey': serializer.toJson<String?>(catalogKey),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PlanItemRecord copyWith({
    String? id,
    String? vehicleId,
    String? name,
    Value<int?> intervalDays = const Value.absent(),
    Value<double?> intervalDistance = const Value.absent(),
    Value<double?> nextDueMileage = const Value.absent(),
    Value<DateTime?> nextDueOn = const Value.absent(),
    bool? enabled,
    Value<String?> notes = const Value.absent(),
    Value<String?> catalogKey = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => PlanItemRecord(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    name: name ?? this.name,
    intervalDays: intervalDays.present ? intervalDays.value : this.intervalDays,
    intervalDistance: intervalDistance.present
        ? intervalDistance.value
        : this.intervalDistance,
    nextDueMileage: nextDueMileage.present
        ? nextDueMileage.value
        : this.nextDueMileage,
    nextDueOn: nextDueOn.present ? nextDueOn.value : this.nextDueOn,
    enabled: enabled ?? this.enabled,
    notes: notes.present ? notes.value : this.notes,
    catalogKey: catalogKey.present ? catalogKey.value : this.catalogKey,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PlanItemRecord copyWithCompanion(PlanItemRecordsCompanion data) {
    return PlanItemRecord(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      name: data.name.present ? data.name.value : this.name,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      intervalDistance: data.intervalDistance.present
          ? data.intervalDistance.value
          : this.intervalDistance,
      nextDueMileage: data.nextDueMileage.present
          ? data.nextDueMileage.value
          : this.nextDueMileage,
      nextDueOn: data.nextDueOn.present ? data.nextDueOn.value : this.nextDueOn,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      notes: data.notes.present ? data.notes.value : this.notes,
      catalogKey: data.catalogKey.present
          ? data.catalogKey.value
          : this.catalogKey,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanItemRecord(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('intervalDistance: $intervalDistance, ')
          ..write('nextDueMileage: $nextDueMileage, ')
          ..write('nextDueOn: $nextDueOn, ')
          ..write('enabled: $enabled, ')
          ..write('notes: $notes, ')
          ..write('catalogKey: $catalogKey, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    name,
    intervalDays,
    intervalDistance,
    nextDueMileage,
    nextDueOn,
    enabled,
    notes,
    catalogKey,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanItemRecord &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.name == this.name &&
          other.intervalDays == this.intervalDays &&
          other.intervalDistance == this.intervalDistance &&
          other.nextDueMileage == this.nextDueMileage &&
          other.nextDueOn == this.nextDueOn &&
          other.enabled == this.enabled &&
          other.notes == this.notes &&
          other.catalogKey == this.catalogKey &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class PlanItemRecordsCompanion extends UpdateCompanion<PlanItemRecord> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> name;
  final Value<int?> intervalDays;
  final Value<double?> intervalDistance;
  final Value<double?> nextDueMileage;
  final Value<DateTime?> nextDueOn;
  final Value<bool> enabled;
  final Value<String?> notes;
  final Value<String?> catalogKey;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlanItemRecordsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.name = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.intervalDistance = const Value.absent(),
    this.nextDueMileage = const Value.absent(),
    this.nextDueOn = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.catalogKey = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanItemRecordsCompanion.insert({
    required String id,
    required String vehicleId,
    required String name,
    this.intervalDays = const Value.absent(),
    this.intervalDistance = const Value.absent(),
    this.nextDueMileage = const Value.absent(),
    this.nextDueOn = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.catalogKey = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<PlanItemRecord> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? name,
    Expression<int>? intervalDays,
    Expression<double>? intervalDistance,
    Expression<double>? nextDueMileage,
    Expression<DateTime>? nextDueOn,
    Expression<bool>? enabled,
    Expression<String>? notes,
    Expression<String>? catalogKey,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (name != null) 'name': name,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (intervalDistance != null) 'interval_distance': intervalDistance,
      if (nextDueMileage != null) 'next_due_mileage': nextDueMileage,
      if (nextDueOn != null) 'next_due_on': nextDueOn,
      if (enabled != null) 'enabled': enabled,
      if (notes != null) 'notes': notes,
      if (catalogKey != null) 'catalog_key': catalogKey,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanItemRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? name,
    Value<int?>? intervalDays,
    Value<double?>? intervalDistance,
    Value<double?>? nextDueMileage,
    Value<DateTime?>? nextDueOn,
    Value<bool>? enabled,
    Value<String?>? notes,
    Value<String?>? catalogKey,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PlanItemRecordsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalDistance: intervalDistance ?? this.intervalDistance,
      nextDueMileage: nextDueMileage ?? this.nextDueMileage,
      nextDueOn: nextDueOn ?? this.nextDueOn,
      enabled: enabled ?? this.enabled,
      notes: notes ?? this.notes,
      catalogKey: catalogKey ?? this.catalogKey,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (intervalDistance.present) {
      map['interval_distance'] = Variable<double>(intervalDistance.value);
    }
    if (nextDueMileage.present) {
      map['next_due_mileage'] = Variable<double>(nextDueMileage.value);
    }
    if (nextDueOn.present) {
      map['next_due_on'] = Variable<DateTime>(nextDueOn.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (catalogKey.present) {
      map['catalog_key'] = Variable<String>(catalogKey.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanItemRecordsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('intervalDistance: $intervalDistance, ')
          ..write('nextDueMileage: $nextDueMileage, ')
          ..write('nextDueOn: $nextDueOn, ')
          ..write('enabled: $enabled, ')
          ..write('notes: $notes, ')
          ..write('catalogKey: $catalogKey, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceRecordRowsTable extends ServiceRecordRows
    with TableInfo<$ServiceRecordRowsTable, ServiceRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceRecordRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servicedOnMeta = const VerificationMeta(
    'servicedOn',
  );
  @override
  late final GeneratedColumn<DateTime> servicedOn = GeneratedColumn<DateTime>(
    'serviced_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<double> odometer = GeneratedColumn<double>(
    'odometer',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCostMeta = const VerificationMeta(
    'totalCost',
  );
  @override
  late final GeneratedColumn<double> totalCost = GeneratedColumn<double>(
    'total_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workshopNameMeta = const VerificationMeta(
    'workshopName',
  );
  @override
  late final GeneratedColumn<String> workshopName = GeneratedColumn<String>(
    'workshop_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptLocalPathMeta = const VerificationMeta(
    'receiptLocalPath',
  );
  @override
  late final GeneratedColumn<String> receiptLocalPath = GeneratedColumn<String>(
    'receipt_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptMediaIdMeta = const VerificationMeta(
    'receiptMediaId',
  );
  @override
  late final GeneratedColumn<String> receiptMediaId = GeneratedColumn<String>(
    'receipt_media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    title,
    servicedOn,
    odometer,
    totalCost,
    workshopName,
    notes,
    receiptLocalPath,
    receiptMediaId,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('serviced_on')) {
      context.handle(
        _servicedOnMeta,
        servicedOn.isAcceptableOrUnknown(data['serviced_on']!, _servicedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_servicedOnMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerMeta);
    }
    if (data.containsKey('total_cost')) {
      context.handle(
        _totalCostMeta,
        totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCostMeta);
    }
    if (data.containsKey('workshop_name')) {
      context.handle(
        _workshopNameMeta,
        workshopName.isAcceptableOrUnknown(
          data['workshop_name']!,
          _workshopNameMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('receipt_local_path')) {
      context.handle(
        _receiptLocalPathMeta,
        receiptLocalPath.isAcceptableOrUnknown(
          data['receipt_local_path']!,
          _receiptLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('receipt_media_id')) {
      context.handle(
        _receiptMediaIdMeta,
        receiptMediaId.isAcceptableOrUnknown(
          data['receipt_media_id']!,
          _receiptMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      servicedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}serviced_on'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer'],
      )!,
      totalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_cost'],
      )!,
      workshopName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workshop_name'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      receiptLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_local_path'],
      ),
      receiptMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_media_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ServiceRecordRowsTable createAlias(String alias) {
    return $ServiceRecordRowsTable(attachedDatabase, alias);
  }
}

class ServiceRecordRow extends DataClass
    implements Insertable<ServiceRecordRow> {
  final String id;
  final String vehicleId;
  final String title;
  final DateTime servicedOn;
  final double odometer;
  final double totalCost;
  final String? workshopName;
  final String? notes;
  final String? receiptLocalPath;
  final String? receiptMediaId;
  final DateTime updatedAt;
  final DateTime createdAt;
  const ServiceRecordRow({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.servicedOn,
    required this.odometer,
    required this.totalCost,
    this.workshopName,
    this.notes,
    this.receiptLocalPath,
    this.receiptMediaId,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['title'] = Variable<String>(title);
    map['serviced_on'] = Variable<DateTime>(servicedOn);
    map['odometer'] = Variable<double>(odometer);
    map['total_cost'] = Variable<double>(totalCost);
    if (!nullToAbsent || workshopName != null) {
      map['workshop_name'] = Variable<String>(workshopName);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || receiptLocalPath != null) {
      map['receipt_local_path'] = Variable<String>(receiptLocalPath);
    }
    if (!nullToAbsent || receiptMediaId != null) {
      map['receipt_media_id'] = Variable<String>(receiptMediaId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServiceRecordRowsCompanion toCompanion(bool nullToAbsent) {
    return ServiceRecordRowsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      title: Value(title),
      servicedOn: Value(servicedOn),
      odometer: Value(odometer),
      totalCost: Value(totalCost),
      workshopName: workshopName == null && nullToAbsent
          ? const Value.absent()
          : Value(workshopName),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      receiptLocalPath: receiptLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptLocalPath),
      receiptMediaId: receiptMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptMediaId),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ServiceRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceRecordRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      title: serializer.fromJson<String>(json['title']),
      servicedOn: serializer.fromJson<DateTime>(json['servicedOn']),
      odometer: serializer.fromJson<double>(json['odometer']),
      totalCost: serializer.fromJson<double>(json['totalCost']),
      workshopName: serializer.fromJson<String?>(json['workshopName']),
      notes: serializer.fromJson<String?>(json['notes']),
      receiptLocalPath: serializer.fromJson<String?>(json['receiptLocalPath']),
      receiptMediaId: serializer.fromJson<String?>(json['receiptMediaId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'title': serializer.toJson<String>(title),
      'servicedOn': serializer.toJson<DateTime>(servicedOn),
      'odometer': serializer.toJson<double>(odometer),
      'totalCost': serializer.toJson<double>(totalCost),
      'workshopName': serializer.toJson<String?>(workshopName),
      'notes': serializer.toJson<String?>(notes),
      'receiptLocalPath': serializer.toJson<String?>(receiptLocalPath),
      'receiptMediaId': serializer.toJson<String?>(receiptMediaId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServiceRecordRow copyWith({
    String? id,
    String? vehicleId,
    String? title,
    DateTime? servicedOn,
    double? odometer,
    double? totalCost,
    Value<String?> workshopName = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> receiptLocalPath = const Value.absent(),
    Value<String?> receiptMediaId = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => ServiceRecordRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    title: title ?? this.title,
    servicedOn: servicedOn ?? this.servicedOn,
    odometer: odometer ?? this.odometer,
    totalCost: totalCost ?? this.totalCost,
    workshopName: workshopName.present ? workshopName.value : this.workshopName,
    notes: notes.present ? notes.value : this.notes,
    receiptLocalPath: receiptLocalPath.present
        ? receiptLocalPath.value
        : this.receiptLocalPath,
    receiptMediaId: receiptMediaId.present
        ? receiptMediaId.value
        : this.receiptMediaId,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ServiceRecordRow copyWithCompanion(ServiceRecordRowsCompanion data) {
    return ServiceRecordRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      title: data.title.present ? data.title.value : this.title,
      servicedOn: data.servicedOn.present
          ? data.servicedOn.value
          : this.servicedOn,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      workshopName: data.workshopName.present
          ? data.workshopName.value
          : this.workshopName,
      notes: data.notes.present ? data.notes.value : this.notes,
      receiptLocalPath: data.receiptLocalPath.present
          ? data.receiptLocalPath.value
          : this.receiptLocalPath,
      receiptMediaId: data.receiptMediaId.present
          ? data.receiptMediaId.value
          : this.receiptMediaId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceRecordRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('title: $title, ')
          ..write('servicedOn: $servicedOn, ')
          ..write('odometer: $odometer, ')
          ..write('totalCost: $totalCost, ')
          ..write('workshopName: $workshopName, ')
          ..write('notes: $notes, ')
          ..write('receiptLocalPath: $receiptLocalPath, ')
          ..write('receiptMediaId: $receiptMediaId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    title,
    servicedOn,
    odometer,
    totalCost,
    workshopName,
    notes,
    receiptLocalPath,
    receiptMediaId,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceRecordRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.title == this.title &&
          other.servicedOn == this.servicedOn &&
          other.odometer == this.odometer &&
          other.totalCost == this.totalCost &&
          other.workshopName == this.workshopName &&
          other.notes == this.notes &&
          other.receiptLocalPath == this.receiptLocalPath &&
          other.receiptMediaId == this.receiptMediaId &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class ServiceRecordRowsCompanion extends UpdateCompanion<ServiceRecordRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> title;
  final Value<DateTime> servicedOn;
  final Value<double> odometer;
  final Value<double> totalCost;
  final Value<String?> workshopName;
  final Value<String?> notes;
  final Value<String?> receiptLocalPath;
  final Value<String?> receiptMediaId;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServiceRecordRowsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.title = const Value.absent(),
    this.servicedOn = const Value.absent(),
    this.odometer = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.workshopName = const Value.absent(),
    this.notes = const Value.absent(),
    this.receiptLocalPath = const Value.absent(),
    this.receiptMediaId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceRecordRowsCompanion.insert({
    required String id,
    required String vehicleId,
    required String title,
    required DateTime servicedOn,
    required double odometer,
    required double totalCost,
    this.workshopName = const Value.absent(),
    this.notes = const Value.absent(),
    this.receiptLocalPath = const Value.absent(),
    this.receiptMediaId = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       title = Value(title),
       servicedOn = Value(servicedOn),
       odometer = Value(odometer),
       totalCost = Value(totalCost),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<ServiceRecordRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? title,
    Expression<DateTime>? servicedOn,
    Expression<double>? odometer,
    Expression<double>? totalCost,
    Expression<String>? workshopName,
    Expression<String>? notes,
    Expression<String>? receiptLocalPath,
    Expression<String>? receiptMediaId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (title != null) 'title': title,
      if (servicedOn != null) 'serviced_on': servicedOn,
      if (odometer != null) 'odometer': odometer,
      if (totalCost != null) 'total_cost': totalCost,
      if (workshopName != null) 'workshop_name': workshopName,
      if (notes != null) 'notes': notes,
      if (receiptLocalPath != null) 'receipt_local_path': receiptLocalPath,
      if (receiptMediaId != null) 'receipt_media_id': receiptMediaId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceRecordRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? title,
    Value<DateTime>? servicedOn,
    Value<double>? odometer,
    Value<double>? totalCost,
    Value<String?>? workshopName,
    Value<String?>? notes,
    Value<String?>? receiptLocalPath,
    Value<String?>? receiptMediaId,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ServiceRecordRowsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      title: title ?? this.title,
      servicedOn: servicedOn ?? this.servicedOn,
      odometer: odometer ?? this.odometer,
      totalCost: totalCost ?? this.totalCost,
      workshopName: workshopName ?? this.workshopName,
      notes: notes ?? this.notes,
      receiptLocalPath: receiptLocalPath ?? this.receiptLocalPath,
      receiptMediaId: receiptMediaId ?? this.receiptMediaId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (servicedOn.present) {
      map['serviced_on'] = Variable<DateTime>(servicedOn.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<double>(odometer.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<double>(totalCost.value);
    }
    if (workshopName.present) {
      map['workshop_name'] = Variable<String>(workshopName.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (receiptLocalPath.present) {
      map['receipt_local_path'] = Variable<String>(receiptLocalPath.value);
    }
    if (receiptMediaId.present) {
      map['receipt_media_id'] = Variable<String>(receiptMediaId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceRecordRowsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('title: $title, ')
          ..write('servicedOn: $servicedOn, ')
          ..write('odometer: $odometer, ')
          ..write('totalCost: $totalCost, ')
          ..write('workshopName: $workshopName, ')
          ..write('notes: $notes, ')
          ..write('receiptLocalPath: $receiptLocalPath, ')
          ..write('receiptMediaId: $receiptMediaId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceLineRecordsTable extends ServiceLineRecords
    with TableInfo<$ServiceLineRecordsTable, ServiceLineRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceLineRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceRecordIdMeta = const VerificationMeta(
    'serviceRecordId',
  );
  @override
  late final GeneratedColumn<String> serviceRecordId = GeneratedColumn<String>(
    'service_record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planItemIdMeta = const VerificationMeta(
    'planItemId',
  );
  @override
  late final GeneratedColumn<String> planItemId = GeneratedColumn<String>(
    'plan_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _lineCostMeta = const VerificationMeta(
    'lineCost',
  );
  @override
  late final GeneratedColumn<double> lineCost = GeneratedColumn<double>(
    'line_cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serviceRecordId,
    planItemId,
    name,
    lineCost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_record_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceLineRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('service_record_id')) {
      context.handle(
        _serviceRecordIdMeta,
        serviceRecordId.isAcceptableOrUnknown(
          data['service_record_id']!,
          _serviceRecordIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceRecordIdMeta);
    }
    if (data.containsKey('plan_item_id')) {
      context.handle(
        _planItemIdMeta,
        planItemId.isAcceptableOrUnknown(
          data['plan_item_id']!,
          _planItemIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('line_cost')) {
      context.handle(
        _lineCostMeta,
        lineCost.isAcceptableOrUnknown(data['line_cost']!, _lineCostMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceLineRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceLineRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serviceRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_record_id'],
      )!,
      planItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_item_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lineCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}line_cost'],
      ),
    );
  }

  @override
  $ServiceLineRecordsTable createAlias(String alias) {
    return $ServiceLineRecordsTable(attachedDatabase, alias);
  }
}

class ServiceLineRecord extends DataClass
    implements Insertable<ServiceLineRecord> {
  final String id;
  final String serviceRecordId;
  final String? planItemId;
  final String name;
  final double? lineCost;
  const ServiceLineRecord({
    required this.id,
    required this.serviceRecordId,
    this.planItemId,
    required this.name,
    this.lineCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['service_record_id'] = Variable<String>(serviceRecordId);
    if (!nullToAbsent || planItemId != null) {
      map['plan_item_id'] = Variable<String>(planItemId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || lineCost != null) {
      map['line_cost'] = Variable<double>(lineCost);
    }
    return map;
  }

  ServiceLineRecordsCompanion toCompanion(bool nullToAbsent) {
    return ServiceLineRecordsCompanion(
      id: Value(id),
      serviceRecordId: Value(serviceRecordId),
      planItemId: planItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(planItemId),
      name: Value(name),
      lineCost: lineCost == null && nullToAbsent
          ? const Value.absent()
          : Value(lineCost),
    );
  }

  factory ServiceLineRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceLineRecord(
      id: serializer.fromJson<String>(json['id']),
      serviceRecordId: serializer.fromJson<String>(json['serviceRecordId']),
      planItemId: serializer.fromJson<String?>(json['planItemId']),
      name: serializer.fromJson<String>(json['name']),
      lineCost: serializer.fromJson<double?>(json['lineCost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serviceRecordId': serializer.toJson<String>(serviceRecordId),
      'planItemId': serializer.toJson<String?>(planItemId),
      'name': serializer.toJson<String>(name),
      'lineCost': serializer.toJson<double?>(lineCost),
    };
  }

  ServiceLineRecord copyWith({
    String? id,
    String? serviceRecordId,
    Value<String?> planItemId = const Value.absent(),
    String? name,
    Value<double?> lineCost = const Value.absent(),
  }) => ServiceLineRecord(
    id: id ?? this.id,
    serviceRecordId: serviceRecordId ?? this.serviceRecordId,
    planItemId: planItemId.present ? planItemId.value : this.planItemId,
    name: name ?? this.name,
    lineCost: lineCost.present ? lineCost.value : this.lineCost,
  );
  ServiceLineRecord copyWithCompanion(ServiceLineRecordsCompanion data) {
    return ServiceLineRecord(
      id: data.id.present ? data.id.value : this.id,
      serviceRecordId: data.serviceRecordId.present
          ? data.serviceRecordId.value
          : this.serviceRecordId,
      planItemId: data.planItemId.present
          ? data.planItemId.value
          : this.planItemId,
      name: data.name.present ? data.name.value : this.name,
      lineCost: data.lineCost.present ? data.lineCost.value : this.lineCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceLineRecord(')
          ..write('id: $id, ')
          ..write('serviceRecordId: $serviceRecordId, ')
          ..write('planItemId: $planItemId, ')
          ..write('name: $name, ')
          ..write('lineCost: $lineCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serviceRecordId, planItemId, name, lineCost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceLineRecord &&
          other.id == this.id &&
          other.serviceRecordId == this.serviceRecordId &&
          other.planItemId == this.planItemId &&
          other.name == this.name &&
          other.lineCost == this.lineCost);
}

class ServiceLineRecordsCompanion extends UpdateCompanion<ServiceLineRecord> {
  final Value<String> id;
  final Value<String> serviceRecordId;
  final Value<String?> planItemId;
  final Value<String> name;
  final Value<double?> lineCost;
  final Value<int> rowid;
  const ServiceLineRecordsCompanion({
    this.id = const Value.absent(),
    this.serviceRecordId = const Value.absent(),
    this.planItemId = const Value.absent(),
    this.name = const Value.absent(),
    this.lineCost = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceLineRecordsCompanion.insert({
    required String id,
    required String serviceRecordId,
    this.planItemId = const Value.absent(),
    required String name,
    this.lineCost = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serviceRecordId = Value(serviceRecordId),
       name = Value(name);
  static Insertable<ServiceLineRecord> custom({
    Expression<String>? id,
    Expression<String>? serviceRecordId,
    Expression<String>? planItemId,
    Expression<String>? name,
    Expression<double>? lineCost,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serviceRecordId != null) 'service_record_id': serviceRecordId,
      if (planItemId != null) 'plan_item_id': planItemId,
      if (name != null) 'name': name,
      if (lineCost != null) 'line_cost': lineCost,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceLineRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? serviceRecordId,
    Value<String?>? planItemId,
    Value<String>? name,
    Value<double?>? lineCost,
    Value<int>? rowid,
  }) {
    return ServiceLineRecordsCompanion(
      id: id ?? this.id,
      serviceRecordId: serviceRecordId ?? this.serviceRecordId,
      planItemId: planItemId ?? this.planItemId,
      name: name ?? this.name,
      lineCost: lineCost ?? this.lineCost,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serviceRecordId.present) {
      map['service_record_id'] = Variable<String>(serviceRecordId.value);
    }
    if (planItemId.present) {
      map['plan_item_id'] = Variable<String>(planItemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lineCost.present) {
      map['line_cost'] = Variable<double>(lineCost.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceLineRecordsCompanion(')
          ..write('id: $id, ')
          ..write('serviceRecordId: $serviceRecordId, ')
          ..write('planItemId: $planItemId, ')
          ..write('name: $name, ')
          ..write('lineCost: $lineCost, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartRecordsTable extends PartRecords
    with TableInfo<$PartRecordsTable, PartRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
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
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partNumberMeta = const VerificationMeta(
    'partNumber',
  );
  @override
  late final GeneratedColumn<String> partNumber = GeneratedColumn<String>(
    'part_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    vehicleId,
    name,
    brand,
    partNumber,
    notes,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('part_number')) {
      context.handle(
        _partNumberMeta,
        partNumber.isAcceptableOrUnknown(data['part_number']!, _partNumberMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      partNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_number'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PartRecordsTable createAlias(String alias) {
    return $PartRecordsTable(attachedDatabase, alias);
  }
}

class PartRecord extends DataClass implements Insertable<PartRecord> {
  final String id;
  final String userId;
  final String vehicleId;
  final String name;
  final String? brand;
  final String? partNumber;
  final String? notes;
  final DateTime updatedAt;
  final DateTime createdAt;
  const PartRecord({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.name,
    this.brand,
    this.partNumber,
    this.notes,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || partNumber != null) {
      map['part_number'] = Variable<String>(partNumber);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PartRecordsCompanion toCompanion(bool nullToAbsent) {
    return PartRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      vehicleId: Value(vehicleId),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      partNumber: partNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(partNumber),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory PartRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      partNumber: serializer.fromJson<String?>(json['partNumber']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'partNumber': serializer.toJson<String?>(partNumber),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PartRecord copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> partNumber = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => PartRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    vehicleId: vehicleId ?? this.vehicleId,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    partNumber: partNumber.present ? partNumber.value : this.partNumber,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PartRecord copyWithCompanion(PartRecordsCompanion data) {
    return PartRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      partNumber: data.partNumber.present
          ? data.partNumber.value
          : this.partNumber,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('partNumber: $partNumber, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    vehicleId,
    name,
    brand,
    partNumber,
    notes,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.vehicleId == this.vehicleId &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.partNumber == this.partNumber &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class PartRecordsCompanion extends UpdateCompanion<PartRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> vehicleId;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> partNumber;
  final Value<String?> notes;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PartRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.partNumber = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartRecordsCompanion.insert({
    required String id,
    required String userId,
    required String vehicleId,
    required String name,
    this.brand = const Value.absent(),
    this.partNumber = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       vehicleId = Value(vehicleId),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<PartRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? vehicleId,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? partNumber,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (partNumber != null) 'part_number': partNumber,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? vehicleId,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? partNumber,
    Value<String?>? notes,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PartRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      partNumber: partNumber ?? this.partNumber,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (partNumber.present) {
      map['part_number'] = Variable<String>(partNumber.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('partNumber: $partNumber, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServicePartRecordsTable extends ServicePartRecords
    with TableInfo<$ServicePartRecordsTable, ServicePartRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServicePartRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceRecordIdMeta = const VerificationMeta(
    'serviceRecordId',
  );
  @override
  late final GeneratedColumn<String> serviceRecordId = GeneratedColumn<String>(
    'service_record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
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
  @override
  List<GeneratedColumn> get $columns => [id, serviceRecordId, partId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_record_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServicePartRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('service_record_id')) {
      context.handle(
        _serviceRecordIdMeta,
        serviceRecordId.isAcceptableOrUnknown(
          data['service_record_id']!,
          _serviceRecordIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceRecordIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServicePartRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServicePartRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serviceRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_record_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ServicePartRecordsTable createAlias(String alias) {
    return $ServicePartRecordsTable(attachedDatabase, alias);
  }
}

class ServicePartRecord extends DataClass
    implements Insertable<ServicePartRecord> {
  final String id;
  final String serviceRecordId;
  final String partId;
  final String name;
  const ServicePartRecord({
    required this.id,
    required this.serviceRecordId,
    required this.partId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['service_record_id'] = Variable<String>(serviceRecordId);
    map['part_id'] = Variable<String>(partId);
    map['name'] = Variable<String>(name);
    return map;
  }

  ServicePartRecordsCompanion toCompanion(bool nullToAbsent) {
    return ServicePartRecordsCompanion(
      id: Value(id),
      serviceRecordId: Value(serviceRecordId),
      partId: Value(partId),
      name: Value(name),
    );
  }

  factory ServicePartRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServicePartRecord(
      id: serializer.fromJson<String>(json['id']),
      serviceRecordId: serializer.fromJson<String>(json['serviceRecordId']),
      partId: serializer.fromJson<String>(json['partId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serviceRecordId': serializer.toJson<String>(serviceRecordId),
      'partId': serializer.toJson<String>(partId),
      'name': serializer.toJson<String>(name),
    };
  }

  ServicePartRecord copyWith({
    String? id,
    String? serviceRecordId,
    String? partId,
    String? name,
  }) => ServicePartRecord(
    id: id ?? this.id,
    serviceRecordId: serviceRecordId ?? this.serviceRecordId,
    partId: partId ?? this.partId,
    name: name ?? this.name,
  );
  ServicePartRecord copyWithCompanion(ServicePartRecordsCompanion data) {
    return ServicePartRecord(
      id: data.id.present ? data.id.value : this.id,
      serviceRecordId: data.serviceRecordId.present
          ? data.serviceRecordId.value
          : this.serviceRecordId,
      partId: data.partId.present ? data.partId.value : this.partId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServicePartRecord(')
          ..write('id: $id, ')
          ..write('serviceRecordId: $serviceRecordId, ')
          ..write('partId: $partId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, serviceRecordId, partId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServicePartRecord &&
          other.id == this.id &&
          other.serviceRecordId == this.serviceRecordId &&
          other.partId == this.partId &&
          other.name == this.name);
}

class ServicePartRecordsCompanion extends UpdateCompanion<ServicePartRecord> {
  final Value<String> id;
  final Value<String> serviceRecordId;
  final Value<String> partId;
  final Value<String> name;
  final Value<int> rowid;
  const ServicePartRecordsCompanion({
    this.id = const Value.absent(),
    this.serviceRecordId = const Value.absent(),
    this.partId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServicePartRecordsCompanion.insert({
    required String id,
    required String serviceRecordId,
    required String partId,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serviceRecordId = Value(serviceRecordId),
       partId = Value(partId),
       name = Value(name);
  static Insertable<ServicePartRecord> custom({
    Expression<String>? id,
    Expression<String>? serviceRecordId,
    Expression<String>? partId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serviceRecordId != null) 'service_record_id': serviceRecordId,
      if (partId != null) 'part_id': partId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServicePartRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? serviceRecordId,
    Value<String>? partId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return ServicePartRecordsCompanion(
      id: id ?? this.id,
      serviceRecordId: serviceRecordId ?? this.serviceRecordId,
      partId: partId ?? this.partId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serviceRecordId.present) {
      map['service_record_id'] = Variable<String>(serviceRecordId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServicePartRecordsCompanion(')
          ..write('id: $id, ')
          ..write('serviceRecordId: $serviceRecordId, ')
          ..write('partId: $partId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FuelTypeRecordsTable extends FuelTypeRecords
    with TableInfo<$FuelTypeRecordsTable, FuelTypeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FuelTypeRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    kind,
    unit,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fuel_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<FuelTypeRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FuelTypeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FuelTypeRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FuelTypeRecordsTable createAlias(String alias) {
    return $FuelTypeRecordsTable(attachedDatabase, alias);
  }
}

class FuelTypeRecord extends DataClass implements Insertable<FuelTypeRecord> {
  final String id;
  final String userId;
  final String name;
  final String kind;
  final String unit;
  final DateTime updatedAt;
  final DateTime createdAt;
  const FuelTypeRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    required this.unit,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['unit'] = Variable<String>(unit);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FuelTypeRecordsCompanion toCompanion(bool nullToAbsent) {
    return FuelTypeRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      kind: Value(kind),
      unit: Value(unit),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory FuelTypeRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FuelTypeRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      unit: serializer.fromJson<String>(json['unit']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'unit': serializer.toJson<String>(unit),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FuelTypeRecord copyWith({
    String? id,
    String? userId,
    String? name,
    String? kind,
    String? unit,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => FuelTypeRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    unit: unit ?? this.unit,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  FuelTypeRecord copyWithCompanion(FuelTypeRecordsCompanion data) {
    return FuelTypeRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      unit: data.unit.present ? data.unit.value : this.unit,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FuelTypeRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('unit: $unit, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, name, kind, unit, updatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FuelTypeRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.unit == this.unit &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class FuelTypeRecordsCompanion extends UpdateCompanion<FuelTypeRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> unit;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FuelTypeRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.unit = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FuelTypeRecordsCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required String kind,
    required String unit,
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       kind = Value(kind),
       unit = Value(unit),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<FuelTypeRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? unit,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (unit != null) 'unit': unit,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FuelTypeRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? unit,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FuelTypeRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      unit: unit ?? this.unit,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FuelTypeRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('unit: $unit, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FuelLogRecordsTable extends FuelLogRecords
    with TableInfo<$FuelLogRecordsTable, FuelLogRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FuelLogRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fuelTypeIdMeta = const VerificationMeta(
    'fuelTypeId',
  );
  @override
  late final GeneratedColumn<String> fuelTypeId = GeneratedColumn<String>(
    'fuel_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fuelTypeNameMeta = const VerificationMeta(
    'fuelTypeName',
  );
  @override
  late final GeneratedColumn<String> fuelTypeName = GeneratedColumn<String>(
    'fuel_type_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedOnMeta = const VerificationMeta(
    'loggedOn',
  );
  @override
  late final GeneratedColumn<DateTime> loggedOn = GeneratedColumn<DateTime>(
    'logged_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
    'cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    vehicleId,
    kind,
    fuelTypeId,
    fuelTypeName,
    unit,
    loggedOn,
    amount,
    cost,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fuel_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FuelLogRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('fuel_type_id')) {
      context.handle(
        _fuelTypeIdMeta,
        fuelTypeId.isAcceptableOrUnknown(
          data['fuel_type_id']!,
          _fuelTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fuelTypeIdMeta);
    }
    if (data.containsKey('fuel_type_name')) {
      context.handle(
        _fuelTypeNameMeta,
        fuelTypeName.isAcceptableOrUnknown(
          data['fuel_type_name']!,
          _fuelTypeNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fuelTypeNameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('logged_on')) {
      context.handle(
        _loggedOnMeta,
        loggedOn.isAcceptableOrUnknown(data['logged_on']!, _loggedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedOnMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    } else if (isInserting) {
      context.missing(_costMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FuelLogRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FuelLogRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      fuelTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_type_id'],
      )!,
      fuelTypeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_type_name'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      loggedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_on'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FuelLogRecordsTable createAlias(String alias) {
    return $FuelLogRecordsTable(attachedDatabase, alias);
  }
}

class FuelLogRecord extends DataClass implements Insertable<FuelLogRecord> {
  final String id;
  final String userId;
  final String vehicleId;
  final String kind;
  final String fuelTypeId;
  final String fuelTypeName;
  final String unit;
  final DateTime loggedOn;
  final double amount;
  final double cost;
  final DateTime updatedAt;
  final DateTime createdAt;
  const FuelLogRecord({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.kind,
    required this.fuelTypeId,
    required this.fuelTypeName,
    required this.unit,
    required this.loggedOn,
    required this.amount,
    required this.cost,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['kind'] = Variable<String>(kind);
    map['fuel_type_id'] = Variable<String>(fuelTypeId);
    map['fuel_type_name'] = Variable<String>(fuelTypeName);
    map['unit'] = Variable<String>(unit);
    map['logged_on'] = Variable<DateTime>(loggedOn);
    map['amount'] = Variable<double>(amount);
    map['cost'] = Variable<double>(cost);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FuelLogRecordsCompanion toCompanion(bool nullToAbsent) {
    return FuelLogRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      vehicleId: Value(vehicleId),
      kind: Value(kind),
      fuelTypeId: Value(fuelTypeId),
      fuelTypeName: Value(fuelTypeName),
      unit: Value(unit),
      loggedOn: Value(loggedOn),
      amount: Value(amount),
      cost: Value(cost),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory FuelLogRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FuelLogRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      kind: serializer.fromJson<String>(json['kind']),
      fuelTypeId: serializer.fromJson<String>(json['fuelTypeId']),
      fuelTypeName: serializer.fromJson<String>(json['fuelTypeName']),
      unit: serializer.fromJson<String>(json['unit']),
      loggedOn: serializer.fromJson<DateTime>(json['loggedOn']),
      amount: serializer.fromJson<double>(json['amount']),
      cost: serializer.fromJson<double>(json['cost']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'kind': serializer.toJson<String>(kind),
      'fuelTypeId': serializer.toJson<String>(fuelTypeId),
      'fuelTypeName': serializer.toJson<String>(fuelTypeName),
      'unit': serializer.toJson<String>(unit),
      'loggedOn': serializer.toJson<DateTime>(loggedOn),
      'amount': serializer.toJson<double>(amount),
      'cost': serializer.toJson<double>(cost),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FuelLogRecord copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    String? kind,
    String? fuelTypeId,
    String? fuelTypeName,
    String? unit,
    DateTime? loggedOn,
    double? amount,
    double? cost,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => FuelLogRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    vehicleId: vehicleId ?? this.vehicleId,
    kind: kind ?? this.kind,
    fuelTypeId: fuelTypeId ?? this.fuelTypeId,
    fuelTypeName: fuelTypeName ?? this.fuelTypeName,
    unit: unit ?? this.unit,
    loggedOn: loggedOn ?? this.loggedOn,
    amount: amount ?? this.amount,
    cost: cost ?? this.cost,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  FuelLogRecord copyWithCompanion(FuelLogRecordsCompanion data) {
    return FuelLogRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      kind: data.kind.present ? data.kind.value : this.kind,
      fuelTypeId: data.fuelTypeId.present
          ? data.fuelTypeId.value
          : this.fuelTypeId,
      fuelTypeName: data.fuelTypeName.present
          ? data.fuelTypeName.value
          : this.fuelTypeName,
      unit: data.unit.present ? data.unit.value : this.unit,
      loggedOn: data.loggedOn.present ? data.loggedOn.value : this.loggedOn,
      amount: data.amount.present ? data.amount.value : this.amount,
      cost: data.cost.present ? data.cost.value : this.cost,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FuelLogRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('kind: $kind, ')
          ..write('fuelTypeId: $fuelTypeId, ')
          ..write('fuelTypeName: $fuelTypeName, ')
          ..write('unit: $unit, ')
          ..write('loggedOn: $loggedOn, ')
          ..write('amount: $amount, ')
          ..write('cost: $cost, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    vehicleId,
    kind,
    fuelTypeId,
    fuelTypeName,
    unit,
    loggedOn,
    amount,
    cost,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FuelLogRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.vehicleId == this.vehicleId &&
          other.kind == this.kind &&
          other.fuelTypeId == this.fuelTypeId &&
          other.fuelTypeName == this.fuelTypeName &&
          other.unit == this.unit &&
          other.loggedOn == this.loggedOn &&
          other.amount == this.amount &&
          other.cost == this.cost &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class FuelLogRecordsCompanion extends UpdateCompanion<FuelLogRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> vehicleId;
  final Value<String> kind;
  final Value<String> fuelTypeId;
  final Value<String> fuelTypeName;
  final Value<String> unit;
  final Value<DateTime> loggedOn;
  final Value<double> amount;
  final Value<double> cost;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FuelLogRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.kind = const Value.absent(),
    this.fuelTypeId = const Value.absent(),
    this.fuelTypeName = const Value.absent(),
    this.unit = const Value.absent(),
    this.loggedOn = const Value.absent(),
    this.amount = const Value.absent(),
    this.cost = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FuelLogRecordsCompanion.insert({
    required String id,
    required String userId,
    required String vehicleId,
    required String kind,
    required String fuelTypeId,
    required String fuelTypeName,
    required String unit,
    required DateTime loggedOn,
    required double amount,
    required double cost,
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       vehicleId = Value(vehicleId),
       kind = Value(kind),
       fuelTypeId = Value(fuelTypeId),
       fuelTypeName = Value(fuelTypeName),
       unit = Value(unit),
       loggedOn = Value(loggedOn),
       amount = Value(amount),
       cost = Value(cost),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<FuelLogRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? vehicleId,
    Expression<String>? kind,
    Expression<String>? fuelTypeId,
    Expression<String>? fuelTypeName,
    Expression<String>? unit,
    Expression<DateTime>? loggedOn,
    Expression<double>? amount,
    Expression<double>? cost,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (kind != null) 'kind': kind,
      if (fuelTypeId != null) 'fuel_type_id': fuelTypeId,
      if (fuelTypeName != null) 'fuel_type_name': fuelTypeName,
      if (unit != null) 'unit': unit,
      if (loggedOn != null) 'logged_on': loggedOn,
      if (amount != null) 'amount': amount,
      if (cost != null) 'cost': cost,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FuelLogRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? vehicleId,
    Value<String>? kind,
    Value<String>? fuelTypeId,
    Value<String>? fuelTypeName,
    Value<String>? unit,
    Value<DateTime>? loggedOn,
    Value<double>? amount,
    Value<double>? cost,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FuelLogRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      kind: kind ?? this.kind,
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      fuelTypeName: fuelTypeName ?? this.fuelTypeName,
      unit: unit ?? this.unit,
      loggedOn: loggedOn ?? this.loggedOn,
      amount: amount ?? this.amount,
      cost: cost ?? this.cost,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (fuelTypeId.present) {
      map['fuel_type_id'] = Variable<String>(fuelTypeId.value);
    }
    if (fuelTypeName.present) {
      map['fuel_type_name'] = Variable<String>(fuelTypeName.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (loggedOn.present) {
      map['logged_on'] = Variable<DateTime>(loggedOn.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FuelLogRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('kind: $kind, ')
          ..write('fuelTypeId: $fuelTypeId, ')
          ..write('fuelTypeName: $fuelTypeName, ')
          ..write('unit: $unit, ')
          ..write('loggedOn: $loggedOn, ')
          ..write('amount: $amount, ')
          ..write('cost: $cost, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseRecordsTable extends ExpenseRecords
    with TableInfo<$ExpenseRecordsTable, ExpenseRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incurredOnMeta = const VerificationMeta(
    'incurredOn',
  );
  @override
  late final GeneratedColumn<DateTime> incurredOn = GeneratedColumn<DateTime>(
    'incurred_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptLocalPathMeta = const VerificationMeta(
    'receiptLocalPath',
  );
  @override
  late final GeneratedColumn<String> receiptLocalPath = GeneratedColumn<String>(
    'receipt_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptMediaIdMeta = const VerificationMeta(
    'receiptMediaId',
  );
  @override
  late final GeneratedColumn<String> receiptMediaId = GeneratedColumn<String>(
    'receipt_media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    category,
    amount,
    incurredOn,
    notes,
    receiptLocalPath,
    receiptMediaId,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('incurred_on')) {
      context.handle(
        _incurredOnMeta,
        incurredOn.isAcceptableOrUnknown(data['incurred_on']!, _incurredOnMeta),
      );
    } else if (isInserting) {
      context.missing(_incurredOnMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('receipt_local_path')) {
      context.handle(
        _receiptLocalPathMeta,
        receiptLocalPath.isAcceptableOrUnknown(
          data['receipt_local_path']!,
          _receiptLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('receipt_media_id')) {
      context.handle(
        _receiptMediaIdMeta,
        receiptMediaId.isAcceptableOrUnknown(
          data['receipt_media_id']!,
          _receiptMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      incurredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}incurred_on'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      receiptLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_local_path'],
      ),
      receiptMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_media_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExpenseRecordsTable createAlias(String alias) {
    return $ExpenseRecordsTable(attachedDatabase, alias);
  }
}

class ExpenseRecord extends DataClass implements Insertable<ExpenseRecord> {
  final String id;
  final String vehicleId;
  final String category;
  final double amount;
  final DateTime incurredOn;
  final String? notes;
  final String? receiptLocalPath;
  final String? receiptMediaId;
  final DateTime updatedAt;
  final DateTime createdAt;
  const ExpenseRecord({
    required this.id,
    required this.vehicleId,
    required this.category,
    required this.amount,
    required this.incurredOn,
    this.notes,
    this.receiptLocalPath,
    this.receiptMediaId,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['category'] = Variable<String>(category);
    map['amount'] = Variable<double>(amount);
    map['incurred_on'] = Variable<DateTime>(incurredOn);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || receiptLocalPath != null) {
      map['receipt_local_path'] = Variable<String>(receiptLocalPath);
    }
    if (!nullToAbsent || receiptMediaId != null) {
      map['receipt_media_id'] = Variable<String>(receiptMediaId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExpenseRecordsCompanion toCompanion(bool nullToAbsent) {
    return ExpenseRecordsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      category: Value(category),
      amount: Value(amount),
      incurredOn: Value(incurredOn),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      receiptLocalPath: receiptLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptLocalPath),
      receiptMediaId: receiptMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptMediaId),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ExpenseRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseRecord(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<double>(json['amount']),
      incurredOn: serializer.fromJson<DateTime>(json['incurredOn']),
      notes: serializer.fromJson<String?>(json['notes']),
      receiptLocalPath: serializer.fromJson<String?>(json['receiptLocalPath']),
      receiptMediaId: serializer.fromJson<String?>(json['receiptMediaId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<double>(amount),
      'incurredOn': serializer.toJson<DateTime>(incurredOn),
      'notes': serializer.toJson<String?>(notes),
      'receiptLocalPath': serializer.toJson<String?>(receiptLocalPath),
      'receiptMediaId': serializer.toJson<String?>(receiptMediaId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExpenseRecord copyWith({
    String? id,
    String? vehicleId,
    String? category,
    double? amount,
    DateTime? incurredOn,
    Value<String?> notes = const Value.absent(),
    Value<String?> receiptLocalPath = const Value.absent(),
    Value<String?> receiptMediaId = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => ExpenseRecord(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    incurredOn: incurredOn ?? this.incurredOn,
    notes: notes.present ? notes.value : this.notes,
    receiptLocalPath: receiptLocalPath.present
        ? receiptLocalPath.value
        : this.receiptLocalPath,
    receiptMediaId: receiptMediaId.present
        ? receiptMediaId.value
        : this.receiptMediaId,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ExpenseRecord copyWithCompanion(ExpenseRecordsCompanion data) {
    return ExpenseRecord(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      incurredOn: data.incurredOn.present
          ? data.incurredOn.value
          : this.incurredOn,
      notes: data.notes.present ? data.notes.value : this.notes,
      receiptLocalPath: data.receiptLocalPath.present
          ? data.receiptLocalPath.value
          : this.receiptLocalPath,
      receiptMediaId: data.receiptMediaId.present
          ? data.receiptMediaId.value
          : this.receiptMediaId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRecord(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('incurredOn: $incurredOn, ')
          ..write('notes: $notes, ')
          ..write('receiptLocalPath: $receiptLocalPath, ')
          ..write('receiptMediaId: $receiptMediaId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    category,
    amount,
    incurredOn,
    notes,
    receiptLocalPath,
    receiptMediaId,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseRecord &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.incurredOn == this.incurredOn &&
          other.notes == this.notes &&
          other.receiptLocalPath == this.receiptLocalPath &&
          other.receiptMediaId == this.receiptMediaId &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class ExpenseRecordsCompanion extends UpdateCompanion<ExpenseRecord> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> category;
  final Value<double> amount;
  final Value<DateTime> incurredOn;
  final Value<String?> notes;
  final Value<String?> receiptLocalPath;
  final Value<String?> receiptMediaId;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExpenseRecordsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.incurredOn = const Value.absent(),
    this.notes = const Value.absent(),
    this.receiptLocalPath = const Value.absent(),
    this.receiptMediaId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseRecordsCompanion.insert({
    required String id,
    required String vehicleId,
    required String category,
    required double amount,
    required DateTime incurredOn,
    this.notes = const Value.absent(),
    this.receiptLocalPath = const Value.absent(),
    this.receiptMediaId = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       category = Value(category),
       amount = Value(amount),
       incurredOn = Value(incurredOn),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<ExpenseRecord> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? category,
    Expression<double>? amount,
    Expression<DateTime>? incurredOn,
    Expression<String>? notes,
    Expression<String>? receiptLocalPath,
    Expression<String>? receiptMediaId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (incurredOn != null) 'incurred_on': incurredOn,
      if (notes != null) 'notes': notes,
      if (receiptLocalPath != null) 'receipt_local_path': receiptLocalPath,
      if (receiptMediaId != null) 'receipt_media_id': receiptMediaId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? category,
    Value<double>? amount,
    Value<DateTime>? incurredOn,
    Value<String?>? notes,
    Value<String?>? receiptLocalPath,
    Value<String?>? receiptMediaId,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExpenseRecordsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      incurredOn: incurredOn ?? this.incurredOn,
      notes: notes ?? this.notes,
      receiptLocalPath: receiptLocalPath ?? this.receiptLocalPath,
      receiptMediaId: receiptMediaId ?? this.receiptMediaId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (incurredOn.present) {
      map['incurred_on'] = Variable<DateTime>(incurredOn.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (receiptLocalPath.present) {
      map['receipt_local_path'] = Variable<String>(receiptLocalPath.value);
    }
    if (receiptMediaId.present) {
      map['receipt_media_id'] = Variable<String>(receiptMediaId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRecordsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('incurredOn: $incurredOn, ')
          ..write('notes: $notes, ')
          ..write('receiptLocalPath: $receiptLocalPath, ')
          ..write('receiptMediaId: $receiptMediaId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensePartRecordsTable extends ExpensePartRecords
    with TableInfo<$ExpensePartRecordsTable, ExpensePartRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensePartRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expenseIdMeta = const VerificationMeta(
    'expenseId',
  );
  @override
  late final GeneratedColumn<String> expenseId = GeneratedColumn<String>(
    'expense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
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
  @override
  List<GeneratedColumn> get $columns => [id, expenseId, partId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpensePartRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('expense_id')) {
      context.handle(
        _expenseIdMeta,
        expenseId.isAcceptableOrUnknown(data['expense_id']!, _expenseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_expenseIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpensePartRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpensePartRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      expenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ExpensePartRecordsTable createAlias(String alias) {
    return $ExpensePartRecordsTable(attachedDatabase, alias);
  }
}

class ExpensePartRecord extends DataClass
    implements Insertable<ExpensePartRecord> {
  final String id;
  final String expenseId;
  final String partId;
  final String name;
  const ExpensePartRecord({
    required this.id,
    required this.expenseId,
    required this.partId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['expense_id'] = Variable<String>(expenseId);
    map['part_id'] = Variable<String>(partId);
    map['name'] = Variable<String>(name);
    return map;
  }

  ExpensePartRecordsCompanion toCompanion(bool nullToAbsent) {
    return ExpensePartRecordsCompanion(
      id: Value(id),
      expenseId: Value(expenseId),
      partId: Value(partId),
      name: Value(name),
    );
  }

  factory ExpensePartRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpensePartRecord(
      id: serializer.fromJson<String>(json['id']),
      expenseId: serializer.fromJson<String>(json['expenseId']),
      partId: serializer.fromJson<String>(json['partId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'expenseId': serializer.toJson<String>(expenseId),
      'partId': serializer.toJson<String>(partId),
      'name': serializer.toJson<String>(name),
    };
  }

  ExpensePartRecord copyWith({
    String? id,
    String? expenseId,
    String? partId,
    String? name,
  }) => ExpensePartRecord(
    id: id ?? this.id,
    expenseId: expenseId ?? this.expenseId,
    partId: partId ?? this.partId,
    name: name ?? this.name,
  );
  ExpensePartRecord copyWithCompanion(ExpensePartRecordsCompanion data) {
    return ExpensePartRecord(
      id: data.id.present ? data.id.value : this.id,
      expenseId: data.expenseId.present ? data.expenseId.value : this.expenseId,
      partId: data.partId.present ? data.partId.value : this.partId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpensePartRecord(')
          ..write('id: $id, ')
          ..write('expenseId: $expenseId, ')
          ..write('partId: $partId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, expenseId, partId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpensePartRecord &&
          other.id == this.id &&
          other.expenseId == this.expenseId &&
          other.partId == this.partId &&
          other.name == this.name);
}

class ExpensePartRecordsCompanion extends UpdateCompanion<ExpensePartRecord> {
  final Value<String> id;
  final Value<String> expenseId;
  final Value<String> partId;
  final Value<String> name;
  final Value<int> rowid;
  const ExpensePartRecordsCompanion({
    this.id = const Value.absent(),
    this.expenseId = const Value.absent(),
    this.partId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensePartRecordsCompanion.insert({
    required String id,
    required String expenseId,
    required String partId,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       expenseId = Value(expenseId),
       partId = Value(partId),
       name = Value(name);
  static Insertable<ExpensePartRecord> custom({
    Expression<String>? id,
    Expression<String>? expenseId,
    Expression<String>? partId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (expenseId != null) 'expense_id': expenseId,
      if (partId != null) 'part_id': partId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensePartRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? expenseId,
    Value<String>? partId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return ExpensePartRecordsCompanion(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      partId: partId ?? this.partId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (expenseId.present) {
      map['expense_id'] = Variable<String>(expenseId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensePartRecordsCompanion(')
          ..write('id: $id, ')
          ..write('expenseId: $expenseId, ')
          ..write('partId: $partId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationRecordsTable extends NotificationRecords
    with TableInfo<$NotificationRecordsTable, NotificationRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planItemIdMeta = const VerificationMeta(
    'planItemId',
  );
  @override
  late final GeneratedColumn<String> planItemId = GeneratedColumn<String>(
    'plan_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unread'),
  );
  static const VerificationMeta _dueReasonMeta = const VerificationMeta(
    'dueReason',
  );
  @override
  late final GeneratedColumn<String> dueReason = GeneratedColumn<String>(
    'due_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleKeyMeta = const VerificationMeta(
    'cycleKey',
  );
  @override
  late final GeneratedColumn<String> cycleKey = GeneratedColumn<String>(
    'cycle_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    vehicleId,
    planItemId,
    title,
    body,
    status,
    dueReason,
    cycleKey,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    }
    if (data.containsKey('plan_item_id')) {
      context.handle(
        _planItemIdMeta,
        planItemId.isAcceptableOrUnknown(
          data['plan_item_id']!,
          _planItemIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('due_reason')) {
      context.handle(
        _dueReasonMeta,
        dueReason.isAcceptableOrUnknown(data['due_reason']!, _dueReasonMeta),
      );
    }
    if (data.containsKey('cycle_key')) {
      context.handle(
        _cycleKeyMeta,
        cycleKey.isAcceptableOrUnknown(data['cycle_key']!, _cycleKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      ),
      planItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_item_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dueReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_reason'],
      ),
      cycleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotificationRecordsTable createAlias(String alias) {
    return $NotificationRecordsTable(attachedDatabase, alias);
  }
}

class NotificationRecord extends DataClass
    implements Insertable<NotificationRecord> {
  final String id;
  final String userId;
  final String? vehicleId;
  final String? planItemId;
  final String title;
  final String body;
  final String status;
  final String? dueReason;
  final String? cycleKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  const NotificationRecord({
    required this.id,
    required this.userId,
    this.vehicleId,
    this.planItemId,
    required this.title,
    required this.body,
    required this.status,
    this.dueReason,
    this.cycleKey,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<String>(vehicleId);
    }
    if (!nullToAbsent || planItemId != null) {
      map['plan_item_id'] = Variable<String>(planItemId);
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || dueReason != null) {
      map['due_reason'] = Variable<String>(dueReason);
    }
    if (!nullToAbsent || cycleKey != null) {
      map['cycle_key'] = Variable<String>(cycleKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotificationRecordsCompanion toCompanion(bool nullToAbsent) {
    return NotificationRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      vehicleId: vehicleId == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleId),
      planItemId: planItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(planItemId),
      title: Value(title),
      body: Value(body),
      status: Value(status),
      dueReason: dueReason == null && nullToAbsent
          ? const Value.absent()
          : Value(dueReason),
      cycleKey: cycleKey == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleKey),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotificationRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      vehicleId: serializer.fromJson<String?>(json['vehicleId']),
      planItemId: serializer.fromJson<String?>(json['planItemId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      status: serializer.fromJson<String>(json['status']),
      dueReason: serializer.fromJson<String?>(json['dueReason']),
      cycleKey: serializer.fromJson<String?>(json['cycleKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'vehicleId': serializer.toJson<String?>(vehicleId),
      'planItemId': serializer.toJson<String?>(planItemId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'status': serializer.toJson<String>(status),
      'dueReason': serializer.toJson<String?>(dueReason),
      'cycleKey': serializer.toJson<String?>(cycleKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NotificationRecord copyWith({
    String? id,
    String? userId,
    Value<String?> vehicleId = const Value.absent(),
    Value<String?> planItemId = const Value.absent(),
    String? title,
    String? body,
    String? status,
    Value<String?> dueReason = const Value.absent(),
    Value<String?> cycleKey = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NotificationRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
    planItemId: planItemId.present ? planItemId.value : this.planItemId,
    title: title ?? this.title,
    body: body ?? this.body,
    status: status ?? this.status,
    dueReason: dueReason.present ? dueReason.value : this.dueReason,
    cycleKey: cycleKey.present ? cycleKey.value : this.cycleKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NotificationRecord copyWithCompanion(NotificationRecordsCompanion data) {
    return NotificationRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      planItemId: data.planItemId.present
          ? data.planItemId.value
          : this.planItemId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      status: data.status.present ? data.status.value : this.status,
      dueReason: data.dueReason.present ? data.dueReason.value : this.dueReason,
      cycleKey: data.cycleKey.present ? data.cycleKey.value : this.cycleKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('planItemId: $planItemId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('dueReason: $dueReason, ')
          ..write('cycleKey: $cycleKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    vehicleId,
    planItemId,
    title,
    body,
    status,
    dueReason,
    cycleKey,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.vehicleId == this.vehicleId &&
          other.planItemId == this.planItemId &&
          other.title == this.title &&
          other.body == this.body &&
          other.status == this.status &&
          other.dueReason == this.dueReason &&
          other.cycleKey == this.cycleKey &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotificationRecordsCompanion extends UpdateCompanion<NotificationRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> vehicleId;
  final Value<String?> planItemId;
  final Value<String> title;
  final Value<String> body;
  final Value<String> status;
  final Value<String?> dueReason;
  final Value<String?> cycleKey;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotificationRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.planItemId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.dueReason = const Value.absent(),
    this.cycleKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationRecordsCompanion.insert({
    required String id,
    required String userId,
    this.vehicleId = const Value.absent(),
    this.planItemId = const Value.absent(),
    required String title,
    required String body,
    this.status = const Value.absent(),
    this.dueReason = const Value.absent(),
    this.cycleKey = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       title = Value(title),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NotificationRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? vehicleId,
    Expression<String>? planItemId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? status,
    Expression<String>? dueReason,
    Expression<String>? cycleKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (planItemId != null) 'plan_item_id': planItemId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (dueReason != null) 'due_reason': dueReason,
      if (cycleKey != null) 'cycle_key': cycleKey,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? vehicleId,
    Value<String?>? planItemId,
    Value<String>? title,
    Value<String>? body,
    Value<String>? status,
    Value<String?>? dueReason,
    Value<String?>? cycleKey,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotificationRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      planItemId: planItemId ?? this.planItemId,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      dueReason: dueReason ?? this.dueReason,
      cycleKey: cycleKey ?? this.cycleKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (planItemId.present) {
      map['plan_item_id'] = Variable<String>(planItemId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dueReason.present) {
      map['due_reason'] = Variable<String>(dueReason.value);
    }
    if (cycleKey.present) {
      map['cycle_key'] = Variable<String>(cycleKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('planItemId: $planItemId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('dueReason: $dueReason, ')
          ..write('cycleKey: $cycleKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyRecordsTable extends FamilyRecords
    with TableInfo<$FamilyRecordsTable, FamilyRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _shareCodeMeta = const VerificationMeta(
    'shareCode',
  );
  @override
  late final GeneratedColumn<String> shareCode = GeneratedColumn<String>(
    'share_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qrCodeDataMeta = const VerificationMeta(
    'qrCodeData',
  );
  @override
  late final GeneratedColumn<String> qrCodeData = GeneratedColumn<String>(
    'qr_code_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
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
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    shareCode,
    qrCodeData,
    createdBy,
    status,
    createdAt,
    archivedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'families';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyRecord> instance, {
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
    if (data.containsKey('share_code')) {
      context.handle(
        _shareCodeMeta,
        shareCode.isAcceptableOrUnknown(data['share_code']!, _shareCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_shareCodeMeta);
    }
    if (data.containsKey('qr_code_data')) {
      context.handle(
        _qrCodeDataMeta,
        qrCodeData.isAcceptableOrUnknown(
          data['qr_code_data']!,
          _qrCodeDataMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      shareCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_code'],
      )!,
      qrCodeData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_code_data'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $FamilyRecordsTable createAlias(String alias) {
    return $FamilyRecordsTable(attachedDatabase, alias);
  }
}

class FamilyRecord extends DataClass implements Insertable<FamilyRecord> {
  final String id;
  final String name;
  final String shareCode;
  final String? qrCodeData;
  final String createdBy;
  final String status;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final DateTime? syncedAt;
  const FamilyRecord({
    required this.id,
    required this.name,
    required this.shareCode,
    this.qrCodeData,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    this.archivedAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['share_code'] = Variable<String>(shareCode);
    if (!nullToAbsent || qrCodeData != null) {
      map['qr_code_data'] = Variable<String>(qrCodeData);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  FamilyRecordsCompanion toCompanion(bool nullToAbsent) {
    return FamilyRecordsCompanion(
      id: Value(id),
      name: Value(name),
      shareCode: Value(shareCode),
      qrCodeData: qrCodeData == null && nullToAbsent
          ? const Value.absent()
          : Value(qrCodeData),
      createdBy: Value(createdBy),
      status: Value(status),
      createdAt: Value(createdAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory FamilyRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyRecord(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      shareCode: serializer.fromJson<String>(json['shareCode']),
      qrCodeData: serializer.fromJson<String?>(json['qrCodeData']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'shareCode': serializer.toJson<String>(shareCode),
      'qrCodeData': serializer.toJson<String?>(qrCodeData),
      'createdBy': serializer.toJson<String>(createdBy),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  FamilyRecord copyWith({
    String? id,
    String? name,
    String? shareCode,
    Value<String?> qrCodeData = const Value.absent(),
    String? createdBy,
    String? status,
    DateTime? createdAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => FamilyRecord(
    id: id ?? this.id,
    name: name ?? this.name,
    shareCode: shareCode ?? this.shareCode,
    qrCodeData: qrCodeData.present ? qrCodeData.value : this.qrCodeData,
    createdBy: createdBy ?? this.createdBy,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  FamilyRecord copyWithCompanion(FamilyRecordsCompanion data) {
    return FamilyRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      shareCode: data.shareCode.present ? data.shareCode.value : this.shareCode,
      qrCodeData: data.qrCodeData.present
          ? data.qrCodeData.value
          : this.qrCodeData,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyRecord(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shareCode: $shareCode, ')
          ..write('qrCodeData: $qrCodeData, ')
          ..write('createdBy: $createdBy, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    shareCode,
    qrCodeData,
    createdBy,
    status,
    createdAt,
    archivedAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyRecord &&
          other.id == this.id &&
          other.name == this.name &&
          other.shareCode == this.shareCode &&
          other.qrCodeData == this.qrCodeData &&
          other.createdBy == this.createdBy &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.archivedAt == this.archivedAt &&
          other.syncedAt == this.syncedAt);
}

class FamilyRecordsCompanion extends UpdateCompanion<FamilyRecord> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> shareCode;
  final Value<String?> qrCodeData;
  final Value<String> createdBy;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const FamilyRecordsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.shareCode = const Value.absent(),
    this.qrCodeData = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyRecordsCompanion.insert({
    required String id,
    required String name,
    required String shareCode,
    this.qrCodeData = const Value.absent(),
    required String createdBy,
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.archivedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       shareCode = Value(shareCode),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt);
  static Insertable<FamilyRecord> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? shareCode,
    Expression<String>? qrCodeData,
    Expression<String>? createdBy,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (shareCode != null) 'share_code': shareCode,
      if (qrCodeData != null) 'qr_code_data': qrCodeData,
      if (createdBy != null) 'created_by': createdBy,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? shareCode,
    Value<String?>? qrCodeData,
    Value<String>? createdBy,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return FamilyRecordsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      shareCode: shareCode ?? this.shareCode,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      syncedAt: syncedAt ?? this.syncedAt,
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
    if (shareCode.present) {
      map['share_code'] = Variable<String>(shareCode.value);
    }
    if (qrCodeData.present) {
      map['qr_code_data'] = Variable<String>(qrCodeData.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyRecordsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shareCode: $shareCode, ')
          ..write('qrCodeData: $qrCodeData, ')
          ..write('createdBy: $createdBy, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyMembershipRecordsTable extends FamilyMembershipRecords
    with TableInfo<$FamilyMembershipRecordsTable, FamilyMembershipRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyMembershipRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invitedByMeta = const VerificationMeta(
    'invitedBy',
  );
  @override
  late final GeneratedColumn<String> invitedBy = GeneratedColumn<String>(
    'invited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    userId,
    role,
    joinedAt,
    invitedBy,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_memberships';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyMembershipRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('invited_by')) {
      context.handle(
        _invitedByMeta,
        invitedBy.isAcceptableOrUnknown(data['invited_by']!, _invitedByMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyMembershipRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyMembershipRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
      invitedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invited_by'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $FamilyMembershipRecordsTable createAlias(String alias) {
    return $FamilyMembershipRecordsTable(attachedDatabase, alias);
  }
}

class FamilyMembershipRecord extends DataClass
    implements Insertable<FamilyMembershipRecord> {
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? invitedBy;
  final DateTime? syncedAt;
  const FamilyMembershipRecord({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    if (!nullToAbsent || invitedBy != null) {
      map['invited_by'] = Variable<String>(invitedBy);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  FamilyMembershipRecordsCompanion toCompanion(bool nullToAbsent) {
    return FamilyMembershipRecordsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      userId: Value(userId),
      role: Value(role),
      joinedAt: Value(joinedAt),
      invitedBy: invitedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(invitedBy),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory FamilyMembershipRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyMembershipRecord(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      invitedBy: serializer.fromJson<String?>(json['invitedBy']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'invitedBy': serializer.toJson<String?>(invitedBy),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  FamilyMembershipRecord copyWith({
    String? id,
    String? familyId,
    String? userId,
    String? role,
    DateTime? joinedAt,
    Value<String?> invitedBy = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => FamilyMembershipRecord(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
    invitedBy: invitedBy.present ? invitedBy.value : this.invitedBy,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  FamilyMembershipRecord copyWithCompanion(
    FamilyMembershipRecordsCompanion data,
  ) {
    return FamilyMembershipRecord(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      invitedBy: data.invitedBy.present ? data.invitedBy.value : this.invitedBy,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyMembershipRecord(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('invitedBy: $invitedBy, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, familyId, userId, role, joinedAt, invitedBy, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyMembershipRecord &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt &&
          other.invitedBy == this.invitedBy &&
          other.syncedAt == this.syncedAt);
}

class FamilyMembershipRecordsCompanion
    extends UpdateCompanion<FamilyMembershipRecord> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> userId;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<String?> invitedBy;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const FamilyMembershipRecordsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.invitedBy = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyMembershipRecordsCompanion.insert({
    required String id,
    required String familyId,
    required String userId,
    required String role,
    required DateTime joinedAt,
    this.invitedBy = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       userId = Value(userId),
       role = Value(role),
       joinedAt = Value(joinedAt);
  static Insertable<FamilyMembershipRecord> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<String>? invitedBy,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (invitedBy != null) 'invited_by': invitedBy,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyMembershipRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? userId,
    Value<String>? role,
    Value<DateTime>? joinedAt,
    Value<String?>? invitedBy,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return FamilyMembershipRecordsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (invitedBy.present) {
      map['invited_by'] = Variable<String>(invitedBy.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyMembershipRecordsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('invitedBy: $invitedBy, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehicleGrantRecordsTable extends VehicleGrantRecords
    with TableInfo<$VehicleGrantRecordsTable, VehicleGrantRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleGrantRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grantedByMeta = const VerificationMeta(
    'grantedBy',
  );
  @override
  late final GeneratedColumn<String> grantedBy = GeneratedColumn<String>(
    'granted_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  @override
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    userId,
    grantedBy,
    permission,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicle_grants';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleGrantRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('granted_by')) {
      context.handle(
        _grantedByMeta,
        grantedBy.isAcceptableOrUnknown(data['granted_by']!, _grantedByMeta),
      );
    } else if (isInserting) {
      context.missing(_grantedByMeta);
    }
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    } else if (isInserting) {
      context.missing(_permissionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleGrantRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleGrantRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      grantedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}granted_by'],
      )!,
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $VehicleGrantRecordsTable createAlias(String alias) {
    return $VehicleGrantRecordsTable(attachedDatabase, alias);
  }
}

class VehicleGrantRecord extends DataClass
    implements Insertable<VehicleGrantRecord> {
  final String id;
  final String vehicleId;
  final String userId;
  final String grantedBy;
  final String permission;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const VehicleGrantRecord({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.grantedBy,
    required this.permission,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['user_id'] = Variable<String>(userId);
    map['granted_by'] = Variable<String>(grantedBy);
    map['permission'] = Variable<String>(permission);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  VehicleGrantRecordsCompanion toCompanion(bool nullToAbsent) {
    return VehicleGrantRecordsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      userId: Value(userId),
      grantedBy: Value(grantedBy),
      permission: Value(permission),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory VehicleGrantRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleGrantRecord(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      userId: serializer.fromJson<String>(json['userId']),
      grantedBy: serializer.fromJson<String>(json['grantedBy']),
      permission: serializer.fromJson<String>(json['permission']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'userId': serializer.toJson<String>(userId),
      'grantedBy': serializer.toJson<String>(grantedBy),
      'permission': serializer.toJson<String>(permission),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  VehicleGrantRecord copyWith({
    String? id,
    String? vehicleId,
    String? userId,
    String? grantedBy,
    String? permission,
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => VehicleGrantRecord(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    userId: userId ?? this.userId,
    grantedBy: grantedBy ?? this.grantedBy,
    permission: permission ?? this.permission,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  VehicleGrantRecord copyWithCompanion(VehicleGrantRecordsCompanion data) {
    return VehicleGrantRecord(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      userId: data.userId.present ? data.userId.value : this.userId,
      grantedBy: data.grantedBy.present ? data.grantedBy.value : this.grantedBy,
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleGrantRecord(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('userId: $userId, ')
          ..write('grantedBy: $grantedBy, ')
          ..write('permission: $permission, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    userId,
    grantedBy,
    permission,
    createdAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleGrantRecord &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.userId == this.userId &&
          other.grantedBy == this.grantedBy &&
          other.permission == this.permission &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class VehicleGrantRecordsCompanion extends UpdateCompanion<VehicleGrantRecord> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> userId;
  final Value<String> grantedBy;
  final Value<String> permission;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const VehicleGrantRecordsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.userId = const Value.absent(),
    this.grantedBy = const Value.absent(),
    this.permission = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleGrantRecordsCompanion.insert({
    required String id,
    required String vehicleId,
    required String userId,
    required String grantedBy,
    required String permission,
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       userId = Value(userId),
       grantedBy = Value(grantedBy),
       permission = Value(permission),
       createdAt = Value(createdAt);
  static Insertable<VehicleGrantRecord> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? userId,
    Expression<String>? grantedBy,
    Expression<String>? permission,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (userId != null) 'user_id': userId,
      if (grantedBy != null) 'granted_by': grantedBy,
      if (permission != null) 'permission': permission,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleGrantRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? userId,
    Value<String>? grantedBy,
    Value<String>? permission,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return VehicleGrantRecordsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      userId: userId ?? this.userId,
      grantedBy: grantedBy ?? this.grantedBy,
      permission: permission ?? this.permission,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (grantedBy.present) {
      map['granted_by'] = Variable<String>(grantedBy.value);
    }
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehicleGrantRecordsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('userId: $userId, ')
          ..write('grantedBy: $grantedBy, ')
          ..write('permission: $permission, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DrivingLicenseRecordsTable extends DrivingLicenseRecords
    with TableInfo<$DrivingLicenseRecordsTable, DrivingLicenseRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DrivingLicenseRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseNumberMeta = const VerificationMeta(
    'licenseNumber',
  );
  @override
  late final GeneratedColumn<String> licenseNumber = GeneratedColumn<String>(
    'license_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _issuingCountryMeta = const VerificationMeta(
    'issuingCountry',
  );
  @override
  late final GeneratedColumn<String> issuingCountry = GeneratedColumn<String>(
    'issuing_country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
    'expiry_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoriesMeta = const VerificationMeta(
    'categories',
  );
  @override
  late final GeneratedColumn<String> categories = GeneratedColumn<String>(
    'categories',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frontMediaIdMeta = const VerificationMeta(
    'frontMediaId',
  );
  @override
  late final GeneratedColumn<String> frontMediaId = GeneratedColumn<String>(
    'front_media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backMediaIdMeta = const VerificationMeta(
    'backMediaId',
  );
  @override
  late final GeneratedColumn<String> backMediaId = GeneratedColumn<String>(
    'back_media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    licenseNumber,
    issuingCountry,
    expiryDate,
    categories,
    frontMediaId,
    backMediaId,
    createdAt,
    updatedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'driving_licenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<DrivingLicenseRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('license_number')) {
      context.handle(
        _licenseNumberMeta,
        licenseNumber.isAcceptableOrUnknown(
          data['license_number']!,
          _licenseNumberMeta,
        ),
      );
    }
    if (data.containsKey('issuing_country')) {
      context.handle(
        _issuingCountryMeta,
        issuingCountry.isAcceptableOrUnknown(
          data['issuing_country']!,
          _issuingCountryMeta,
        ),
      );
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    } else if (isInserting) {
      context.missing(_expiryDateMeta);
    }
    if (data.containsKey('categories')) {
      context.handle(
        _categoriesMeta,
        categories.isAcceptableOrUnknown(data['categories']!, _categoriesMeta),
      );
    }
    if (data.containsKey('front_media_id')) {
      context.handle(
        _frontMediaIdMeta,
        frontMediaId.isAcceptableOrUnknown(
          data['front_media_id']!,
          _frontMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('back_media_id')) {
      context.handle(
        _backMediaIdMeta,
        backMediaId.isAcceptableOrUnknown(
          data['back_media_id']!,
          _backMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DrivingLicenseRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DrivingLicenseRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      licenseNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_number'],
      ),
      issuingCountry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuing_country'],
      ),
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expiry_date'],
      )!,
      categories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories'],
      ),
      frontMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front_media_id'],
      ),
      backMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back_media_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $DrivingLicenseRecordsTable createAlias(String alias) {
    return $DrivingLicenseRecordsTable(attachedDatabase, alias);
  }
}

class DrivingLicenseRecord extends DataClass
    implements Insertable<DrivingLicenseRecord> {
  final String id;
  final String userId;
  final String? licenseNumber;
  final String? issuingCountry;
  final DateTime expiryDate;
  final String? categories;
  final String? frontMediaId;
  final String? backMediaId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? syncedAt;
  const DrivingLicenseRecord({
    required this.id,
    required this.userId,
    this.licenseNumber,
    this.issuingCountry,
    required this.expiryDate,
    this.categories,
    this.frontMediaId,
    this.backMediaId,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || licenseNumber != null) {
      map['license_number'] = Variable<String>(licenseNumber);
    }
    if (!nullToAbsent || issuingCountry != null) {
      map['issuing_country'] = Variable<String>(issuingCountry);
    }
    map['expiry_date'] = Variable<DateTime>(expiryDate);
    if (!nullToAbsent || categories != null) {
      map['categories'] = Variable<String>(categories);
    }
    if (!nullToAbsent || frontMediaId != null) {
      map['front_media_id'] = Variable<String>(frontMediaId);
    }
    if (!nullToAbsent || backMediaId != null) {
      map['back_media_id'] = Variable<String>(backMediaId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  DrivingLicenseRecordsCompanion toCompanion(bool nullToAbsent) {
    return DrivingLicenseRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      licenseNumber: licenseNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(licenseNumber),
      issuingCountry: issuingCountry == null && nullToAbsent
          ? const Value.absent()
          : Value(issuingCountry),
      expiryDate: Value(expiryDate),
      categories: categories == null && nullToAbsent
          ? const Value.absent()
          : Value(categories),
      frontMediaId: frontMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(frontMediaId),
      backMediaId: backMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(backMediaId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory DrivingLicenseRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DrivingLicenseRecord(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      licenseNumber: serializer.fromJson<String?>(json['licenseNumber']),
      issuingCountry: serializer.fromJson<String?>(json['issuingCountry']),
      expiryDate: serializer.fromJson<DateTime>(json['expiryDate']),
      categories: serializer.fromJson<String?>(json['categories']),
      frontMediaId: serializer.fromJson<String?>(json['frontMediaId']),
      backMediaId: serializer.fromJson<String?>(json['backMediaId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'licenseNumber': serializer.toJson<String?>(licenseNumber),
      'issuingCountry': serializer.toJson<String?>(issuingCountry),
      'expiryDate': serializer.toJson<DateTime>(expiryDate),
      'categories': serializer.toJson<String?>(categories),
      'frontMediaId': serializer.toJson<String?>(frontMediaId),
      'backMediaId': serializer.toJson<String?>(backMediaId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  DrivingLicenseRecord copyWith({
    String? id,
    String? userId,
    Value<String?> licenseNumber = const Value.absent(),
    Value<String?> issuingCountry = const Value.absent(),
    DateTime? expiryDate,
    Value<String?> categories = const Value.absent(),
    Value<String?> frontMediaId = const Value.absent(),
    Value<String?> backMediaId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> syncedAt = const Value.absent(),
  }) => DrivingLicenseRecord(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    licenseNumber: licenseNumber.present
        ? licenseNumber.value
        : this.licenseNumber,
    issuingCountry: issuingCountry.present
        ? issuingCountry.value
        : this.issuingCountry,
    expiryDate: expiryDate ?? this.expiryDate,
    categories: categories.present ? categories.value : this.categories,
    frontMediaId: frontMediaId.present ? frontMediaId.value : this.frontMediaId,
    backMediaId: backMediaId.present ? backMediaId.value : this.backMediaId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  DrivingLicenseRecord copyWithCompanion(DrivingLicenseRecordsCompanion data) {
    return DrivingLicenseRecord(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      licenseNumber: data.licenseNumber.present
          ? data.licenseNumber.value
          : this.licenseNumber,
      issuingCountry: data.issuingCountry.present
          ? data.issuingCountry.value
          : this.issuingCountry,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      categories: data.categories.present
          ? data.categories.value
          : this.categories,
      frontMediaId: data.frontMediaId.present
          ? data.frontMediaId.value
          : this.frontMediaId,
      backMediaId: data.backMediaId.present
          ? data.backMediaId.value
          : this.backMediaId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DrivingLicenseRecord(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('licenseNumber: $licenseNumber, ')
          ..write('issuingCountry: $issuingCountry, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('categories: $categories, ')
          ..write('frontMediaId: $frontMediaId, ')
          ..write('backMediaId: $backMediaId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    licenseNumber,
    issuingCountry,
    expiryDate,
    categories,
    frontMediaId,
    backMediaId,
    createdAt,
    updatedAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DrivingLicenseRecord &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.licenseNumber == this.licenseNumber &&
          other.issuingCountry == this.issuingCountry &&
          other.expiryDate == this.expiryDate &&
          other.categories == this.categories &&
          other.frontMediaId == this.frontMediaId &&
          other.backMediaId == this.backMediaId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt);
}

class DrivingLicenseRecordsCompanion
    extends UpdateCompanion<DrivingLicenseRecord> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> licenseNumber;
  final Value<String?> issuingCountry;
  final Value<DateTime> expiryDate;
  final Value<String?> categories;
  final Value<String?> frontMediaId;
  final Value<String?> backMediaId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const DrivingLicenseRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.licenseNumber = const Value.absent(),
    this.issuingCountry = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.categories = const Value.absent(),
    this.frontMediaId = const Value.absent(),
    this.backMediaId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DrivingLicenseRecordsCompanion.insert({
    required String id,
    required String userId,
    this.licenseNumber = const Value.absent(),
    this.issuingCountry = const Value.absent(),
    required DateTime expiryDate,
    this.categories = const Value.absent(),
    this.frontMediaId = const Value.absent(),
    this.backMediaId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       expiryDate = Value(expiryDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DrivingLicenseRecord> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? licenseNumber,
    Expression<String>? issuingCountry,
    Expression<DateTime>? expiryDate,
    Expression<String>? categories,
    Expression<String>? frontMediaId,
    Expression<String>? backMediaId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (licenseNumber != null) 'license_number': licenseNumber,
      if (issuingCountry != null) 'issuing_country': issuingCountry,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (categories != null) 'categories': categories,
      if (frontMediaId != null) 'front_media_id': frontMediaId,
      if (backMediaId != null) 'back_media_id': backMediaId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DrivingLicenseRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? licenseNumber,
    Value<String?>? issuingCountry,
    Value<DateTime>? expiryDate,
    Value<String?>? categories,
    Value<String?>? frontMediaId,
    Value<String?>? backMediaId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? syncedAt,
    Value<int>? rowid,
  }) {
    return DrivingLicenseRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      issuingCountry: issuingCountry ?? this.issuingCountry,
      expiryDate: expiryDate ?? this.expiryDate,
      categories: categories ?? this.categories,
      frontMediaId: frontMediaId ?? this.frontMediaId,
      backMediaId: backMediaId ?? this.backMediaId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (licenseNumber.present) {
      map['license_number'] = Variable<String>(licenseNumber.value);
    }
    if (issuingCountry.present) {
      map['issuing_country'] = Variable<String>(issuingCountry.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (categories.present) {
      map['categories'] = Variable<String>(categories.value);
    }
    if (frontMediaId.present) {
      map['front_media_id'] = Variable<String>(frontMediaId.value);
    }
    if (backMediaId.present) {
      map['back_media_id'] = Variable<String>(backMediaId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DrivingLicenseRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('licenseNumber: $licenseNumber, ')
          ..write('issuingCountry: $issuingCountry, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('categories: $categories, ')
          ..write('frontMediaId: $frontMediaId, ')
          ..write('backMediaId: $backMediaId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyVehicleRecordsTable extends FamilyVehicleRecords
    with TableInfo<$FamilyVehicleRecordsTable, FamilyVehicleRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyVehicleRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedByMeta = const VerificationMeta(
    'addedBy',
  );
  @override
  late final GeneratedColumn<String> addedBy = GeneratedColumn<String>(
    'added_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    vehicleId,
    addedBy,
    addedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyVehicleRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('added_by')) {
      context.handle(
        _addedByMeta,
        addedBy.isAcceptableOrUnknown(data['added_by']!, _addedByMeta),
      );
    } else if (isInserting) {
      context.missing(_addedByMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyVehicleRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyVehicleRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      addedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $FamilyVehicleRecordsTable createAlias(String alias) {
    return $FamilyVehicleRecordsTable(attachedDatabase, alias);
  }
}

class FamilyVehicleRecord extends DataClass
    implements Insertable<FamilyVehicleRecord> {
  final String id;
  final String familyId;
  final String vehicleId;
  final String addedBy;
  final DateTime addedAt;
  final DateTime? syncedAt;
  const FamilyVehicleRecord({
    required this.id,
    required this.familyId,
    required this.vehicleId,
    required this.addedBy,
    required this.addedAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['added_by'] = Variable<String>(addedBy);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  FamilyVehicleRecordsCompanion toCompanion(bool nullToAbsent) {
    return FamilyVehicleRecordsCompanion(
      id: Value(id),
      familyId: Value(familyId),
      vehicleId: Value(vehicleId),
      addedBy: Value(addedBy),
      addedAt: Value(addedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory FamilyVehicleRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyVehicleRecord(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      addedBy: serializer.fromJson<String>(json['addedBy']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'addedBy': serializer.toJson<String>(addedBy),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  FamilyVehicleRecord copyWith({
    String? id,
    String? familyId,
    String? vehicleId,
    String? addedBy,
    DateTime? addedAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => FamilyVehicleRecord(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    vehicleId: vehicleId ?? this.vehicleId,
    addedBy: addedBy ?? this.addedBy,
    addedAt: addedAt ?? this.addedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  FamilyVehicleRecord copyWithCompanion(FamilyVehicleRecordsCompanion data) {
    return FamilyVehicleRecord(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      addedBy: data.addedBy.present ? data.addedBy.value : this.addedBy,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyVehicleRecord(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedAt: $addedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, familyId, vehicleId, addedBy, addedAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyVehicleRecord &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.vehicleId == this.vehicleId &&
          other.addedBy == this.addedBy &&
          other.addedAt == this.addedAt &&
          other.syncedAt == this.syncedAt);
}

class FamilyVehicleRecordsCompanion
    extends UpdateCompanion<FamilyVehicleRecord> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> vehicleId;
  final Value<String> addedBy;
  final Value<DateTime> addedAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const FamilyVehicleRecordsCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyVehicleRecordsCompanion.insert({
    required String id,
    required String familyId,
    required String vehicleId,
    required String addedBy,
    required DateTime addedAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       vehicleId = Value(vehicleId),
       addedBy = Value(addedBy),
       addedAt = Value(addedAt);
  static Insertable<FamilyVehicleRecord> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? vehicleId,
    Expression<String>? addedBy,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (addedBy != null) 'added_by': addedBy,
      if (addedAt != null) 'added_at': addedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyVehicleRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? vehicleId,
    Value<String>? addedBy,
    Value<DateTime>? addedAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return FamilyVehicleRecordsCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      vehicleId: vehicleId ?? this.vehicleId,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (addedBy.present) {
      map['added_by'] = Variable<String>(addedBy.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyVehicleRecordsCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedAt: $addedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentRecordsTable extends DocumentRecords
    with TableInfo<$DocumentRecordsTable, DocumentRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localFilePathMeta = const VerificationMeta(
    'localFilePath',
  );
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
    'local_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    name,
    category,
    notes,
    localFilePath,
    mediaId,
    updatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
        _localFilePathMeta,
        localFilePath.isAcceptableOrUnknown(
          data['local_file_path']!,
          _localFilePathMeta,
        ),
      );
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      localFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_path'],
      ),
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DocumentRecordsTable createAlias(String alias) {
    return $DocumentRecordsTable(attachedDatabase, alias);
  }
}

class DocumentRecord extends DataClass implements Insertable<DocumentRecord> {
  final String id;
  final String vehicleId;
  final String name;
  final String category;
  final String? notes;
  final String? localFilePath;
  final String? mediaId;
  final DateTime updatedAt;
  final DateTime createdAt;
  const DocumentRecord({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.category,
    this.notes,
    this.localFilePath,
    this.mediaId,
    required this.updatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<String>(mediaId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DocumentRecordsCompanion toCompanion(bool nullToAbsent) {
    return DocumentRecordsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      name: Value(name),
      category: Value(category),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
      mediaId: mediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaId),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory DocumentRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRecord(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      notes: serializer.fromJson<String?>(json['notes']),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
      mediaId: serializer.fromJson<String?>(json['mediaId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'notes': serializer.toJson<String?>(notes),
      'localFilePath': serializer.toJson<String?>(localFilePath),
      'mediaId': serializer.toJson<String?>(mediaId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DocumentRecord copyWith({
    String? id,
    String? vehicleId,
    String? name,
    String? category,
    Value<String?> notes = const Value.absent(),
    Value<String?> localFilePath = const Value.absent(),
    Value<String?> mediaId = const Value.absent(),
    DateTime? updatedAt,
    DateTime? createdAt,
  }) => DocumentRecord(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    name: name ?? this.name,
    category: category ?? this.category,
    notes: notes.present ? notes.value : this.notes,
    localFilePath: localFilePath.present
        ? localFilePath.value
        : this.localFilePath,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  DocumentRecord copyWithCompanion(DocumentRecordsCompanion data) {
    return DocumentRecord(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      notes: data.notes.present ? data.notes.value : this.notes,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRecord(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('mediaId: $mediaId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    name,
    category,
    notes,
    localFilePath,
    mediaId,
    updatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRecord &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.name == this.name &&
          other.category == this.category &&
          other.notes == this.notes &&
          other.localFilePath == this.localFilePath &&
          other.mediaId == this.mediaId &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt);
}

class DocumentRecordsCompanion extends UpdateCompanion<DocumentRecord> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> name;
  final Value<String> category;
  final Value<String?> notes;
  final Value<String?> localFilePath;
  final Value<String?> mediaId;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DocumentRecordsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentRecordsCompanion.insert({
    required String id,
    required String vehicleId,
    required String name,
    required String category,
    this.notes = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.mediaId = const Value.absent(),
    required DateTime updatedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       name = Value(name),
       category = Value(category),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt);
  static Insertable<DocumentRecord> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? notes,
    Expression<String>? localFilePath,
    Expression<String>? mediaId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (mediaId != null) 'media_id': mediaId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? name,
    Value<String>? category,
    Value<String?>? notes,
    Value<String?>? localFilePath,
    Value<String?>? mediaId,
    Value<DateTime>? updatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DocumentRecordsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      localFilePath: localFilePath ?? this.localFilePath,
      mediaId: mediaId ?? this.mediaId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRecordsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('mediaId: $mediaId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $VehicleRecordsTable vehicleRecords = $VehicleRecordsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final $PlanItemRecordsTable planItemRecords = $PlanItemRecordsTable(
    this,
  );
  late final $ServiceRecordRowsTable serviceRecordRows =
      $ServiceRecordRowsTable(this);
  late final $ServiceLineRecordsTable serviceLineRecords =
      $ServiceLineRecordsTable(this);
  late final $PartRecordsTable partRecords = $PartRecordsTable(this);
  late final $ServicePartRecordsTable servicePartRecords =
      $ServicePartRecordsTable(this);
  late final $FuelTypeRecordsTable fuelTypeRecords = $FuelTypeRecordsTable(
    this,
  );
  late final $FuelLogRecordsTable fuelLogRecords = $FuelLogRecordsTable(this);
  late final $ExpenseRecordsTable expenseRecords = $ExpenseRecordsTable(this);
  late final $ExpensePartRecordsTable expensePartRecords =
      $ExpensePartRecordsTable(this);
  late final $NotificationRecordsTable notificationRecords =
      $NotificationRecordsTable(this);
  late final $FamilyRecordsTable familyRecords = $FamilyRecordsTable(this);
  late final $FamilyMembershipRecordsTable familyMembershipRecords =
      $FamilyMembershipRecordsTable(this);
  late final $VehicleGrantRecordsTable vehicleGrantRecords =
      $VehicleGrantRecordsTable(this);
  late final $DrivingLicenseRecordsTable drivingLicenseRecords =
      $DrivingLicenseRecordsTable(this);
  late final $FamilyVehicleRecordsTable familyVehicleRecords =
      $FamilyVehicleRecordsTable(this);
  late final $DocumentRecordsTable documentRecords = $DocumentRecordsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appMeta,
    vehicleRecords,
    userProfiles,
    outboxEntries,
    planItemRecords,
    serviceRecordRows,
    serviceLineRecords,
    partRecords,
    servicePartRecords,
    fuelTypeRecords,
    fuelLogRecords,
    expenseRecords,
    expensePartRecords,
    notificationRecords,
    familyRecords,
    familyMembershipRecords,
    vehicleGrantRecords,
    drivingLicenseRecords,
    familyVehicleRecords,
    documentRecords,
  ];
}

typedef $$AppMetaTableCreateCompanionBuilder =
    AppMetaCompanion Function({
      Value<int> id,
      required String key,
      Value<String?> value,
    });
typedef $$AppMetaTableUpdateCompanionBuilder =
    AppMetaCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String?> value,
    });

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetaTable,
          AppMetaData,
          $$AppMetaTableFilterComposer,
          $$AppMetaTableOrderingComposer,
          $$AppMetaTableAnnotationComposer,
          $$AppMetaTableCreateCompanionBuilder,
          $$AppMetaTableUpdateCompanionBuilder,
          (
            AppMetaData,
            BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>,
          ),
          AppMetaData,
          PrefetchHooks Function()
        > {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
              }) => AppMetaCompanion(id: id, key: key, value: value),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                Value<String?> value = const Value.absent(),
              }) => AppMetaCompanion.insert(id: id, key: key, value: value),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetaTable,
      AppMetaData,
      $$AppMetaTableFilterComposer,
      $$AppMetaTableOrderingComposer,
      $$AppMetaTableAnnotationComposer,
      $$AppMetaTableCreateCompanionBuilder,
      $$AppMetaTableUpdateCompanionBuilder,
      (AppMetaData, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>),
      AppMetaData,
      PrefetchHooks Function()
    >;
typedef $$VehicleRecordsTableCreateCompanionBuilder =
    VehicleRecordsCompanion Function({
      required String id,
      required String userId,
      required String name,
      Value<String?> nickname,
      required String make,
      required String model,
      required int year,
      required String licensePlate,
      Value<String?> vin,
      Value<String?> color,
      required String fuelType,
      required double mileage,
      Value<String> mileageUnit,
      Value<DateTime?> purchaseDate,
      Value<double?> purchasePrice,
      Value<String?> photoLocalPath,
      Value<String?> photoMediaId,
      Value<bool> archived,
      Value<DateTime?> archivedAt,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<String> source,
      Value<String?> permission,
      Value<int> rowid,
    });
typedef $$VehicleRecordsTableUpdateCompanionBuilder =
    VehicleRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<String?> nickname,
      Value<String> make,
      Value<String> model,
      Value<int> year,
      Value<String> licensePlate,
      Value<String?> vin,
      Value<String?> color,
      Value<String> fuelType,
      Value<double> mileage,
      Value<String> mileageUnit,
      Value<DateTime?> purchaseDate,
      Value<double?> purchasePrice,
      Value<String?> photoLocalPath,
      Value<String?> photoMediaId,
      Value<bool> archived,
      Value<DateTime?> archivedAt,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<String> source,
      Value<String?> permission,
      Value<int> rowid,
    });

class $$VehicleRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleRecordsTable> {
  $$VehicleRecordsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mileage => $composableBuilder(
    column: $table.mileage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mileageUnit => $composableBuilder(
    column: $table.mileageUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoLocalPath => $composableBuilder(
    column: $table.photoLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoMediaId => $composableBuilder(
    column: $table.photoMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VehicleRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleRecordsTable> {
  $$VehicleRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mileage => $composableBuilder(
    column: $table.mileage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mileageUnit => $composableBuilder(
    column: $table.mileageUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoLocalPath => $composableBuilder(
    column: $table.photoLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoMediaId => $composableBuilder(
    column: $table.photoMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehicleRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleRecordsTable> {
  $$VehicleRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vin =>
      $composableBuilder(column: $table.vin, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get fuelType =>
      $composableBuilder(column: $table.fuelType, builder: (column) => column);

  GeneratedColumn<double> get mileage =>
      $composableBuilder(column: $table.mileage, builder: (column) => column);

  GeneratedColumn<String> get mileageUnit => $composableBuilder(
    column: $table.mileageUnit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoLocalPath => $composableBuilder(
    column: $table.photoLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoMediaId => $composableBuilder(
    column: $table.photoMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );
}

class $$VehicleRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehicleRecordsTable,
          VehicleRecord,
          $$VehicleRecordsTableFilterComposer,
          $$VehicleRecordsTableOrderingComposer,
          $$VehicleRecordsTableAnnotationComposer,
          $$VehicleRecordsTableCreateCompanionBuilder,
          $$VehicleRecordsTableUpdateCompanionBuilder,
          (
            VehicleRecord,
            BaseReferences<_$AppDatabase, $VehicleRecordsTable, VehicleRecord>,
          ),
          VehicleRecord,
          PrefetchHooks Function()
        > {
  $$VehicleRecordsTableTableManager(
    _$AppDatabase db,
    $VehicleRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehicleRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String> make = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<String> licensePlate = const Value.absent(),
                Value<String?> vin = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> fuelType = const Value.absent(),
                Value<double> mileage = const Value.absent(),
                Value<String> mileageUnit = const Value.absent(),
                Value<DateTime?> purchaseDate = const Value.absent(),
                Value<double?> purchasePrice = const Value.absent(),
                Value<String?> photoLocalPath = const Value.absent(),
                Value<String?> photoMediaId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> permission = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleRecordsCompanion(
                id: id,
                userId: userId,
                name: name,
                nickname: nickname,
                make: make,
                model: model,
                year: year,
                licensePlate: licensePlate,
                vin: vin,
                color: color,
                fuelType: fuelType,
                mileage: mileage,
                mileageUnit: mileageUnit,
                purchaseDate: purchaseDate,
                purchasePrice: purchasePrice,
                photoLocalPath: photoLocalPath,
                photoMediaId: photoMediaId,
                archived: archived,
                archivedAt: archivedAt,
                updatedAt: updatedAt,
                createdAt: createdAt,
                source: source,
                permission: permission,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String name,
                Value<String?> nickname = const Value.absent(),
                required String make,
                required String model,
                required int year,
                required String licensePlate,
                Value<String?> vin = const Value.absent(),
                Value<String?> color = const Value.absent(),
                required String fuelType,
                required double mileage,
                Value<String> mileageUnit = const Value.absent(),
                Value<DateTime?> purchaseDate = const Value.absent(),
                Value<double?> purchasePrice = const Value.absent(),
                Value<String?> photoLocalPath = const Value.absent(),
                Value<String?> photoMediaId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<String> source = const Value.absent(),
                Value<String?> permission = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleRecordsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                nickname: nickname,
                make: make,
                model: model,
                year: year,
                licensePlate: licensePlate,
                vin: vin,
                color: color,
                fuelType: fuelType,
                mileage: mileage,
                mileageUnit: mileageUnit,
                purchaseDate: purchaseDate,
                purchasePrice: purchasePrice,
                photoLocalPath: photoLocalPath,
                photoMediaId: photoMediaId,
                archived: archived,
                archivedAt: archivedAt,
                updatedAt: updatedAt,
                createdAt: createdAt,
                source: source,
                permission: permission,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehicleRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehicleRecordsTable,
      VehicleRecord,
      $$VehicleRecordsTableFilterComposer,
      $$VehicleRecordsTableOrderingComposer,
      $$VehicleRecordsTableAnnotationComposer,
      $$VehicleRecordsTableCreateCompanionBuilder,
      $$VehicleRecordsTableUpdateCompanionBuilder,
      (
        VehicleRecord,
        BaseReferences<_$AppDatabase, $VehicleRecordsTable, VehicleRecord>,
      ),
      VehicleRecord,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      required String userId,
      Value<String?> activeVehicleId,
      Value<String> language,
      Value<String> currency,
      Value<String> lengthUnit,
      Value<int> rowid,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> userId,
      Value<String?> activeVehicleId,
      Value<String> language,
      Value<String> currency,
      Value<String> lengthUnit,
      Value<int> rowid,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeVehicleId => $composableBuilder(
    column: $table.activeVehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lengthUnit => $composableBuilder(
    column: $table.lengthUnit,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeVehicleId => $composableBuilder(
    column: $table.activeVehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lengthUnit => $composableBuilder(
    column: $table.lengthUnit,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get activeVehicleId => $composableBuilder(
    column: $table.activeVehicleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get lengthUnit => $composableBuilder(
    column: $table.lengthUnit,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String?> activeVehicleId = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> lengthUnit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion(
                userId: userId,
                activeVehicleId: activeVehicleId,
                language: language,
                currency: currency,
                lengthUnit: lengthUnit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String?> activeVehicleId = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> lengthUnit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                userId: userId,
                activeVehicleId: activeVehicleId,
                language: language,
                currency: currency,
                lengthUnit: lengthUnit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$OutboxEntriesTableCreateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<int> id,
      required String userId,
      required String entityType,
      required String entityId,
      required String op,
      required String payload,
      required DateTime clientTs,
      Value<int> attemptCount,
      Value<String?> lastError,
    });
typedef $$OutboxEntriesTableUpdateCompanionBuilder =
    OutboxEntriesCompanion Function({
      Value<int> id,
      Value<String> userId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> op,
      Value<String> payload,
      Value<DateTime> clientTs,
      Value<int> attemptCount,
      Value<String?> lastError,
    });

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientTs => $composableBuilder(
    column: $table.clientTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientTs => $composableBuilder(
    column: $table.clientTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get clientTs =>
      $composableBuilder(column: $table.clientTs, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxEntriesTable,
          OutboxEntry,
          $$OutboxEntriesTableFilterComposer,
          $$OutboxEntriesTableOrderingComposer,
          $$OutboxEntriesTableAnnotationComposer,
          $$OutboxEntriesTableCreateCompanionBuilder,
          $$OutboxEntriesTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxEntriesTableTableManager(_$AppDatabase db, $OutboxEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> clientTs = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxEntriesCompanion(
                id: id,
                userId: userId,
                entityType: entityType,
                entityId: entityId,
                op: op,
                payload: payload,
                clientTs: clientTs,
                attemptCount: attemptCount,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String userId,
                required String entityType,
                required String entityId,
                required String op,
                required String payload,
                required DateTime clientTs,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxEntriesCompanion.insert(
                id: id,
                userId: userId,
                entityType: entityType,
                entityId: entityId,
                op: op,
                payload: payload,
                clientTs: clientTs,
                attemptCount: attemptCount,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxEntriesTable,
      OutboxEntry,
      $$OutboxEntriesTableFilterComposer,
      $$OutboxEntriesTableOrderingComposer,
      $$OutboxEntriesTableAnnotationComposer,
      $$OutboxEntriesTableCreateCompanionBuilder,
      $$OutboxEntriesTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$PlanItemRecordsTableCreateCompanionBuilder =
    PlanItemRecordsCompanion Function({
      required String id,
      required String vehicleId,
      required String name,
      Value<int?> intervalDays,
      Value<double?> intervalDistance,
      Value<double?> nextDueMileage,
      Value<DateTime?> nextDueOn,
      Value<bool> enabled,
      Value<String?> notes,
      Value<String?> catalogKey,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PlanItemRecordsTableUpdateCompanionBuilder =
    PlanItemRecordsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> name,
      Value<int?> intervalDays,
      Value<double?> intervalDistance,
      Value<double?> nextDueMileage,
      Value<DateTime?> nextDueOn,
      Value<bool> enabled,
      Value<String?> notes,
      Value<String?> catalogKey,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PlanItemRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanItemRecordsTable> {
  $$PlanItemRecordsTableFilterComposer({
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

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intervalDistance => $composableBuilder(
    column: $table.intervalDistance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nextDueMileage => $composableBuilder(
    column: $table.nextDueMileage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDueOn => $composableBuilder(
    column: $table.nextDueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catalogKey => $composableBuilder(
    column: $table.catalogKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlanItemRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanItemRecordsTable> {
  $$PlanItemRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intervalDistance => $composableBuilder(
    column: $table.intervalDistance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nextDueMileage => $composableBuilder(
    column: $table.nextDueMileage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDueOn => $composableBuilder(
    column: $table.nextDueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catalogKey => $composableBuilder(
    column: $table.catalogKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlanItemRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanItemRecordsTable> {
  $$PlanItemRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get intervalDistance => $composableBuilder(
    column: $table.intervalDistance,
    builder: (column) => column,
  );

  GeneratedColumn<double> get nextDueMileage => $composableBuilder(
    column: $table.nextDueMileage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDueOn =>
      $composableBuilder(column: $table.nextDueOn, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get catalogKey => $composableBuilder(
    column: $table.catalogKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PlanItemRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanItemRecordsTable,
          PlanItemRecord,
          $$PlanItemRecordsTableFilterComposer,
          $$PlanItemRecordsTableOrderingComposer,
          $$PlanItemRecordsTableAnnotationComposer,
          $$PlanItemRecordsTableCreateCompanionBuilder,
          $$PlanItemRecordsTableUpdateCompanionBuilder,
          (
            PlanItemRecord,
            BaseReferences<
              _$AppDatabase,
              $PlanItemRecordsTable,
              PlanItemRecord
            >,
          ),
          PlanItemRecord,
          PrefetchHooks Function()
        > {
  $$PlanItemRecordsTableTableManager(
    _$AppDatabase db,
    $PlanItemRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanItemRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanItemRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanItemRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                Value<double?> intervalDistance = const Value.absent(),
                Value<double?> nextDueMileage = const Value.absent(),
                Value<DateTime?> nextDueOn = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> catalogKey = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanItemRecordsCompanion(
                id: id,
                vehicleId: vehicleId,
                name: name,
                intervalDays: intervalDays,
                intervalDistance: intervalDistance,
                nextDueMileage: nextDueMileage,
                nextDueOn: nextDueOn,
                enabled: enabled,
                notes: notes,
                catalogKey: catalogKey,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String name,
                Value<int?> intervalDays = const Value.absent(),
                Value<double?> intervalDistance = const Value.absent(),
                Value<double?> nextDueMileage = const Value.absent(),
                Value<DateTime?> nextDueOn = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> catalogKey = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PlanItemRecordsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                name: name,
                intervalDays: intervalDays,
                intervalDistance: intervalDistance,
                nextDueMileage: nextDueMileage,
                nextDueOn: nextDueOn,
                enabled: enabled,
                notes: notes,
                catalogKey: catalogKey,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlanItemRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanItemRecordsTable,
      PlanItemRecord,
      $$PlanItemRecordsTableFilterComposer,
      $$PlanItemRecordsTableOrderingComposer,
      $$PlanItemRecordsTableAnnotationComposer,
      $$PlanItemRecordsTableCreateCompanionBuilder,
      $$PlanItemRecordsTableUpdateCompanionBuilder,
      (
        PlanItemRecord,
        BaseReferences<_$AppDatabase, $PlanItemRecordsTable, PlanItemRecord>,
      ),
      PlanItemRecord,
      PrefetchHooks Function()
    >;
typedef $$ServiceRecordRowsTableCreateCompanionBuilder =
    ServiceRecordRowsCompanion Function({
      required String id,
      required String vehicleId,
      required String title,
      required DateTime servicedOn,
      required double odometer,
      required double totalCost,
      Value<String?> workshopName,
      Value<String?> notes,
      Value<String?> receiptLocalPath,
      Value<String?> receiptMediaId,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ServiceRecordRowsTableUpdateCompanionBuilder =
    ServiceRecordRowsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> title,
      Value<DateTime> servicedOn,
      Value<double> odometer,
      Value<double> totalCost,
      Value<String?> workshopName,
      Value<String?> notes,
      Value<String?> receiptLocalPath,
      Value<String?> receiptMediaId,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ServiceRecordRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceRecordRowsTable> {
  $$ServiceRecordRowsTableFilterComposer({
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

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get servicedOn => $composableBuilder(
    column: $table.servicedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workshopName => $composableBuilder(
    column: $table.workshopName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptLocalPath => $composableBuilder(
    column: $table.receiptLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptMediaId => $composableBuilder(
    column: $table.receiptMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServiceRecordRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceRecordRowsTable> {
  $$ServiceRecordRowsTableOrderingComposer({
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

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get servicedOn => $composableBuilder(
    column: $table.servicedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workshopName => $composableBuilder(
    column: $table.workshopName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptLocalPath => $composableBuilder(
    column: $table.receiptLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptMediaId => $composableBuilder(
    column: $table.receiptMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServiceRecordRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceRecordRowsTable> {
  $$ServiceRecordRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get servicedOn => $composableBuilder(
    column: $table.servicedOn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);

  GeneratedColumn<double> get totalCost =>
      $composableBuilder(column: $table.totalCost, builder: (column) => column);

  GeneratedColumn<String> get workshopName => $composableBuilder(
    column: $table.workshopName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get receiptLocalPath => $composableBuilder(
    column: $table.receiptLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptMediaId => $composableBuilder(
    column: $table.receiptMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServiceRecordRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceRecordRowsTable,
          ServiceRecordRow,
          $$ServiceRecordRowsTableFilterComposer,
          $$ServiceRecordRowsTableOrderingComposer,
          $$ServiceRecordRowsTableAnnotationComposer,
          $$ServiceRecordRowsTableCreateCompanionBuilder,
          $$ServiceRecordRowsTableUpdateCompanionBuilder,
          (
            ServiceRecordRow,
            BaseReferences<
              _$AppDatabase,
              $ServiceRecordRowsTable,
              ServiceRecordRow
            >,
          ),
          ServiceRecordRow,
          PrefetchHooks Function()
        > {
  $$ServiceRecordRowsTableTableManager(
    _$AppDatabase db,
    $ServiceRecordRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceRecordRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceRecordRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceRecordRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> servicedOn = const Value.absent(),
                Value<double> odometer = const Value.absent(),
                Value<double> totalCost = const Value.absent(),
                Value<String?> workshopName = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> receiptLocalPath = const Value.absent(),
                Value<String?> receiptMediaId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceRecordRowsCompanion(
                id: id,
                vehicleId: vehicleId,
                title: title,
                servicedOn: servicedOn,
                odometer: odometer,
                totalCost: totalCost,
                workshopName: workshopName,
                notes: notes,
                receiptLocalPath: receiptLocalPath,
                receiptMediaId: receiptMediaId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String title,
                required DateTime servicedOn,
                required double odometer,
                required double totalCost,
                Value<String?> workshopName = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> receiptLocalPath = const Value.absent(),
                Value<String?> receiptMediaId = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ServiceRecordRowsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                title: title,
                servicedOn: servicedOn,
                odometer: odometer,
                totalCost: totalCost,
                workshopName: workshopName,
                notes: notes,
                receiptLocalPath: receiptLocalPath,
                receiptMediaId: receiptMediaId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServiceRecordRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceRecordRowsTable,
      ServiceRecordRow,
      $$ServiceRecordRowsTableFilterComposer,
      $$ServiceRecordRowsTableOrderingComposer,
      $$ServiceRecordRowsTableAnnotationComposer,
      $$ServiceRecordRowsTableCreateCompanionBuilder,
      $$ServiceRecordRowsTableUpdateCompanionBuilder,
      (
        ServiceRecordRow,
        BaseReferences<
          _$AppDatabase,
          $ServiceRecordRowsTable,
          ServiceRecordRow
        >,
      ),
      ServiceRecordRow,
      PrefetchHooks Function()
    >;
typedef $$ServiceLineRecordsTableCreateCompanionBuilder =
    ServiceLineRecordsCompanion Function({
      required String id,
      required String serviceRecordId,
      Value<String?> planItemId,
      required String name,
      Value<double?> lineCost,
      Value<int> rowid,
    });
typedef $$ServiceLineRecordsTableUpdateCompanionBuilder =
    ServiceLineRecordsCompanion Function({
      Value<String> id,
      Value<String> serviceRecordId,
      Value<String?> planItemId,
      Value<String> name,
      Value<double?> lineCost,
      Value<int> rowid,
    });

class $$ServiceLineRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceLineRecordsTable> {
  $$ServiceLineRecordsTableFilterComposer({
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

  ColumnFilters<String> get serviceRecordId => $composableBuilder(
    column: $table.serviceRecordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planItemId => $composableBuilder(
    column: $table.planItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lineCost => $composableBuilder(
    column: $table.lineCost,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServiceLineRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceLineRecordsTable> {
  $$ServiceLineRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get serviceRecordId => $composableBuilder(
    column: $table.serviceRecordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planItemId => $composableBuilder(
    column: $table.planItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lineCost => $composableBuilder(
    column: $table.lineCost,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServiceLineRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceLineRecordsTable> {
  $$ServiceLineRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serviceRecordId => $composableBuilder(
    column: $table.serviceRecordId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get planItemId => $composableBuilder(
    column: $table.planItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lineCost =>
      $composableBuilder(column: $table.lineCost, builder: (column) => column);
}

class $$ServiceLineRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceLineRecordsTable,
          ServiceLineRecord,
          $$ServiceLineRecordsTableFilterComposer,
          $$ServiceLineRecordsTableOrderingComposer,
          $$ServiceLineRecordsTableAnnotationComposer,
          $$ServiceLineRecordsTableCreateCompanionBuilder,
          $$ServiceLineRecordsTableUpdateCompanionBuilder,
          (
            ServiceLineRecord,
            BaseReferences<
              _$AppDatabase,
              $ServiceLineRecordsTable,
              ServiceLineRecord
            >,
          ),
          ServiceLineRecord,
          PrefetchHooks Function()
        > {
  $$ServiceLineRecordsTableTableManager(
    _$AppDatabase db,
    $ServiceLineRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceLineRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceLineRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceLineRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serviceRecordId = const Value.absent(),
                Value<String?> planItemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> lineCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceLineRecordsCompanion(
                id: id,
                serviceRecordId: serviceRecordId,
                planItemId: planItemId,
                name: name,
                lineCost: lineCost,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serviceRecordId,
                Value<String?> planItemId = const Value.absent(),
                required String name,
                Value<double?> lineCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceLineRecordsCompanion.insert(
                id: id,
                serviceRecordId: serviceRecordId,
                planItemId: planItemId,
                name: name,
                lineCost: lineCost,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServiceLineRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceLineRecordsTable,
      ServiceLineRecord,
      $$ServiceLineRecordsTableFilterComposer,
      $$ServiceLineRecordsTableOrderingComposer,
      $$ServiceLineRecordsTableAnnotationComposer,
      $$ServiceLineRecordsTableCreateCompanionBuilder,
      $$ServiceLineRecordsTableUpdateCompanionBuilder,
      (
        ServiceLineRecord,
        BaseReferences<
          _$AppDatabase,
          $ServiceLineRecordsTable,
          ServiceLineRecord
        >,
      ),
      ServiceLineRecord,
      PrefetchHooks Function()
    >;
typedef $$PartRecordsTableCreateCompanionBuilder =
    PartRecordsCompanion Function({
      required String id,
      required String userId,
      required String vehicleId,
      required String name,
      Value<String?> brand,
      Value<String?> partNumber,
      Value<String?> notes,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PartRecordsTableUpdateCompanionBuilder =
    PartRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> vehicleId,
      Value<String> name,
      Value<String?> brand,
      Value<String?> partNumber,
      Value<String?> notes,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PartRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $PartRecordsTable> {
  $$PartRecordsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partNumber => $composableBuilder(
    column: $table.partNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PartRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $PartRecordsTable> {
  $$PartRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partNumber => $composableBuilder(
    column: $table.partNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PartRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartRecordsTable> {
  $$PartRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get partNumber => $composableBuilder(
    column: $table.partNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PartRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartRecordsTable,
          PartRecord,
          $$PartRecordsTableFilterComposer,
          $$PartRecordsTableOrderingComposer,
          $$PartRecordsTableAnnotationComposer,
          $$PartRecordsTableCreateCompanionBuilder,
          $$PartRecordsTableUpdateCompanionBuilder,
          (
            PartRecord,
            BaseReferences<_$AppDatabase, $PartRecordsTable, PartRecord>,
          ),
          PartRecord,
          PrefetchHooks Function()
        > {
  $$PartRecordsTableTableManager(_$AppDatabase db, $PartRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> partNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartRecordsCompanion(
                id: id,
                userId: userId,
                vehicleId: vehicleId,
                name: name,
                brand: brand,
                partNumber: partNumber,
                notes: notes,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String vehicleId,
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> partNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PartRecordsCompanion.insert(
                id: id,
                userId: userId,
                vehicleId: vehicleId,
                name: name,
                brand: brand,
                partNumber: partNumber,
                notes: notes,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PartRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartRecordsTable,
      PartRecord,
      $$PartRecordsTableFilterComposer,
      $$PartRecordsTableOrderingComposer,
      $$PartRecordsTableAnnotationComposer,
      $$PartRecordsTableCreateCompanionBuilder,
      $$PartRecordsTableUpdateCompanionBuilder,
      (
        PartRecord,
        BaseReferences<_$AppDatabase, $PartRecordsTable, PartRecord>,
      ),
      PartRecord,
      PrefetchHooks Function()
    >;
typedef $$ServicePartRecordsTableCreateCompanionBuilder =
    ServicePartRecordsCompanion Function({
      required String id,
      required String serviceRecordId,
      required String partId,
      required String name,
      Value<int> rowid,
    });
typedef $$ServicePartRecordsTableUpdateCompanionBuilder =
    ServicePartRecordsCompanion Function({
      Value<String> id,
      Value<String> serviceRecordId,
      Value<String> partId,
      Value<String> name,
      Value<int> rowid,
    });

class $$ServicePartRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ServicePartRecordsTable> {
  $$ServicePartRecordsTableFilterComposer({
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

  ColumnFilters<String> get serviceRecordId => $composableBuilder(
    column: $table.serviceRecordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServicePartRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServicePartRecordsTable> {
  $$ServicePartRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get serviceRecordId => $composableBuilder(
    column: $table.serviceRecordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServicePartRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServicePartRecordsTable> {
  $$ServicePartRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serviceRecordId => $composableBuilder(
    column: $table.serviceRecordId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$ServicePartRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServicePartRecordsTable,
          ServicePartRecord,
          $$ServicePartRecordsTableFilterComposer,
          $$ServicePartRecordsTableOrderingComposer,
          $$ServicePartRecordsTableAnnotationComposer,
          $$ServicePartRecordsTableCreateCompanionBuilder,
          $$ServicePartRecordsTableUpdateCompanionBuilder,
          (
            ServicePartRecord,
            BaseReferences<
              _$AppDatabase,
              $ServicePartRecordsTable,
              ServicePartRecord
            >,
          ),
          ServicePartRecord,
          PrefetchHooks Function()
        > {
  $$ServicePartRecordsTableTableManager(
    _$AppDatabase db,
    $ServicePartRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServicePartRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServicePartRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServicePartRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serviceRecordId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServicePartRecordsCompanion(
                id: id,
                serviceRecordId: serviceRecordId,
                partId: partId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serviceRecordId,
                required String partId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => ServicePartRecordsCompanion.insert(
                id: id,
                serviceRecordId: serviceRecordId,
                partId: partId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServicePartRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServicePartRecordsTable,
      ServicePartRecord,
      $$ServicePartRecordsTableFilterComposer,
      $$ServicePartRecordsTableOrderingComposer,
      $$ServicePartRecordsTableAnnotationComposer,
      $$ServicePartRecordsTableCreateCompanionBuilder,
      $$ServicePartRecordsTableUpdateCompanionBuilder,
      (
        ServicePartRecord,
        BaseReferences<
          _$AppDatabase,
          $ServicePartRecordsTable,
          ServicePartRecord
        >,
      ),
      ServicePartRecord,
      PrefetchHooks Function()
    >;
typedef $$FuelTypeRecordsTableCreateCompanionBuilder =
    FuelTypeRecordsCompanion Function({
      required String id,
      required String userId,
      required String name,
      required String kind,
      required String unit,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FuelTypeRecordsTableUpdateCompanionBuilder =
    FuelTypeRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<String> kind,
      Value<String> unit,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$FuelTypeRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FuelTypeRecordsTable> {
  $$FuelTypeRecordsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FuelTypeRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FuelTypeRecordsTable> {
  $$FuelTypeRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FuelTypeRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FuelTypeRecordsTable> {
  $$FuelTypeRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FuelTypeRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FuelTypeRecordsTable,
          FuelTypeRecord,
          $$FuelTypeRecordsTableFilterComposer,
          $$FuelTypeRecordsTableOrderingComposer,
          $$FuelTypeRecordsTableAnnotationComposer,
          $$FuelTypeRecordsTableCreateCompanionBuilder,
          $$FuelTypeRecordsTableUpdateCompanionBuilder,
          (
            FuelTypeRecord,
            BaseReferences<
              _$AppDatabase,
              $FuelTypeRecordsTable,
              FuelTypeRecord
            >,
          ),
          FuelTypeRecord,
          PrefetchHooks Function()
        > {
  $$FuelTypeRecordsTableTableManager(
    _$AppDatabase db,
    $FuelTypeRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FuelTypeRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FuelTypeRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FuelTypeRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FuelTypeRecordsCompanion(
                id: id,
                userId: userId,
                name: name,
                kind: kind,
                unit: unit,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String name,
                required String kind,
                required String unit,
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FuelTypeRecordsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                kind: kind,
                unit: unit,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FuelTypeRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FuelTypeRecordsTable,
      FuelTypeRecord,
      $$FuelTypeRecordsTableFilterComposer,
      $$FuelTypeRecordsTableOrderingComposer,
      $$FuelTypeRecordsTableAnnotationComposer,
      $$FuelTypeRecordsTableCreateCompanionBuilder,
      $$FuelTypeRecordsTableUpdateCompanionBuilder,
      (
        FuelTypeRecord,
        BaseReferences<_$AppDatabase, $FuelTypeRecordsTable, FuelTypeRecord>,
      ),
      FuelTypeRecord,
      PrefetchHooks Function()
    >;
typedef $$FuelLogRecordsTableCreateCompanionBuilder =
    FuelLogRecordsCompanion Function({
      required String id,
      required String userId,
      required String vehicleId,
      required String kind,
      required String fuelTypeId,
      required String fuelTypeName,
      required String unit,
      required DateTime loggedOn,
      required double amount,
      required double cost,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FuelLogRecordsTableUpdateCompanionBuilder =
    FuelLogRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> vehicleId,
      Value<String> kind,
      Value<String> fuelTypeId,
      Value<String> fuelTypeName,
      Value<String> unit,
      Value<DateTime> loggedOn,
      Value<double> amount,
      Value<double> cost,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$FuelLogRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FuelLogRecordsTable> {
  $$FuelLogRecordsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuelTypeId => $composableBuilder(
    column: $table.fuelTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuelTypeName => $composableBuilder(
    column: $table.fuelTypeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FuelLogRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FuelLogRecordsTable> {
  $$FuelLogRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelTypeId => $composableBuilder(
    column: $table.fuelTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelTypeName => $composableBuilder(
    column: $table.fuelTypeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FuelLogRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FuelLogRecordsTable> {
  $$FuelLogRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get fuelTypeId => $composableBuilder(
    column: $table.fuelTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fuelTypeName => $composableBuilder(
    column: $table.fuelTypeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedOn =>
      $composableBuilder(column: $table.loggedOn, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FuelLogRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FuelLogRecordsTable,
          FuelLogRecord,
          $$FuelLogRecordsTableFilterComposer,
          $$FuelLogRecordsTableOrderingComposer,
          $$FuelLogRecordsTableAnnotationComposer,
          $$FuelLogRecordsTableCreateCompanionBuilder,
          $$FuelLogRecordsTableUpdateCompanionBuilder,
          (
            FuelLogRecord,
            BaseReferences<_$AppDatabase, $FuelLogRecordsTable, FuelLogRecord>,
          ),
          FuelLogRecord,
          PrefetchHooks Function()
        > {
  $$FuelLogRecordsTableTableManager(
    _$AppDatabase db,
    $FuelLogRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FuelLogRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FuelLogRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FuelLogRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> fuelTypeId = const Value.absent(),
                Value<String> fuelTypeName = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<DateTime> loggedOn = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<double> cost = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FuelLogRecordsCompanion(
                id: id,
                userId: userId,
                vehicleId: vehicleId,
                kind: kind,
                fuelTypeId: fuelTypeId,
                fuelTypeName: fuelTypeName,
                unit: unit,
                loggedOn: loggedOn,
                amount: amount,
                cost: cost,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String vehicleId,
                required String kind,
                required String fuelTypeId,
                required String fuelTypeName,
                required String unit,
                required DateTime loggedOn,
                required double amount,
                required double cost,
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FuelLogRecordsCompanion.insert(
                id: id,
                userId: userId,
                vehicleId: vehicleId,
                kind: kind,
                fuelTypeId: fuelTypeId,
                fuelTypeName: fuelTypeName,
                unit: unit,
                loggedOn: loggedOn,
                amount: amount,
                cost: cost,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FuelLogRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FuelLogRecordsTable,
      FuelLogRecord,
      $$FuelLogRecordsTableFilterComposer,
      $$FuelLogRecordsTableOrderingComposer,
      $$FuelLogRecordsTableAnnotationComposer,
      $$FuelLogRecordsTableCreateCompanionBuilder,
      $$FuelLogRecordsTableUpdateCompanionBuilder,
      (
        FuelLogRecord,
        BaseReferences<_$AppDatabase, $FuelLogRecordsTable, FuelLogRecord>,
      ),
      FuelLogRecord,
      PrefetchHooks Function()
    >;
typedef $$ExpenseRecordsTableCreateCompanionBuilder =
    ExpenseRecordsCompanion Function({
      required String id,
      required String vehicleId,
      required String category,
      required double amount,
      required DateTime incurredOn,
      Value<String?> notes,
      Value<String?> receiptLocalPath,
      Value<String?> receiptMediaId,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ExpenseRecordsTableUpdateCompanionBuilder =
    ExpenseRecordsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> category,
      Value<double> amount,
      Value<DateTime> incurredOn,
      Value<String?> notes,
      Value<String?> receiptLocalPath,
      Value<String?> receiptMediaId,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ExpenseRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ExpenseRecordsTable> {
  $$ExpenseRecordsTableFilterComposer({
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

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get incurredOn => $composableBuilder(
    column: $table.incurredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptLocalPath => $composableBuilder(
    column: $table.receiptLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptMediaId => $composableBuilder(
    column: $table.receiptMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpenseRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpenseRecordsTable> {
  $$ExpenseRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get incurredOn => $composableBuilder(
    column: $table.incurredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptLocalPath => $composableBuilder(
    column: $table.receiptLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptMediaId => $composableBuilder(
    column: $table.receiptMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpenseRecordsTable> {
  $$ExpenseRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get incurredOn => $composableBuilder(
    column: $table.incurredOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get receiptLocalPath => $composableBuilder(
    column: $table.receiptLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptMediaId => $composableBuilder(
    column: $table.receiptMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExpenseRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpenseRecordsTable,
          ExpenseRecord,
          $$ExpenseRecordsTableFilterComposer,
          $$ExpenseRecordsTableOrderingComposer,
          $$ExpenseRecordsTableAnnotationComposer,
          $$ExpenseRecordsTableCreateCompanionBuilder,
          $$ExpenseRecordsTableUpdateCompanionBuilder,
          (
            ExpenseRecord,
            BaseReferences<_$AppDatabase, $ExpenseRecordsTable, ExpenseRecord>,
          ),
          ExpenseRecord,
          PrefetchHooks Function()
        > {
  $$ExpenseRecordsTableTableManager(
    _$AppDatabase db,
    $ExpenseRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime> incurredOn = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> receiptLocalPath = const Value.absent(),
                Value<String?> receiptMediaId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseRecordsCompanion(
                id: id,
                vehicleId: vehicleId,
                category: category,
                amount: amount,
                incurredOn: incurredOn,
                notes: notes,
                receiptLocalPath: receiptLocalPath,
                receiptMediaId: receiptMediaId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String category,
                required double amount,
                required DateTime incurredOn,
                Value<String?> notes = const Value.absent(),
                Value<String?> receiptLocalPath = const Value.absent(),
                Value<String?> receiptMediaId = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExpenseRecordsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                category: category,
                amount: amount,
                incurredOn: incurredOn,
                notes: notes,
                receiptLocalPath: receiptLocalPath,
                receiptMediaId: receiptMediaId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpenseRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpenseRecordsTable,
      ExpenseRecord,
      $$ExpenseRecordsTableFilterComposer,
      $$ExpenseRecordsTableOrderingComposer,
      $$ExpenseRecordsTableAnnotationComposer,
      $$ExpenseRecordsTableCreateCompanionBuilder,
      $$ExpenseRecordsTableUpdateCompanionBuilder,
      (
        ExpenseRecord,
        BaseReferences<_$AppDatabase, $ExpenseRecordsTable, ExpenseRecord>,
      ),
      ExpenseRecord,
      PrefetchHooks Function()
    >;
typedef $$ExpensePartRecordsTableCreateCompanionBuilder =
    ExpensePartRecordsCompanion Function({
      required String id,
      required String expenseId,
      required String partId,
      required String name,
      Value<int> rowid,
    });
typedef $$ExpensePartRecordsTableUpdateCompanionBuilder =
    ExpensePartRecordsCompanion Function({
      Value<String> id,
      Value<String> expenseId,
      Value<String> partId,
      Value<String> name,
      Value<int> rowid,
    });

class $$ExpensePartRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensePartRecordsTable> {
  $$ExpensePartRecordsTableFilterComposer({
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

  ColumnFilters<String> get expenseId => $composableBuilder(
    column: $table.expenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpensePartRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensePartRecordsTable> {
  $$ExpensePartRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get expenseId => $composableBuilder(
    column: $table.expenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpensePartRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensePartRecordsTable> {
  $$ExpensePartRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get expenseId =>
      $composableBuilder(column: $table.expenseId, builder: (column) => column);

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$ExpensePartRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpensePartRecordsTable,
          ExpensePartRecord,
          $$ExpensePartRecordsTableFilterComposer,
          $$ExpensePartRecordsTableOrderingComposer,
          $$ExpensePartRecordsTableAnnotationComposer,
          $$ExpensePartRecordsTableCreateCompanionBuilder,
          $$ExpensePartRecordsTableUpdateCompanionBuilder,
          (
            ExpensePartRecord,
            BaseReferences<
              _$AppDatabase,
              $ExpensePartRecordsTable,
              ExpensePartRecord
            >,
          ),
          ExpensePartRecord,
          PrefetchHooks Function()
        > {
  $$ExpensePartRecordsTableTableManager(
    _$AppDatabase db,
    $ExpensePartRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensePartRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensePartRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensePartRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> expenseId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensePartRecordsCompanion(
                id: id,
                expenseId: expenseId,
                partId: partId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String expenseId,
                required String partId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => ExpensePartRecordsCompanion.insert(
                id: id,
                expenseId: expenseId,
                partId: partId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpensePartRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpensePartRecordsTable,
      ExpensePartRecord,
      $$ExpensePartRecordsTableFilterComposer,
      $$ExpensePartRecordsTableOrderingComposer,
      $$ExpensePartRecordsTableAnnotationComposer,
      $$ExpensePartRecordsTableCreateCompanionBuilder,
      $$ExpensePartRecordsTableUpdateCompanionBuilder,
      (
        ExpensePartRecord,
        BaseReferences<
          _$AppDatabase,
          $ExpensePartRecordsTable,
          ExpensePartRecord
        >,
      ),
      ExpensePartRecord,
      PrefetchHooks Function()
    >;
typedef $$NotificationRecordsTableCreateCompanionBuilder =
    NotificationRecordsCompanion Function({
      required String id,
      required String userId,
      Value<String?> vehicleId,
      Value<String?> planItemId,
      required String title,
      required String body,
      Value<String> status,
      Value<String?> dueReason,
      Value<String?> cycleKey,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NotificationRecordsTableUpdateCompanionBuilder =
    NotificationRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> vehicleId,
      Value<String?> planItemId,
      Value<String> title,
      Value<String> body,
      Value<String> status,
      Value<String?> dueReason,
      Value<String?> cycleKey,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$NotificationRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationRecordsTable> {
  $$NotificationRecordsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planItemId => $composableBuilder(
    column: $table.planItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueReason => $composableBuilder(
    column: $table.dueReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleKey => $composableBuilder(
    column: $table.cycleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationRecordsTable> {
  $$NotificationRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planItemId => $composableBuilder(
    column: $table.planItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueReason => $composableBuilder(
    column: $table.dueReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleKey => $composableBuilder(
    column: $table.cycleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationRecordsTable> {
  $$NotificationRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get planItemId => $composableBuilder(
    column: $table.planItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get dueReason =>
      $composableBuilder(column: $table.dueReason, builder: (column) => column);

  GeneratedColumn<String> get cycleKey =>
      $composableBuilder(column: $table.cycleKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotificationRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationRecordsTable,
          NotificationRecord,
          $$NotificationRecordsTableFilterComposer,
          $$NotificationRecordsTableOrderingComposer,
          $$NotificationRecordsTableAnnotationComposer,
          $$NotificationRecordsTableCreateCompanionBuilder,
          $$NotificationRecordsTableUpdateCompanionBuilder,
          (
            NotificationRecord,
            BaseReferences<
              _$AppDatabase,
              $NotificationRecordsTable,
              NotificationRecord
            >,
          ),
          NotificationRecord,
          PrefetchHooks Function()
        > {
  $$NotificationRecordsTableTableManager(
    _$AppDatabase db,
    $NotificationRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> vehicleId = const Value.absent(),
                Value<String?> planItemId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> dueReason = const Value.absent(),
                Value<String?> cycleKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationRecordsCompanion(
                id: id,
                userId: userId,
                vehicleId: vehicleId,
                planItemId: planItemId,
                title: title,
                body: body,
                status: status,
                dueReason: dueReason,
                cycleKey: cycleKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> vehicleId = const Value.absent(),
                Value<String?> planItemId = const Value.absent(),
                required String title,
                required String body,
                Value<String> status = const Value.absent(),
                Value<String?> dueReason = const Value.absent(),
                Value<String?> cycleKey = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotificationRecordsCompanion.insert(
                id: id,
                userId: userId,
                vehicleId: vehicleId,
                planItemId: planItemId,
                title: title,
                body: body,
                status: status,
                dueReason: dueReason,
                cycleKey: cycleKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationRecordsTable,
      NotificationRecord,
      $$NotificationRecordsTableFilterComposer,
      $$NotificationRecordsTableOrderingComposer,
      $$NotificationRecordsTableAnnotationComposer,
      $$NotificationRecordsTableCreateCompanionBuilder,
      $$NotificationRecordsTableUpdateCompanionBuilder,
      (
        NotificationRecord,
        BaseReferences<
          _$AppDatabase,
          $NotificationRecordsTable,
          NotificationRecord
        >,
      ),
      NotificationRecord,
      PrefetchHooks Function()
    >;
typedef $$FamilyRecordsTableCreateCompanionBuilder =
    FamilyRecordsCompanion Function({
      required String id,
      required String name,
      required String shareCode,
      Value<String?> qrCodeData,
      required String createdBy,
      Value<String> status,
      required DateTime createdAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$FamilyRecordsTableUpdateCompanionBuilder =
    FamilyRecordsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> shareCode,
      Value<String?> qrCodeData,
      Value<String> createdBy,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$FamilyRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyRecordsTable> {
  $$FamilyRecordsTableFilterComposer({
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

  ColumnFilters<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrCodeData => $composableBuilder(
    column: $table.qrCodeData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyRecordsTable> {
  $$FamilyRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrCodeData => $composableBuilder(
    column: $table.qrCodeData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyRecordsTable> {
  $$FamilyRecordsTableAnnotationComposer({
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

  GeneratedColumn<String> get shareCode =>
      $composableBuilder(column: $table.shareCode, builder: (column) => column);

  GeneratedColumn<String> get qrCodeData => $composableBuilder(
    column: $table.qrCodeData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$FamilyRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyRecordsTable,
          FamilyRecord,
          $$FamilyRecordsTableFilterComposer,
          $$FamilyRecordsTableOrderingComposer,
          $$FamilyRecordsTableAnnotationComposer,
          $$FamilyRecordsTableCreateCompanionBuilder,
          $$FamilyRecordsTableUpdateCompanionBuilder,
          (
            FamilyRecord,
            BaseReferences<_$AppDatabase, $FamilyRecordsTable, FamilyRecord>,
          ),
          FamilyRecord,
          PrefetchHooks Function()
        > {
  $$FamilyRecordsTableTableManager(_$AppDatabase db, $FamilyRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> shareCode = const Value.absent(),
                Value<String?> qrCodeData = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyRecordsCompanion(
                id: id,
                name: name,
                shareCode: shareCode,
                qrCodeData: qrCodeData,
                createdBy: createdBy,
                status: status,
                createdAt: createdAt,
                archivedAt: archivedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String shareCode,
                Value<String?> qrCodeData = const Value.absent(),
                required String createdBy,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyRecordsCompanion.insert(
                id: id,
                name: name,
                shareCode: shareCode,
                qrCodeData: qrCodeData,
                createdBy: createdBy,
                status: status,
                createdAt: createdAt,
                archivedAt: archivedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyRecordsTable,
      FamilyRecord,
      $$FamilyRecordsTableFilterComposer,
      $$FamilyRecordsTableOrderingComposer,
      $$FamilyRecordsTableAnnotationComposer,
      $$FamilyRecordsTableCreateCompanionBuilder,
      $$FamilyRecordsTableUpdateCompanionBuilder,
      (
        FamilyRecord,
        BaseReferences<_$AppDatabase, $FamilyRecordsTable, FamilyRecord>,
      ),
      FamilyRecord,
      PrefetchHooks Function()
    >;
typedef $$FamilyMembershipRecordsTableCreateCompanionBuilder =
    FamilyMembershipRecordsCompanion Function({
      required String id,
      required String familyId,
      required String userId,
      required String role,
      required DateTime joinedAt,
      Value<String?> invitedBy,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$FamilyMembershipRecordsTableUpdateCompanionBuilder =
    FamilyMembershipRecordsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> userId,
      Value<String> role,
      Value<DateTime> joinedAt,
      Value<String?> invitedBy,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$FamilyMembershipRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyMembershipRecordsTable> {
  $$FamilyMembershipRecordsTableFilterComposer({
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

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invitedBy => $composableBuilder(
    column: $table.invitedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyMembershipRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyMembershipRecordsTable> {
  $$FamilyMembershipRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invitedBy => $composableBuilder(
    column: $table.invitedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyMembershipRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyMembershipRecordsTable> {
  $$FamilyMembershipRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<String> get invitedBy =>
      $composableBuilder(column: $table.invitedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$FamilyMembershipRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyMembershipRecordsTable,
          FamilyMembershipRecord,
          $$FamilyMembershipRecordsTableFilterComposer,
          $$FamilyMembershipRecordsTableOrderingComposer,
          $$FamilyMembershipRecordsTableAnnotationComposer,
          $$FamilyMembershipRecordsTableCreateCompanionBuilder,
          $$FamilyMembershipRecordsTableUpdateCompanionBuilder,
          (
            FamilyMembershipRecord,
            BaseReferences<
              _$AppDatabase,
              $FamilyMembershipRecordsTable,
              FamilyMembershipRecord
            >,
          ),
          FamilyMembershipRecord,
          PrefetchHooks Function()
        > {
  $$FamilyMembershipRecordsTableTableManager(
    _$AppDatabase db,
    $FamilyMembershipRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyMembershipRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FamilyMembershipRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FamilyMembershipRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<String?> invitedBy = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyMembershipRecordsCompanion(
                id: id,
                familyId: familyId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                invitedBy: invitedBy,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String userId,
                required String role,
                required DateTime joinedAt,
                Value<String?> invitedBy = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyMembershipRecordsCompanion.insert(
                id: id,
                familyId: familyId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                invitedBy: invitedBy,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyMembershipRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyMembershipRecordsTable,
      FamilyMembershipRecord,
      $$FamilyMembershipRecordsTableFilterComposer,
      $$FamilyMembershipRecordsTableOrderingComposer,
      $$FamilyMembershipRecordsTableAnnotationComposer,
      $$FamilyMembershipRecordsTableCreateCompanionBuilder,
      $$FamilyMembershipRecordsTableUpdateCompanionBuilder,
      (
        FamilyMembershipRecord,
        BaseReferences<
          _$AppDatabase,
          $FamilyMembershipRecordsTable,
          FamilyMembershipRecord
        >,
      ),
      FamilyMembershipRecord,
      PrefetchHooks Function()
    >;
typedef $$VehicleGrantRecordsTableCreateCompanionBuilder =
    VehicleGrantRecordsCompanion Function({
      required String id,
      required String vehicleId,
      required String userId,
      required String grantedBy,
      required String permission,
      required DateTime createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$VehicleGrantRecordsTableUpdateCompanionBuilder =
    VehicleGrantRecordsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> userId,
      Value<String> grantedBy,
      Value<String> permission,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$VehicleGrantRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleGrantRecordsTable> {
  $$VehicleGrantRecordsTableFilterComposer({
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

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grantedBy => $composableBuilder(
    column: $table.grantedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VehicleGrantRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleGrantRecordsTable> {
  $$VehicleGrantRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grantedBy => $composableBuilder(
    column: $table.grantedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehicleGrantRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleGrantRecordsTable> {
  $$VehicleGrantRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get grantedBy =>
      $composableBuilder(column: $table.grantedBy, builder: (column) => column);

  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$VehicleGrantRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehicleGrantRecordsTable,
          VehicleGrantRecord,
          $$VehicleGrantRecordsTableFilterComposer,
          $$VehicleGrantRecordsTableOrderingComposer,
          $$VehicleGrantRecordsTableAnnotationComposer,
          $$VehicleGrantRecordsTableCreateCompanionBuilder,
          $$VehicleGrantRecordsTableUpdateCompanionBuilder,
          (
            VehicleGrantRecord,
            BaseReferences<
              _$AppDatabase,
              $VehicleGrantRecordsTable,
              VehicleGrantRecord
            >,
          ),
          VehicleGrantRecord,
          PrefetchHooks Function()
        > {
  $$VehicleGrantRecordsTableTableManager(
    _$AppDatabase db,
    $VehicleGrantRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleGrantRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleGrantRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VehicleGrantRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> grantedBy = const Value.absent(),
                Value<String> permission = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleGrantRecordsCompanion(
                id: id,
                vehicleId: vehicleId,
                userId: userId,
                grantedBy: grantedBy,
                permission: permission,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String userId,
                required String grantedBy,
                required String permission,
                required DateTime createdAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleGrantRecordsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                userId: userId,
                grantedBy: grantedBy,
                permission: permission,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehicleGrantRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehicleGrantRecordsTable,
      VehicleGrantRecord,
      $$VehicleGrantRecordsTableFilterComposer,
      $$VehicleGrantRecordsTableOrderingComposer,
      $$VehicleGrantRecordsTableAnnotationComposer,
      $$VehicleGrantRecordsTableCreateCompanionBuilder,
      $$VehicleGrantRecordsTableUpdateCompanionBuilder,
      (
        VehicleGrantRecord,
        BaseReferences<
          _$AppDatabase,
          $VehicleGrantRecordsTable,
          VehicleGrantRecord
        >,
      ),
      VehicleGrantRecord,
      PrefetchHooks Function()
    >;
typedef $$DrivingLicenseRecordsTableCreateCompanionBuilder =
    DrivingLicenseRecordsCompanion Function({
      required String id,
      required String userId,
      Value<String?> licenseNumber,
      Value<String?> issuingCountry,
      required DateTime expiryDate,
      Value<String?> categories,
      Value<String?> frontMediaId,
      Value<String?> backMediaId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> syncedAt,
      Value<int> rowid,
    });
typedef $$DrivingLicenseRecordsTableUpdateCompanionBuilder =
    DrivingLicenseRecordsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> licenseNumber,
      Value<String?> issuingCountry,
      Value<DateTime> expiryDate,
      Value<String?> categories,
      Value<String?> frontMediaId,
      Value<String?> backMediaId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> syncedAt,
      Value<int> rowid,
    });

class $$DrivingLicenseRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DrivingLicenseRecordsTable> {
  $$DrivingLicenseRecordsTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licenseNumber => $composableBuilder(
    column: $table.licenseNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuingCountry => $composableBuilder(
    column: $table.issuingCountry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frontMediaId => $composableBuilder(
    column: $table.frontMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backMediaId => $composableBuilder(
    column: $table.backMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DrivingLicenseRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DrivingLicenseRecordsTable> {
  $$DrivingLicenseRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licenseNumber => $composableBuilder(
    column: $table.licenseNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuingCountry => $composableBuilder(
    column: $table.issuingCountry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frontMediaId => $composableBuilder(
    column: $table.frontMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backMediaId => $composableBuilder(
    column: $table.backMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DrivingLicenseRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DrivingLicenseRecordsTable> {
  $$DrivingLicenseRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get licenseNumber => $composableBuilder(
    column: $table.licenseNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get issuingCountry => $composableBuilder(
    column: $table.issuingCountry,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frontMediaId => $composableBuilder(
    column: $table.frontMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backMediaId => $composableBuilder(
    column: $table.backMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$DrivingLicenseRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DrivingLicenseRecordsTable,
          DrivingLicenseRecord,
          $$DrivingLicenseRecordsTableFilterComposer,
          $$DrivingLicenseRecordsTableOrderingComposer,
          $$DrivingLicenseRecordsTableAnnotationComposer,
          $$DrivingLicenseRecordsTableCreateCompanionBuilder,
          $$DrivingLicenseRecordsTableUpdateCompanionBuilder,
          (
            DrivingLicenseRecord,
            BaseReferences<
              _$AppDatabase,
              $DrivingLicenseRecordsTable,
              DrivingLicenseRecord
            >,
          ),
          DrivingLicenseRecord,
          PrefetchHooks Function()
        > {
  $$DrivingLicenseRecordsTableTableManager(
    _$AppDatabase db,
    $DrivingLicenseRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrivingLicenseRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DrivingLicenseRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DrivingLicenseRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> licenseNumber = const Value.absent(),
                Value<String?> issuingCountry = const Value.absent(),
                Value<DateTime> expiryDate = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> frontMediaId = const Value.absent(),
                Value<String?> backMediaId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DrivingLicenseRecordsCompanion(
                id: id,
                userId: userId,
                licenseNumber: licenseNumber,
                issuingCountry: issuingCountry,
                expiryDate: expiryDate,
                categories: categories,
                frontMediaId: frontMediaId,
                backMediaId: backMediaId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> licenseNumber = const Value.absent(),
                Value<String?> issuingCountry = const Value.absent(),
                required DateTime expiryDate,
                Value<String?> categories = const Value.absent(),
                Value<String?> frontMediaId = const Value.absent(),
                Value<String?> backMediaId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DrivingLicenseRecordsCompanion.insert(
                id: id,
                userId: userId,
                licenseNumber: licenseNumber,
                issuingCountry: issuingCountry,
                expiryDate: expiryDate,
                categories: categories,
                frontMediaId: frontMediaId,
                backMediaId: backMediaId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DrivingLicenseRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DrivingLicenseRecordsTable,
      DrivingLicenseRecord,
      $$DrivingLicenseRecordsTableFilterComposer,
      $$DrivingLicenseRecordsTableOrderingComposer,
      $$DrivingLicenseRecordsTableAnnotationComposer,
      $$DrivingLicenseRecordsTableCreateCompanionBuilder,
      $$DrivingLicenseRecordsTableUpdateCompanionBuilder,
      (
        DrivingLicenseRecord,
        BaseReferences<
          _$AppDatabase,
          $DrivingLicenseRecordsTable,
          DrivingLicenseRecord
        >,
      ),
      DrivingLicenseRecord,
      PrefetchHooks Function()
    >;
typedef $$FamilyVehicleRecordsTableCreateCompanionBuilder =
    FamilyVehicleRecordsCompanion Function({
      required String id,
      required String familyId,
      required String vehicleId,
      required String addedBy,
      required DateTime addedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$FamilyVehicleRecordsTableUpdateCompanionBuilder =
    FamilyVehicleRecordsCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> vehicleId,
      Value<String> addedBy,
      Value<DateTime> addedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$FamilyVehicleRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyVehicleRecordsTable> {
  $$FamilyVehicleRecordsTableFilterComposer({
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

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FamilyVehicleRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyVehicleRecordsTable> {
  $$FamilyVehicleRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyVehicleRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyVehicleRecordsTable> {
  $$FamilyVehicleRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get addedBy =>
      $composableBuilder(column: $table.addedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$FamilyVehicleRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyVehicleRecordsTable,
          FamilyVehicleRecord,
          $$FamilyVehicleRecordsTableFilterComposer,
          $$FamilyVehicleRecordsTableOrderingComposer,
          $$FamilyVehicleRecordsTableAnnotationComposer,
          $$FamilyVehicleRecordsTableCreateCompanionBuilder,
          $$FamilyVehicleRecordsTableUpdateCompanionBuilder,
          (
            FamilyVehicleRecord,
            BaseReferences<
              _$AppDatabase,
              $FamilyVehicleRecordsTable,
              FamilyVehicleRecord
            >,
          ),
          FamilyVehicleRecord,
          PrefetchHooks Function()
        > {
  $$FamilyVehicleRecordsTableTableManager(
    _$AppDatabase db,
    $FamilyVehicleRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyVehicleRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyVehicleRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FamilyVehicleRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> addedBy = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyVehicleRecordsCompanion(
                id: id,
                familyId: familyId,
                vehicleId: vehicleId,
                addedBy: addedBy,
                addedAt: addedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String vehicleId,
                required String addedBy,
                required DateTime addedAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyVehicleRecordsCompanion.insert(
                id: id,
                familyId: familyId,
                vehicleId: vehicleId,
                addedBy: addedBy,
                addedAt: addedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FamilyVehicleRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyVehicleRecordsTable,
      FamilyVehicleRecord,
      $$FamilyVehicleRecordsTableFilterComposer,
      $$FamilyVehicleRecordsTableOrderingComposer,
      $$FamilyVehicleRecordsTableAnnotationComposer,
      $$FamilyVehicleRecordsTableCreateCompanionBuilder,
      $$FamilyVehicleRecordsTableUpdateCompanionBuilder,
      (
        FamilyVehicleRecord,
        BaseReferences<
          _$AppDatabase,
          $FamilyVehicleRecordsTable,
          FamilyVehicleRecord
        >,
      ),
      FamilyVehicleRecord,
      PrefetchHooks Function()
    >;
typedef $$DocumentRecordsTableCreateCompanionBuilder =
    DocumentRecordsCompanion Function({
      required String id,
      required String vehicleId,
      required String name,
      required String category,
      Value<String?> notes,
      Value<String?> localFilePath,
      Value<String?> mediaId,
      required DateTime updatedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$DocumentRecordsTableUpdateCompanionBuilder =
    DocumentRecordsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> name,
      Value<String> category,
      Value<String?> notes,
      Value<String?> localFilePath,
      Value<String?> mediaId,
      Value<DateTime> updatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DocumentRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentRecordsTable> {
  $$DocumentRecordsTableFilterComposer({
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

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentRecordsTable> {
  $$DocumentRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentRecordsTable> {
  $$DocumentRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DocumentRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentRecordsTable,
          DocumentRecord,
          $$DocumentRecordsTableFilterComposer,
          $$DocumentRecordsTableOrderingComposer,
          $$DocumentRecordsTableAnnotationComposer,
          $$DocumentRecordsTableCreateCompanionBuilder,
          $$DocumentRecordsTableUpdateCompanionBuilder,
          (
            DocumentRecord,
            BaseReferences<
              _$AppDatabase,
              $DocumentRecordsTable,
              DocumentRecord
            >,
          ),
          DocumentRecord,
          PrefetchHooks Function()
        > {
  $$DocumentRecordsTableTableManager(
    _$AppDatabase db,
    $DocumentRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentRecordsCompanion(
                id: id,
                vehicleId: vehicleId,
                name: name,
                category: category,
                notes: notes,
                localFilePath: localFilePath,
                mediaId: mediaId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String name,
                required String category,
                Value<String?> notes = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                required DateTime updatedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DocumentRecordsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                name: name,
                category: category,
                notes: notes,
                localFilePath: localFilePath,
                mediaId: mediaId,
                updatedAt: updatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentRecordsTable,
      DocumentRecord,
      $$DocumentRecordsTableFilterComposer,
      $$DocumentRecordsTableOrderingComposer,
      $$DocumentRecordsTableAnnotationComposer,
      $$DocumentRecordsTableCreateCompanionBuilder,
      $$DocumentRecordsTableUpdateCompanionBuilder,
      (
        DocumentRecord,
        BaseReferences<_$AppDatabase, $DocumentRecordsTable, DocumentRecord>,
      ),
      DocumentRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$VehicleRecordsTableTableManager get vehicleRecords =>
      $$VehicleRecordsTableTableManager(_db, _db.vehicleRecords);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
  $$PlanItemRecordsTableTableManager get planItemRecords =>
      $$PlanItemRecordsTableTableManager(_db, _db.planItemRecords);
  $$ServiceRecordRowsTableTableManager get serviceRecordRows =>
      $$ServiceRecordRowsTableTableManager(_db, _db.serviceRecordRows);
  $$ServiceLineRecordsTableTableManager get serviceLineRecords =>
      $$ServiceLineRecordsTableTableManager(_db, _db.serviceLineRecords);
  $$PartRecordsTableTableManager get partRecords =>
      $$PartRecordsTableTableManager(_db, _db.partRecords);
  $$ServicePartRecordsTableTableManager get servicePartRecords =>
      $$ServicePartRecordsTableTableManager(_db, _db.servicePartRecords);
  $$FuelTypeRecordsTableTableManager get fuelTypeRecords =>
      $$FuelTypeRecordsTableTableManager(_db, _db.fuelTypeRecords);
  $$FuelLogRecordsTableTableManager get fuelLogRecords =>
      $$FuelLogRecordsTableTableManager(_db, _db.fuelLogRecords);
  $$ExpenseRecordsTableTableManager get expenseRecords =>
      $$ExpenseRecordsTableTableManager(_db, _db.expenseRecords);
  $$ExpensePartRecordsTableTableManager get expensePartRecords =>
      $$ExpensePartRecordsTableTableManager(_db, _db.expensePartRecords);
  $$NotificationRecordsTableTableManager get notificationRecords =>
      $$NotificationRecordsTableTableManager(_db, _db.notificationRecords);
  $$FamilyRecordsTableTableManager get familyRecords =>
      $$FamilyRecordsTableTableManager(_db, _db.familyRecords);
  $$FamilyMembershipRecordsTableTableManager get familyMembershipRecords =>
      $$FamilyMembershipRecordsTableTableManager(
        _db,
        _db.familyMembershipRecords,
      );
  $$VehicleGrantRecordsTableTableManager get vehicleGrantRecords =>
      $$VehicleGrantRecordsTableTableManager(_db, _db.vehicleGrantRecords);
  $$DrivingLicenseRecordsTableTableManager get drivingLicenseRecords =>
      $$DrivingLicenseRecordsTableTableManager(_db, _db.drivingLicenseRecords);
  $$FamilyVehicleRecordsTableTableManager get familyVehicleRecords =>
      $$FamilyVehicleRecordsTableTableManager(_db, _db.familyVehicleRecords);
  $$DocumentRecordsTableTableManager get documentRecords =>
      $$DocumentRecordsTableTableManager(_db, _db.documentRecords);
}
