import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'YOUR_API_KEY';
  final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';
  
  final response = await http.post(
    Uri.parse('$endpoint?key=$apiKey'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': 'Write a 1 sentence hello world'},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 300},
    }),
  );
  
  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
