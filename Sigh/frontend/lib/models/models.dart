class Session {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final int participantCount;

  Session({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.participantCount,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      participantCount: json['participant_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }
}

class Person {
  final String id;
  final String name;
  final String role;
  final DateTime createdAt;

  Person({
    required this.id,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
    };
  }
}

class SessionPerson {
  final String id;
  final String session;
  final String person;
  final String personName;
  final String sessionName;
  final bool isPresent;
  final DateTime? lastSeen;

  SessionPerson({
    required this.id,
    required this.session,
    required this.person,
    required this.personName,
    required this.sessionName,
    required this.isPresent,
    this.lastSeen,
  });

  factory SessionPerson.fromJson(Map<String, dynamic> json) {
    return SessionPerson(
      id: json['id'].toString(),
      session: json['session'].toString(),
      person: json['person'].toString(),
      personName: json['person_name'],
      sessionName: json['session_name'],
      isPresent: json['is_present'],
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }
}

class DashboardStats {
  final int totalSessions;
  final int totalPeople;
  final int activeSessions;
  final int todayAttendance;

  DashboardStats({
    required this.totalSessions,
    required this.totalPeople,
    required this.activeSessions,
    required this.todayAttendance,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSessions: json['total_sessions'],
      totalPeople: json['total_people'],
      activeSessions: json['active_sessions'],
      todayAttendance: json['today_attendance'],
    );
  }
}