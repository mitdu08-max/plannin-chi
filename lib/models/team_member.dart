import 'package:hive/hive.dart';

part 'team_member.g.dart';

@HiveType(typeId: 0)
class TeamMember extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String firstName;

  @HiveField(2)
  final String lastName;

  @HiveField(3)
  final String trigramme;

  @HiveField(4)
  final int orderIndex;

  TeamMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.trigramme,
    this.orderIndex = 0,
  });

  String get fullName => lastName.isNotEmpty ? '$firstName $lastName' : firstName;

  String get displayName => lastName.isNotEmpty ? '$firstName ${lastName.substring(0, 1).toUpperCase()}.' : firstName;

  TeamMember copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? trigramme,
    int? orderIndex,
  }) {
    return TeamMember(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      trigramme: trigramme ?? this.trigramme,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  String toString() {
    return 'TeamMember(id: $id, firstName: $firstName, lastName: $lastName, trigramme: $trigramme)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamMember && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}