import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EnergyAiService {
  EnergyAiService._();

  static final EnergyAiService instance = EnergyAiService._();

  // Local Groq server on your PC (port 5001).
  // Android emulator: http://10.0.2.2:5001
  // Physical phone: use your PC Wi-Fi IP from ipconfig (e.g. 10.113.220.30).
  static const String _baseUrl = String.fromEnvironment(
    'CHATBOT_API_URL',
    defaultValue: 'http://10.113.220.30:5001',
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
          .timeout(const Duration(seconds: 10));

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
      return 'Cannot connect to chatbot server.\n\n'
          '1. Run START_CHATBOT.bat on your PC\n'
          '2. Phone and PC on same Wi-Fi\n'
          '3. Check PC IP matches the app (currently 10.113.220.30)';
    }

    return 'The AI assistant could not respond right now. Please try again.';
  }
}
