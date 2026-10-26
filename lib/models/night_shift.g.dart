// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'night_shift.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NightShiftAdapter extends TypeAdapter<NightShift> {
  @override
  final int typeId = 1;

  @override
  NightShift read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NightShift(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      agentId: fields[2] as String,
      agentTrigramme: fields[3] as String,
      startTime: fields[4] as TimeOfDay,
      endTime: fields[5] as TimeOfDay,
      isWorking: fields[6] as bool,
      coWorkerIds: (fields[7] as List).cast<String>(),
      isManualOverride: fields[8] as bool,
      isVacation: fields[9] == null ? false : fields[9] as bool,
      vacationType: fields[10] == null ? '' : fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NightShift obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.agentId)
      ..writeByte(3)
      ..write(obj.agentTrigramme)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.isWorking)
      ..writeByte(7)
      ..write(obj.coWorkerIds)
      ..writeByte(8)
      ..write(obj.isManualOverride)
      ..writeByte(9)
      ..write(obj.isVacation)
      ..writeByte(10)
      ..write(obj.vacationType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NightShiftAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
