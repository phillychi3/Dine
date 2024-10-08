import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userId = '';
  String currentQuestion = '';
  String currentAnswer = '';
  String recommendation = '';
  List<Map<String, String>> recommendedRestaurants = [];
  bool conversationCompleted = false;
  String errorMessage = '';
  String location = ''; // New variable for location
  TextEditingController answerController = TextEditingController(); // New controller for answer input
  TextEditingController locationController = TextEditingController(); // New controller for location input

  final String baseUrl = 'http://127.0.0.1:8000'; // Android emulator
  // final String baseUrl = 'http://localhost:8000'; // iOS simulator
  // final String baseUrl = 'http://your.actual.server.address'; // Production server

  @override
  void initState() {
    super.initState();
    startConversation();
  }

  @override
  void dispose() {
    answerController.dispose();
    locationController.dispose();
    super.dispose();
  }

  String generateRandomUserId() {
    return Random().nextInt(1000000).toString().padLeft(6, '0');
  }

  Future<void> startConversation() async {
    setState(() {
      userId = generateRandomUserId();
      errorMessage = '';
      conversationCompleted = false;
      recommendation = '';
      recommendedRestaurants = [];
      answerController.clear();
      locationController.clear();
    });
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/start_conversation/').replace(queryParameters: {'user_id': userId}),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentQuestion = data['question'];
        });
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error starting conversation: $e';
      });
      print(errorMessage);
    }
  }

  Future<void> answerQuestion() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/answer_question/').replace(queryParameters: {'user_id': userId, 'answer': currentAnswer}),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['message'] == 'Conversation completed') {
            conversationCompleted = true;
            recommendation = data['recommendation'];
          } else {
            currentQuestion = data['next_question'];
          }
          answerController.clear(); // Clear the answer input
          currentAnswer = '';
        });
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error answering question: $e';
      });
      print(errorMessage);
    }
  }

  Future<void> getRecommendedRestaurants() async {
    if (location.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a location';
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_recommendation_restaurant/').replace(queryParameters: {'user_id': userId, 'locate': location}),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            recommendedRestaurants = List<Map<String, String>>.from(data['recommendation']['restaurants']);
          });
        } else {
          throw Exception('Failed to get restaurant recommendations: ${data['message']}');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error getting restaurant recommendations: $e';
      });
      print(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dinner Recommendation'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'User ID: $userId',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(
                'Error: $errorMessage',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            if (!conversationCompleted && errorMessage.isEmpty) ...[
              Text(
                'Question:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(currentQuestion),
              SizedBox(height: 20),
              TextField(
                controller: answerController,
                onChanged: (value) {
                  setState(() {
                    currentAnswer = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Enter your answer',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: answerQuestion,
                child: Text('Submit Answer'),
              ),
            ] else if (conversationCompleted) ...[
              Text(
                'Recommendation:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(recommendation),
              SizedBox(height: 20),
              TextField(
                controller: locationController,
                onChanged: (value) {
                  setState(() {
                    location = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Enter location for restaurant recommendations',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: getRecommendedRestaurants,
                child: Text('Get Restaurant Recommendations'),
              ),
              SizedBox(height: 20),
              Text(
                'Recommended Restaurants:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: recommendedRestaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = recommendedRestaurants[index];
                    return ListTile(
                      title: Text(restaurant['name'] ?? ''),
                      subtitle: Text(restaurant['address'] ?? ''),
                      trailing: Text(restaurant['reason'] ?? ''),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: startConversation,
              child: Text('Restart Conversation'),
            ),
          ],
        ),
      ),
    );
  }
}