import 'package:flutter/material.dart';
import 'package:frontend/screens/grocery_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: GroceryListPage(),
        ),
      ),
    );
  }
}
