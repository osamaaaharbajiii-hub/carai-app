import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // رابط السيرفر المباشر المرفوع على Render
  static const String baseUrl = 'https://carai-backend-2dw4.onrender.com/api/diagnose';

  // دالة إرسال وصف العطل واستلام التشخيص من الذكاء الاصطناعي
  static Future<Map<String, dynamic>> sendDiagnosisRequest(String issueDescription) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'issue': issueDescription}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'فشل الاتصال بالسيرفر. رمز الاستجابة: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'خطأ في الشبكة أو الاتصال: $e'
      };
    }
  }
}

