import 'package:flutter/material.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Store Orders")),
      body: const Center(
        child: Text("Orders list will appear here."),
      ),
    );
  }
}