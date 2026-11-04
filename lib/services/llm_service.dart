import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/email_parsing.dart';
import '../core/extraction.dart';

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Calls the OpenAI Chat Completions API to extract actions from a message.
///
/// Prototype note: the app calls OpenAI directly with a key stored on the
/// device. A production build should route this through a backend.
class LlmService {
  LlmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final _endpoint = Uri.parse('https://api.openai.com/v1/chat/completions');
  static const maxBodyChars = 6000;

  Future<List<ExtractedAction>> extract({
    required String apiKey,
    required String model,
    required String subject,
    required String from,
    required String body,
    required List<String> children,
    String? sentDate,
    DateTime? today,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw LlmException('Add your OpenAI API key in Settings first.');
    }
    final payload = {
      'model': model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': buildSystemPrompt(
              today: today ?? DateTime.now(), children: children),
        },
        {
          'role': 'user',
          'content': buildUserPrompt(
            subject: subject,
            from: from,
            sentDate: sentDate,
            body: truncate(body, maxBodyChars),
          ),
        },
      ],
    };

    final http.Response res;
    try {
      res = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } on Exception catch (e) {
      throw LlmException('Could not reach OpenAI: $e');
    }

    if (res.statusCode != 200) {
      String detail = res.body;
      try {
        detail = (jsonDecode(res.body)['error']['message'] as String?) ?? detail;
      } catch (_) {}
      throw LlmException('OpenAI error ${res.statusCode}: $detail');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content =
        ((decoded['choices'] as List).first as Map)['message']['content'] as String?;
    return parseExtraction(content ?? '', children: children);
  }
}
