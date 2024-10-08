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
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  String location = '';
  bool isLoading = false;
  TextEditingController answerController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  final String baseUrl = 'http://127.0.0.1:8000'; // Android emulator

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
      isLoading = true;
    });
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/start_conversation/')
                .replace(queryParameters: {'user_id': userId}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentQuestion = data['question'];
          isLoading = false;
        });
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error starting conversation: $e';
        isLoading = false;
      });
      print(errorMessage);
    }
  }

  Future<void> answerQuestion() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/answer_question/').replace(
                queryParameters: {'user_id': userId, 'answer': currentAnswer}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['message'] == 'Conversation completed') {
            conversationCompleted = true;
            recommendation = data['recommendation'];
          } else {
            currentQuestion = data['next_question'];
          }
          answerController.clear();
          currentAnswer = '';
          isLoading = false;
        });
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error answering question: $e';
        isLoading = false;
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
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/get_recommendation_restaurant/').replace(
                queryParameters: {'user_id': userId, 'locate': location}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            recommendedRestaurants = List<Map<String, String>>.from(
                (data['recommendation']['restaurants'] as List).map(
                    (restaurant) =>
                        Map<String, String>.from(restaurant as Map)));
            isLoading = false;
          });
        } else {
          throw Exception(
              'Failed to get restaurant recommendations: ${data['message']}');
        }
      } else {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error getting restaurant recommendations: $e';
        isLoading = false;
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
      body: Stack(
        children: [
          SingleChildScrollView(
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
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.red[100],
                    child: Text(
                      'Error: $errorMessage',
                      style: TextStyle(color: Colors.red[900], fontSize: 16),
                    ),
                  ),
                if (!conversationCompleted && errorMessage.isEmpty) ...[
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(currentQuestion),
                          SizedBox(height: 16),
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
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: answerQuestion,
                            child: Text('Submit Answer'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (conversationCompleted) ...[
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommendation:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(recommendation),
                          SizedBox(height: 16),
                          TextField(
                            controller: locationController,
                            onChanged: (value) {
                              setState(() {
                                location = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Enter location for restaurant recommendations',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: getRecommendedRestaurants,
                            child: Text('Get Restaurant Recommendations'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  if (recommendedRestaurants.isNotEmpty) ...[
                    Text(
                      'Recommended Restaurants:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...recommendedRestaurants
                        .map((restaurant) => Card(
                              elevation: 2,
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(restaurant['name'] ?? ''),
                                subtitle: Text(restaurant['address'] ?? ''),
                                trailing: Chip(
                                  label: Text(restaurant['reason'] ?? ''),
                                  backgroundColor: Colors.blue[100],
                                ),
                              ),
                            ))
                        .toList(),
                  ],
                ],
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: startConversation,
                  child: Text('Restart Conversation'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
