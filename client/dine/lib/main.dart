import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dinner Recommendation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userId = 'user123'; // You might want to generate this or get from user login
  String currentQuestion = '';
  String currentAnswer = '';
  String recommendation = '';

  final String baseUrl = 'http://10.0.2.2:8000'; // Use this for Android emulator
  // final String baseUrl = 'http://localhost:8000'; // Use this for iOS simulator

  @override
  void initState() {
    super.initState();
    startConversation();
  }

  Future<void> startConversation() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/start_conversation/'),
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentQuestion = data['question'];
        });
      } else {
        throw Exception('Failed to start conversation');
      }
    } catch (e) {
      print('Error starting conversation: $e');
      // Show error message to user
    }
  }

  Future<void> answerQuestion() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/answer_question/'),
        queryParameters: {'user_id': userId, 'answer': currentAnswer},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentQuestion = data['next_question'];
          currentAnswer = '';
        });
      } else {
        throw Exception('Failed to submit answer');
      }
    } catch (e) {
      print('Error answering question: $e');
      // Show error message to user
    }
  }

  Future<void> getRecommendation() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_recommendation/'),
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          recommendation = data['recommendation'];
        });
      } else {
        throw Exception('Failed to get recommendation');
      }
    } catch (e) {
      print('Error getting recommendation: $e');
      // Show error message to user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinner Recommendation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Question:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(currentQuestion),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) {
                setState(() {
                  currentAnswer = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Enter your answer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: answerQuestion,
              child: const Text('Submit Answer'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: getRecommendation,
              child: const Text('Get Recommendation'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recommendation:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(recommendation),
          ],
        ),
      ),
    );
  }
}