// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_statistics.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanStatisticsAdapter extends TypeAdapter<ScanStatistics> {
  @override
  final int typeId = 0;

  @override
  ScanStatistics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanStatistics(
      id: fields[0] as String,
      scannedAt: fields[1] as DateTime,
      totalScanned: fields[2] as int,
      totalDeleted: fields[3] as int,
      detectedCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ScanStatistics obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scannedAt)
      ..writeByte(2)
      ..write(obj.totalScanned)
      ..writeByte(3)
      ..write(obj.totalDeleted)
      ..writeByte(4)
      ..write(obj.detectedCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanStatisticsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
