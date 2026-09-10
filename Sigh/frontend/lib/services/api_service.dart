import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api'; // For emulator

  final http.Client client;

  ApiService(this.client);

  // Sessions
  Future<List<Session>> getSessions() async {
    final response = await client.get(Uri.parse('$baseUrl/sessions/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      return data.map((json) => Session.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load sessions');
    }
  }

  Future<Session> createSession(Session session) async {
    final response = await client.post(
      Uri.parse('$baseUrl/sessions/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(session.toJson()),
    );
    if (response.statusCode == 201) {
      return Session.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create session');
    }
  }

  Future<void> deleteSession(String id) async {
    final response = await client.delete(Uri.parse('$baseUrl/sessions/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete session');
    }
  }

  // People
  Future<List<Person>> getPeople() async {
    final response = await client.get(Uri.parse('$baseUrl/people/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      return data.map((json) => Person.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load people');
    }
  }

  Future<Person> createPerson(Person person) async {
    final response = await client.post(
      Uri.parse('$baseUrl/people/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(person.toJson()),
    );
    if (response.statusCode == 201) {
      return Person.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create person');
    }
  }

  Future<void> deletePerson(String id) async {
    final response = await client.delete(Uri.parse('$baseUrl/people/$id/'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete person');
    }
  }

  // Dashboard
  Future<DashboardStats> getDashboardStats() async {
    final response = await client.get(Uri.parse('$baseUrl/dashboard/stats/'));
    if (response.statusCode == 200) {
      return DashboardStats.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load dashboard stats');
    }
  }
  // In ApiService class - Add these methods:

// Get session participants
Future<List<SessionPerson>> getSessionParticipants(String sessionId) async {
  final response = await client.get(Uri.parse('$baseUrl/sessions/$sessionId/participants/'));
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => SessionPerson.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load session participants');
  }
}

// Add person to session
Future<SessionPerson> addPersonToSession(String sessionId, String personId) async {
  final response = await client.post(
    Uri.parse('$baseUrl/sessions/$sessionId/participants/'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'person_id': personId}),
  );
  if (response.statusCode == 201) {
    return SessionPerson.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to add person to session');
  }
}

// Remove person from session
Future<void> removePersonFromSession(String sessionId, String personId) async {
  final response = await client.delete(
    Uri.parse('$baseUrl/sessions/$sessionId/participants/$personId/'),
  );
  if (response.statusCode != 204) {
    throw Exception('Failed to remove person from session');
  }
}
}