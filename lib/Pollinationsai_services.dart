import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final List<Map<String, String>> _messages = [];
  static const int _timeoutSeconds = 60;

  // Pollinations.AI - Free, no API key needed
  static const String _pollinationsBaseUrl = 'https://text.pollinations.ai';
  static const String _pollinationsImageUrl =
      'https://image.pollinations.ai/prompt';

  // Alternative APIs
  static const String _deepaiBaseUrl = 'https://api.deepai.org/api';

  final List<String> _placeholderImages = [
    'https://picsum.photos/512/512?random=1',
    'https://picsum.photos/512/512?random=2',
    'https://picsum.photos/512/512?random=3',
    'https://picsum.photos/512/512?random=4',
    'https://picsum.photos/512/512?random=5',
  ];

  Future<String> handlePrompt(String prompt) async {
    if (prompt.trim().isEmpty) return 'Please provide a valid prompt.';

    if (_isImagePrompt(prompt)) {
      return await generateImage(prompt);
    } else {
      return await generateText(prompt);
    }
  }

  Future<String> generateText(String prompt) async {
    _addMessage('user', prompt);

    try {
      final pollinationsResponse = await _tryPollinationsText(prompt);
      if (pollinationsResponse != null) {
        _addMessage('assistant', pollinationsResponse);
        return pollinationsResponse;
      }

      final hfResponse = await _tryHuggingFaceText(prompt);
      if (hfResponse != null) {
        _addMessage('assistant', hfResponse);
        return hfResponse;
      }
    } catch (e) {
      return 'Network error. Please check your internet connection.';
    }

    return 'Sorry, I could not generate a response at the moment.';
  }

  Future<String> generateImage(String prompt) async {
    _addMessage('user', prompt);

    try {
      final pollinationsResponse = await _tryPollinationsImage(prompt);
      if (pollinationsResponse != null) return pollinationsResponse;

      final deepaiResponse = await _tryDeepAIImage(prompt);
      if (deepaiResponse != null) return deepaiResponse;
    } catch (e) {
      // Silent fallback to placeholder
    }

    return _getRandomPlaceholderImage();
  }

  Future<String?> _tryPollinationsText(String prompt) async {
    try {
      final enhancedPrompt = _buildPromptWithContext(prompt);
      final response = await http
          .post(
            Uri.parse(_pollinationsBaseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are a helpful AI assistant.',
                },
                {'role': 'user', 'content': enhancedPrompt},
              ],
              'model': 'openai',
            }),
          )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {
      // Pollinations failed, try alternative
    }
    return null;
  }

  Future<String?> _tryHuggingFaceText(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'inputs': prompt,
              'options': {'wait_for_model': true},
              'parameters': {'max_new_tokens': 150},
            }),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List &&
            data.isNotEmpty &&
            data[0]['generated_text'] != null) {
          return data[0]['generated_text'].toString().trim();
        }
      }
    } catch (e) {
      // HF API failed
    }
    return null;
  }

  Future<String?> _tryPollinationsImage(String prompt) async {
    try {
      // Direct URL method - no API call needed
      final encodedPrompt = Uri.encodeComponent(prompt);
      final imageUrl =
          '$_pollinationsImageUrl/$encodedPrompt?width=512&height=512&model=flux&enhance=true';

      // Test if URL works
      final response = await http
          .head(Uri.parse(imageUrl))
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return imageUrl;
      }
    } catch (e) {
      // URL method failed
    }
    return null;
  }

  Future<String?> _tryDeepAIImage(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_deepaiBaseUrl/text2img'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': prompt}),
          )
          .timeout(Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['output_url'] != null) {
          return data['output_url'].toString();
        }
      }
    } catch (e) {
      // DeepAI failed
    }
    return null;
  }

  String _buildPromptWithContext(String prompt) {
    if (_messages.isEmpty) return prompt;

    final recentMessages = _messages.length > 4
        ? _messages.sublist(_messages.length - 4)
        : _messages;

    final context = recentMessages
        .map((msg) => '${msg['role']}: ${msg['content']}')
        .join('\n');

    return '$context\nuser: $prompt';
  }

  bool _isImagePrompt(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('image') ||
        lower.contains('picture') ||
        lower.contains('photo') ||
        lower.contains('draw') ||
        lower.contains('create') ||
        lower.contains('generate') ||
        lower.contains('art') ||
        lower.contains('painting') ||
        lower.contains('sketch') ||
        lower.contains('illustration') ||
        lower.contains('design');
  }

  String _getRandomPlaceholderImage() {
    final randomIndex =
        DateTime.now().millisecondsSinceEpoch % _placeholderImages.length;
    return _placeholderImages[randomIndex];
  }

  void _addMessage(String role, String content) {
    _messages.add({'role': role, 'content': content});
    if (_messages.length > 8) _messages.removeAt(0);
  }

  Future<bool> isServiceAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('https://pollinations.ai'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void clearConversation() {
    _messages.clear();
  }

  String getDirectImageUrl(String prompt, {int width = 512, int height = 512}) {
    final encodedPrompt = Uri.encodeComponent(prompt);
    return '$_pollinationsImageUrl/$encodedPrompt?width=$width&height=$height&model=flux&enhance=true&nologo=true';
  }
}

