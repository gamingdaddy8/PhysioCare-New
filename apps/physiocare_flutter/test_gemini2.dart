import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'AIzaSyC99d8Ac6jwJ9CKmH0-KAyQiHtyYoTNE6g';
  final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  final response = await http.get(Uri.parse('$endpoint?key=$apiKey'));
  print(response.body);
}
