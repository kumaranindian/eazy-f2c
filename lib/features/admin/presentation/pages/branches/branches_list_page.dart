import 'package:flutter/material.dart';

class BranchesListPage extends StatelessWidget {
  const BranchesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
        backgroundColor: Colors.green[700],
      ),
      body: const Center(
        child: Text(
          'Branch Management Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
