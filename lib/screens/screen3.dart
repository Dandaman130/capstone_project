/*
Current State 12/3/25 Last Modified v(Alpha 2.0)
Changes Made: Dec 1, 2025
*/

import 'package:flutter/material.dart';

class Screen3 extends StatelessWidget {
  const Screen3({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: const Center(
        child: Text('Saved Things & flags go here'),
      ),
    );
  }
}