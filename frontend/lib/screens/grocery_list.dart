import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/screens/camera.dart';
import 'package:frontend/screens/recommendation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class GroceryItem {
  final String name;
  final DateTime expiryDate;
  final String imageUrl;

  GroceryItem({
    required this.name,
    required this.expiryDate,
    required this.imageUrl,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      name: json['name'],
      expiryDate: DateTime.now().add(Duration(days: json['expiryDays'])),
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/150',
    );
  }
}

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({super.key});

  @override
  _GroceryListPageState createState() => _GroceryListPageState();
}

class _GroceryListPageState extends State<GroceryListPage> {
  List<GroceryItem> groceries = [];
  bool isLoading = true;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    initializeNotifications();
    fetchGroceries();
  }

  void initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> fetchGroceries() async {
    final url = Uri.parse('https://hksw4q5b-8000.inc1.devtunnels.ms/products/');
    try {
      final response = await http.get(url);
      print(response.body);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final List<dynamic> data = jsonData['products'];
        setState(() {
          groceries = data.map((item) => GroceryItem.fromJson(item)).toList();
          isLoading = false;
        });
        checkExpiryAndNotify();
      } else {
        throw Exception('Failed to load groceries');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching groceries: $e');
    }
  }

  void checkExpiryAndNotify() {
    final now = DateTime.now();
    for (var item in groceries) {
      if (item.expiryDate.difference(now).inDays <= 3) {
        sendNotification(item.name, item.expiryDate);
        suggestRecipe(item.name);
      }
    }
  }

  void sendNotification(String itemName, DateTime expiryDate) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Notifications',
      channelDescription: 'Notifications for items about to expire',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    flutterLocalNotificationsPlugin.show(
      0,
      'Expiry Alert',
      '$itemName is about to expire on ${_formatDate(expiryDate)}!',
      platformChannelSpecifics,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> suggestRecipe(String ingredient) async {
    final url = Uri.parse(
        'https://api.spoonacular.com/recipes/findByIngredients?ingredients=$ingredient&number=1&apiKey=YOUR_API_KEY');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> recipes = jsonDecode(response.body);
        if (recipes.isNotEmpty) {
          final recipe = recipes.first;
          debugPrint('Suggested Recipe: ${recipe['title']}');
          sendNotification(
              'Recipe Suggestion'
              'Try making "${recipe['title']}" with $ingredient. Link: ${recipe['sourceUrl']}',
              DateTime.now().add(const Duration(days: 1)));
        }
      } else {
        throw Exception('Failed to fetch recipes');
      }
    } catch (e) {
      debugPrint('Error fetching recipes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color.fromARGB(255, 117, 255, 117),
                Color.fromARGB(255, 0, 254, 0),
                Color.fromARGB(255, 117, 255, 117),
              ]),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 60.0, 16.0, 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Hi, Joel 👋',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Pantry',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const RecommendationPage()),
                            );
                          },
                          child: const Icon(Icons.recommend_rounded),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : groceries.isEmpty
                    ? const Center(child: Text('No items found.'))
                    : ListView.builder(
                        itemCount: groceries.length,
                        itemBuilder: (context, index) {
                          final item = groceries[index];
                          return GroceryItemCard(item: item);
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                );
              },
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              label: const Text('Add Item'),
              icon: const Icon(Icons.add_a_photo),
            ),
          )
        ],
      ),
    );
  }
}

class GroceryItemCard extends StatelessWidget {
  final GroceryItem item;

  const GroceryItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(item.imageUrl),
              radius: 30,
              onBackgroundImageError: (error, stackTrace) =>
                  const Icon(Icons.image_not_supported, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expires on ${_formatDate(item.expiryDate)}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
