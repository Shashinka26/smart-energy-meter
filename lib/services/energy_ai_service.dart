import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EnergyAiService {
  EnergyAiService._();

  static final EnergyAiService instance = EnergyAiService._();

  // Cloud API (Render) — always available, no PC needed.
  // Override at build time: --dart-define=CHATBOT_API_URL=https://your-url.onrender.com
  static const String _baseUrl = String.fromEnvironment(
    'CHATBOT_API_URL',
    defaultValue: 'https://smart-energy-chatbot-api.onrender.com',
  );

  bool _ready = false;
  String? _error;

  bool get isReady => _ready;
  String? get initError => _error;
  String? get activeModel => 'Groq';

  Future<void> initialize() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        _ready = true;
        _error = null;
      } else {
        throw Exception('Chatbot API returned ${response.statusCode}');
      }
    } catch (e) {
      _ready = false;
      _error = e.toString();
      debugPrint('Chatbot API connection failed: $e');
    }
  }

  Future<String> sendMessage(String userMessage) async {
    if (!_ready) {
      await initialize();
    }

    if (!_ready) {
      throw StateError('Chatbot API is not reachable. $_error');
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': userMessage}),
        )
        .timeout(const Duration(seconds: 60));

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return data['reply'] as String;
    }

    throw Exception(data['error'] ?? 'Chatbot request failed.');
  }

  String friendlyError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('timed out') ||
        text.contains('failed host lookup')) {
      return 'Cannot reach the chatbot server. Check your internet connection. If this is the first request after idle, wait 30 seconds and try again.';
    }

    return 'The AI assistant could not respond right now. Please try again.';
  }
}
