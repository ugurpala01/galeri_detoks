// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 1;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      id: fields[0] as String,
      scanDate: fields[1] as DateTime,
      detectedAssetIds: (fields[2] as List).cast<String>(),
      totalScanned: fields[3] as int,
      detectedCount: fields[4] as int,
      keywords: (fields[5] as List).cast<String>(),
      deletedCount: fields[6] as int? ?? 0,
      scannedAssetIds: (fields[7] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scanDate)
      ..writeByte(2)
      ..write(obj.detectedAssetIds)
      ..writeByte(3)
      ..write(obj.totalScanned)
      ..writeByte(4)
      ..write(obj.detectedCount)
      ..writeByte(5)
      ..write(obj.keywords)
      ..writeByte(6)
      ..write(obj.deletedCount);
    writer
      ..writeByte(7)
      ..write(obj.scannedAssetIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
