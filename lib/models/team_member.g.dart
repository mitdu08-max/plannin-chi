// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_member.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamMemberAdapter extends TypeAdapter<TeamMember> {
  @override
  final int typeId = 0;

  @override
  TeamMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeamMember(
      id: fields[0] as String,
      firstName: fields[1] as String,
      lastName: fields[2] as String,
      trigramme: fields[3] as String,
      orderIndex: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TeamMember obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.trigramme)
      ..writeByte(4)
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
