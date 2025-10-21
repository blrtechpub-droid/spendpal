import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const CustomCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}