import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result returned by the AI analysis service.
class AiResult {
  final String analysis;
  final String recommendations;
  AiResult({required this.analysis, required this.recommendations});
}

class AIService {
  static const _apiKey = String.fromEnvironment('DEEPSEEK_API_KEY');
  // Do NOT set defaults here; allow runtime (SharedPreferences) to override when env is absent.
  static const _baseUrlEnv = String.fromEnvironment('DEEPSEEK_BASE_URL');
  static const _modelEnv = String.fromEnvironment('DEEPSEEK_MODEL');

  // Runtime config keys (stored in SharedPreferences)
  static const _kPrefApiKey = 'deepseek_api_key';
  static const _kPrefBaseUrl = 'deepseek_base_url';
  static const _kPrefModel = 'deepseek_model';

  /// Save runtime config for DeepSeek (optional fallback if dart-define not passed)
  static Future<void> saveRuntimeConfig({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey != null) await prefs.setString(_kPrefApiKey, apiKey);
    if (baseUrl != null) await prefs.setString(_kPrefBaseUrl, baseUrl); 
    if (model != null) await prefs.setString(_kPrefModel, model);
  }

  /// Resolve effective config: prefer dart-define; fallback to SharedPreferences; finally defaults.
  static Future<({String apiKey, String baseUrl, String model})>
      _resolveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey =
        _apiKey.isNotEmpty ? _apiKey : (prefs.getString(_kPrefApiKey) ?? '');
    final baseUrl = _baseUrlEnv.isNotEmpty
        ? _baseUrlEnv
        : (prefs.getString(_kPrefBaseUrl) ?? 'https://api.deepseek.com');
    final model = _modelEnv.isNotEmpty
        ? _modelEnv
        : (prefs.getString(_kPrefModel) ?? 'deepseek-chat');
    return (apiKey: apiKey, baseUrl: baseUrl, model: model);
  }

  /// High-level helper that asks the LLM to produce a concise analysis
  /// and actionable recommendations in JSON form.
  static Future<AiResult> analyze({
    required String monthLabel,
    required Map<String, dynamic> summary,
    Duration timeout = const Duration(seconds: 30),
    double temperature = 0.2,
  }) async {
    final cfg = await _resolveConfig();
    if (cfg.apiKey.isEmpty) {
      // Developer has not provided a key; return a friendly fallback.
      return AiResult(
        analysis:
            'Chưa cấu hình khoá API cho DeepSeek. Vui lòng chạy app với --dart-define=DEEPSEEK_API_KEY=... để bật phân tích AI.',
        recommendations:
            '1) Thêm khoá API an toàn bằng --dart-define\n2) Tuỳ chọn: cấu hình DEEPSEEK_BASE_URL và DEEPSEEK_MODEL',
      );
    }

    final uri = Uri.parse('${cfg.baseUrl}/chat/completions');

    final systemPrompt =
        'Bạn là chuyên gia chất lượng không khí trong nhà (IAQ). Dựa trên dữ liệu JSON cung cấp cho giai đoạn "$monthLabel", hãy phân tích CHI TIẾT và THỰC DỤNG.\n\n'
        'YÊU CẦU ĐẦU RA: Trả về một JSON duy nhất với 2 khoá:\n'
        '1) "analysis": đoạn văn 120–200 từ, súc tích nhưng đầy đủ, nêu: (a) mức IAQ chung, (b) số liệu nổi bật (trung bình, min/max, tổng mẫu), '
        '(c) tỉ lệ phần trăm theo các mức EPA (Good/Moderate/…), (d) khuynh hướng rủi ro nếu có. Trình bày bằng tiếng Việt, có số liệu cụ thể từ JSON.\n'
        '2) "recommendations": 5–8 gạch đầu dòng, ưu tiên theo mức độ tác động, ngắn gọn – rõ ràng – có thể hành động ngay (ví dụ tần suất, ngưỡng, thời điểm).\n\n'
        'NGUYÊN TẮC: chỉ sử dụng dữ liệu trong JSON; không bịa số liệu; diễn giải phù hợp bối cảnh (ngày/tuần/tháng) của giai đoạn. Trả lời bằng tiếng Việt.';

    final userPrompt = jsonEncode({
      'month': monthLabel,
      'summary': summary,
    });

    final body = {
      'model': cfg.model,
      'temperature': temperature,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content':
              'Dưới đây là dữ liệu tổng hợp ở dạng JSON, hãy phân tích và xuất JSON theo yêu cầu:\n$userPrompt'
        },
      ],
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${cfg.apiKey}',
    };

    final resp = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('AI API error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI API: no choices');
    }
    final msg = choices.first['message'] as Map<String, dynamic>?;
    final content = msg?['content']?.toString() ?? '';

    // Expect a JSON object. Try to parse; if it fails, wrap content as analysis.
    try {
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      return AiResult(
        analysis: (parsed['analysis'] ?? '').toString(),
        recommendations: (parsed['recommendations'] ?? '').toString(),
      );
    } catch (_) {
      return AiResult(analysis: content, recommendations: '');
    }
  }
}
