// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserConfigAdapter extends TypeAdapter<UserConfig> {
  @override
  final int typeId = 2;

  @override
  UserConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserConfig(
      userId: fields[0] as String,
      userName: fields[1] as String,
      userTrigramme: fields[2] as String,
      shiftDurationHours: fields[3] as int,
      notificationDelayMinutes: fields[4] as int,
      shiftStartTime: fields[5] as TimeOfDay,
      shiftEndTime: fields[6] as TimeOfDay,
      notificationsEnabled: fields[7] as bool,
      darkModeEnabled: fields[8] as bool,
      themeColor: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserConfig obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.userTrigramme)
      ..writeByte(3)
      ..write(obj.shiftDurationHours)
      ..writeByte(4)
      ..write(obj.notificationDelayMinutes)
      ..writeByte(5)
      ..write(obj.shiftStartTime)
      ..writeByte(6)
      ..write(obj.shiftEndTime)
      ..writeByte(7)
      ..write(obj.notificationsEnabled)
      ..writeByte(8)
      ..write(obj.darkModeEnabled)
      ..writeByte(9)
      ..write(obj.themeColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
