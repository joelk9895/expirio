import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({Key? key}) : super(key: key);

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  List<Map<String, dynamic>> groceryItems = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchGroceryItems();
  }

  Future<void> fetchGroceryItems() async {
    try {
      final response = await http.get(
        Uri.parse('https://hksw4q5b-8000.inc1.devtunnels.ms/products/'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final List<dynamic> data = jsonData['products'];

        setState(() {
          groceryItems = data
              .where((item) {
                return item['expiryDays'] < 4;
              })
              .map((item) => item as Map<String, dynamic>)
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to fetch grocery items';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _getRecipe(BuildContext context) async {
    try {
      final ingredients = groceryItems.map((item) => item['name']).toList();

      final response = await http.post(
        Uri.parse('https://hksw4q5b-8000.inc1.devtunnels.ms/create-recipe/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ingredients': ingredients}),
      );

      if (response.statusCode == 200) {
        final recipe = json.decode(response.body);
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            recipe['recipe'] ?? 'Recipe',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 20),
                        const SizedBox(width: 8),
                        Text(recipe['cookingTime'] ?? 'N/A'),
                        const SizedBox(width: 16),
                        const Icon(Icons.bar_chart, size: 20),
                        const SizedBox(width: 8),
                        Text('Difficulty: ${recipe['difficulty'] ?? 'N/A'}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (recipe['ingredients'] != null) ...[
                      ...List<String>.from(recipe['ingredients']).map(
                        (ingredient) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record, size: 8),
                              const SizedBox(width: 8),
                              Expanded(child: Text(ingredient)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (recipe['instructions'] != null) ...[
                      ...List<String>.from(recipe['instructions'])
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.key + 1}.',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(entry.value)),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        throw Exception('Failed to get recipe');
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to get recipe: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery List'),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : groceryItems.isEmpty
                        ? const Center(
                            child: Text('No items expiring soon'),
                          )
                        : ListView.builder(
                            itemCount: groceryItems.length,
                            itemBuilder: (context, index) {
                              final item = groceryItems[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.grey[200],
                                        radius: 30,
                                        child: const Icon(Icons.shopping_basket,
                                            size: 30),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Expires in ${item['expiryDays']} days',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.black),
                  foregroundColor: WidgetStateProperty.all(Colors.white)),
              onPressed:
                  groceryItems.isEmpty ? null : () => _getRecipe(context),
              child: const Text('Get Recipe Suggestions'),
            ),
          ),
        ],
      ),
    );
  }
}
