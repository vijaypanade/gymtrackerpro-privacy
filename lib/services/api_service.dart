import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<String> askAI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse("https://askai-3iarja6fya-uc.a.run.app"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "prompt": prompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          return data["reply"].toString().trim();
        } else {
          return "⚠️ ${data["error"] ?? "Unknown error"}";
        }
      } else {
        return "❌ Server Error: ${response.statusCode}";
      }
    } catch (e) {
      return "❌ Network Error: $e";
    }
  }
}