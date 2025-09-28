// lib/screens/admin_login_view.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_form_widgets.dart';
import 'admin_home_view.dart'; // سننشئها لاحقاً

class AdminLoginView extends StatefulWidget {
  const AdminLoginView({super.key});

  @override
  State<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<AdminLoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _message = "";
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // MARK: - Admin Login Logic
  void _adminLogin() async {
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      // 1. تحقق من صلاحية المشرف في Firestore (كما هو مطلوب في التطبيقات الحقيقية)
      final doc = await FirebaseFirestore.instance.collection("admins").doc(userCredential.user!.uid).get();

      if (doc.exists && (doc.data()?["role"] == "YShopAdmin")) {
        // 2. نجاح تسجيل الدخول والانتقال إلى شاشة المشرف
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AdminHomeView(),
            ),
          );
        }
      } else {
        // إذا كان المستخدم موجودًا في Auth ولكنه ليس مشرفًا في Firestore
        await FirebaseAuth.instance.signOut(); // إخراجه لخطأ في الصلاحيات
        setState(() => _message = "Access denied. You are not a YShop Administrator.");
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _message = "Login failed: ${e.message}");
    } catch (e) {
      setState(() => _message = "An error occurred: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('YShop Admin Login'),
        centerTitle: true,
        backgroundColor: primaryText, // لون مختلف يبرز شاشة الإدارة
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  "Admin Access",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 40),
                UnderlinedTextField(
                  placeholder: "Admin Email",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                UnderlinedSecureField(
                  placeholder: "Password",
                  controller: _passwordController,
                ),
                PrimaryActionButton(
                  title: _isLoading ? "Logging in..." : "Admin Login",
                  action: _isLoading ? () {} : _adminLogin,
                ),
                const SizedBox(height: 20),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}