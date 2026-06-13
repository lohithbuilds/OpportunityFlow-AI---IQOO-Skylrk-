import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';

/// API service for communicating with the FastAPI backend.
class ApiService {
  // Change this to your backend URL
  static const String baseUrl = kIsWeb ? 'http://localhost:8080/api' : 'http://10.0.2.2:8080/api';

  final http.Client _client = http.Client();

  // ── Upload ──────────────────────────────────────────────────

  /// Upload a document and get extracted opportunity data.
  Future<Map<String, dynamic>> uploadDocument({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));
    } else {
      throw ArgumentError('Either filePath or fileBytes must be provided');
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();
    return json.decode(body);
  }

  // ── Opportunities ───────────────────────────────────────────

  /// Get a specific opportunity by ID.
  Future<Map<String, dynamic>> getOpportunity(String id) async {
    final response = await _client.get(Uri.parse('$baseUrl/opportunities/$id'));
    return json.decode(response.body);
  }

  /// List all opportunities.
  Future<Map<String, dynamic>> listOpportunities() async {
    final response = await _client.get(Uri.parse('$baseUrl/opportunities'));
    return json.decode(response.body);
  }

  /// Toggle bookmark.
  Future<Map<String, dynamic>> toggleBookmark(String id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/opportunities/$id/bookmark'),
    );
    return json.decode(response.body);
  }

  // ── Chat ────────────────────────────────────────────────────

  /// Send a chat message to the AI mentor.
  Future<Map<String, dynamic>> sendChatMessage({
    required String opportunityId,
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'opportunity_id': opportunityId,
        'message': message,
        'conversation_history': history,
      }),
    );
    return json.decode(response.body);
  }

  // ── Eligibility ─────────────────────────────────────────────

  /// Check eligibility for an opportunity.
  Future<Map<String, dynamic>> checkEligibility({
    required String opportunityId,
    int? age,
    String? grade,
    String? college,
    List<String>? skills,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/eligibility'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'opportunity_id': opportunityId,
        'age': age,
        'grade': grade,
        'college': college,
        'skills': skills ?? [],
      }),
    );
    return json.decode(response.body);
  }

  // ── Summary ─────────────────────────────────────────────────

  /// Get opportunity summary at a detail level.
  Future<Map<String, dynamic>> getSummary(String id, {String level = 'short'}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/opportunities/$id/summary?level=$level'),
    );
    return json.decode(response.body);
  }

  // ── Roadmap ─────────────────────────────────────────────────

  /// Generate preparation roadmap.
  Future<Map<String, dynamic>> generateRoadmap({
    required String opportunityId,
    int durationDays = 7,
    List<String>? userSkills,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/roadmap'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'opportunity_id': opportunityId,
        'duration_days': durationDays,
        'user_skills': userSkills ?? [],
      }),
    );
    return json.decode(response.body);
  }

  // ── Dashboard ───────────────────────────────────────────────

  /// Get dashboard data.
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _client.get(Uri.parse('$baseUrl/dashboard'));
    return json.decode(response.body);
  }

  void dispose() {
    _client.close();
  }
}
