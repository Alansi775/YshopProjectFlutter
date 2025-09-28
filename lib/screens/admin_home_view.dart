// lib/screens/admin_home_view.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      // الرجوع إلى أول شاشة (شاشة تسجيل الدخول)
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YShop Admin Panel'),
        centerTitle: true,
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_rounded, size: 80, color: Colors.black87),
            const SizedBox(height: 20),
            Text(
              "Welcome, YShop Administrator!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Manage Store Requests, Users, and Content.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            // يمكن إضافة أزرار الإجراءات الرئيسية هنا:
            ElevatedButton.icon(
              onPressed: () {
                // توجيه إلى صفحة مراجعة طلبات المتاجر
              },
              icon: const Icon(Icons.store),
              label: const Text("Review Store Requests"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                // توجيه إلى صفحة إدارة المستخدمين
              },
              icon: const Icon(Icons.people),
              label: const Text("Manage Users"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}