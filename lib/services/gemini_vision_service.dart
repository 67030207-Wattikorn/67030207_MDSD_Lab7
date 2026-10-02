import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/listing_draft.dart';

class GeminiVisionService {
  // ============================================================
  // API KEY
  // ============================================================

  static const String _apiKey =
      String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  // ============================================================
  // Gemini Model
  // ============================================================

  static const String _model =
      'gemini-3.8-flash';

  // ============================================================
  // วิเคราะห์รูปสินค้า
  // ============================================================

  Future<ListingDraft> analyzeProductImage(
    Uint8List imageBytes,
    String prompt,
  ) async {
    // ตรวจ API Key
    if (_apiKey.isEmpty) {
      throw Exception(
        'ไม่พบ GEMINI_API_KEY',
      );
    }

    // แปลงรูปเป็น Base64
    final base64Image =
        base64Encode(imageBytes);

    // ============================================================
    // API URL
    // ============================================================

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/'
      'v1beta/models/$_model:generateContent'
      '?key=$_apiKey',
    );

    http.Response? response;

    // ลองสูงสุด 3 ครั้ง
    const maxAttempts = 3;

    // ============================================================
    // Request
    // ============================================================

    for (int attempt = 1;
        attempt <= maxAttempts;
        attempt++) {
      try {
        response = await http.post(
          url,

          headers: {
            'Content-Type':
                'application/json',
          },

          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  // Prompt จาก SellItemPage
                  {
                    'text': prompt,
                  },

                  // รูปภาพ
                  {
                    'inline_data': {
                      'mime_type':
                          'image/jpeg',

                      'data':
                          base64Image,
                    },
                  },
                ],
              },
            ],

            // ==================================================
            // บังคับ JSON
            // ==================================================

            'generationConfig': {
              'responseMimeType':
                  'application/json',

              'responseSchema': {
                'type': 'OBJECT',

                'properties': {
                  'title': {
                    'type': 'STRING',
                  },

                  'category': {
                    'type': 'STRING',
                  },

                  'description': {
                    'type': 'STRING',
                  },
                },

                'required': [
                  'title',
                  'category',
                  'description',
                ],
              },
            },
          }),
        ).timeout(
          const Duration(
            seconds: 30,
          ),
        );

        // ======================================================
        // สำเร็จ
        // ======================================================

        if (response.statusCode == 200) {
          break;
        }

        // ======================================================
        // 503 → Retry
        // ======================================================

        if (response.statusCode == 503 &&
            attempt < maxAttempts) {
          await Future.delayed(
            Duration(
              seconds: attempt * 2,
            ),
          );

          continue;
        }

        // ======================================================
        // Error
        // ======================================================

        throw Exception(
          'Gemini API Error: '
          '${response.statusCode}\n'
          '${response.body}',
        );
      } catch (e) {
        // Timeout → Retry
        if (attempt < maxAttempts &&
            e.toString().contains(
              'TimeoutException',
            )) {
          await Future.delayed(
            Duration(
              seconds: attempt * 2,
            ),
          );

          continue;
        }

        rethrow;
      }
    }

    // ============================================================
    // ไม่มี Response
    // ============================================================

    if (response == null) {
      throw Exception(
        'ไม่สามารถเชื่อมต่อ Gemini API ได้',
      );
    }

    // ============================================================
    // ตรวจ Status Code
    // ============================================================

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API Error: '
        '${response.statusCode}\n'
        '${response.body}',
      );
    }

    // ============================================================
    // อ่าน Response
    // ============================================================

    try {
      final data =
          jsonDecode(response.body);

      final candidates =
          data['candidates'];

      // ==========================================================
      // ไม่มี Candidate
      // ==========================================================

      if (candidates == null ||
          candidates is! List ||
          candidates.isEmpty) {
        throw Exception(
          'AI ไม่สามารถวิเคราะห์ภาพนี้ได้ '
          'อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม '
          'ลองใช้ภาพหรือคำขออื่น',
        );
      }

      // ==========================================================
      // ตรวจ Safety
      // ==========================================================

      final finishReason =
          candidates[0]['finishReason'];

      if (finishReason == 'SAFETY') {
        throw Exception(
          'เนื้อหาที่วิเคราะห์เข้าข่าย '
          'ไม่ปลอดภัยตามนโยบายของ Gemini '
          'กรุณาใช้ภาพหรือคำขออื่น',
        );
      }

      // ==========================================================
      // Content
      // ==========================================================

      final content =
          candidates[0]['content'];

      if (content == null) {
        throw Exception(
          'Gemini ไม่ส่งผลลัพธ์กลับมา',
        );
      }

      final parts =
          content['parts'];

      if (parts == null ||
          parts is! List ||
          parts.isEmpty) {
        throw Exception(
          'Gemini ไม่ส่งผลลัพธ์กลับมา',
        );
      }

      // ==========================================================
      // Text
      // ==========================================================

      final text =
          parts[0]['text'];

      if (text == null ||
          text.toString().isEmpty) {
        throw Exception(
          'Gemini ไม่ส่งข้อความกลับมา',
        );
      }

      // ==========================================================
      // JSON
      // ==========================================================

      final jsonString =
          jsonDecode(
        text.toString(),
      );

      // ==========================================================
      // ListingDraft
      // ==========================================================

      return ListingDraft.fromJson(
        jsonString,
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'ไม่สามารถอ่านผลลัพธ์จาก Gemini ได้\n'
        '$e',
      );
    }
  }
}