import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String _model = 'gemini-2.5-flash';

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('ไม่พบ GEMINI_API_KEY');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ]
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API Error: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'];

    if (candidates == null ||
        candidates is! List ||
        candidates.isEmpty) {
      throw Exception('Gemini ไม่ส่งผลลัพธ์กลับมา');
    }

    return candidates[0]['content']['parts'][0]['text'];
  }
}