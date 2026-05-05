import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<String> askAI(String prompt) async {
    const maxRetries = 2;
    const url = "https://askai-3iarja6fya-uc.a.run.app";

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                "Content-Type": "application/json",
                "Accept": "application/json",
              },
              body: jsonEncode({"prompt": prompt}),
            )
            .timeout(const Duration(seconds: 30));

        // ✅ Debug logs (IMPORTANT)
        print("🔥 STATUS: ${response.statusCode}");
        print("🔥 BODY: ${response.body}");

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);

            // ✅ Flexible parsing
            if (data is Map) {
              if (data.containsKey("reply")) {
                return data["reply"].toString().trim();
              }
              if (data.containsKey("error")) {
                return "⚠️ ${data["error"]}";
              }
            }

            return "⚠️ Unexpected response format";
          } catch (e) {
            return "⚠️ Invalid JSON response";
          }
        }

        // Retry on 5xx
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
          continue;
        }

        return "❌ Server Error: ${response.statusCode}";
      } catch (e) {
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
          continue;
        }
        return "❌ Network Error: ${e.toString().split('\n').first}";
      }
    }

    return "❌ Failed after retries";
  }
}