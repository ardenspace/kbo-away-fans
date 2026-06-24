import 'package:flutter/material.dart';

class StadiumScreen extends StatelessWidget {
  const StadiumScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('구장 가이드 $id — task-011')),
    );
  }
}
