// lib/screens/admin_login_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_home_view.dart'; // AdminHomeView.dart

//  تعريف الألوان الداكنة لمطابقة SwiftUI .systemGroupedBackground
const Color kDarkBackground = Color(0xFF1C1C1E);
const Color kCardBackground = Color(0xFF2C2C2E);
const Color kPrimaryTextColor = Colors.white;

//  ودجت مُبسطة لمحاكاة تصميم SwiftUI
class SimpleTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isSecure;

  const SimpleTextField({
    super.key,
    required this.placeholder,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isSecure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isSecure,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      //  النص المُدخل سيكون أبيض
      style: const TextStyle(fontSize: 16, color: kPrimaryTextColor),
      decoration: InputDecoration(
        hintText: placeholder,
        //  لون نص الـ Placeholder
        hintStyle: TextStyle(color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        //  خلفية حقل الإدخال داكنة
        fillColor: kCardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1),
        ),
      ),
    );
  }
}


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

  //  بيانات اعتماد المسؤول الثابتة
  static const String _ADMIN_EMAIL = "mohamedalezzi6@gmail.com";
  static const String _ADMIN_PASSWORD = "Alansi77";


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // MARK: - Admin Login Logic (تحقق ثابت)
  void _adminLogin() async {
    setState(() {
      _isLoading = true;
      _message = "";
    });

    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text.trim();

    if (enteredEmail == _ADMIN_EMAIL && enteredPassword == _ADMIN_PASSWORD) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdminHomeView(),
          ),
        );
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _message = "Invalid email or password";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //  إعداد النظام ليكون الوضع الداكن (نص شريط الحالة فاتح)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      //  خلفية الشاشة سوداء أنيقة
      backgroundColor: kDarkBackground,
      //  إزالة الـ AppBar القياسي
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                //  زر الرجوع (Back Button)
                Align(
                  alignment: Alignment.topLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      // محاكاة زر SwiftUI "Back"
                      backgroundColor: Colors.blue, 
                      foregroundColor: kPrimaryTextColor, // نص أبيض
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Back"),
                  ),
                ),

                const SizedBox(height: 30),

                //  العنوان الكبير
                const Text(
                  "Admin Login", 
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryTextColor, // نص أبيض
                  ),
                ),
                const SizedBox(height: 40),
                
                // حقول الإدخال
                SimpleTextField(
                  placeholder: "Email",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                SimpleTextField(
                  placeholder: "Password",
                  controller: _passwordController,
                  isSecure: true,
                ),
                const SizedBox(height: 30),
                
                // زر الدخول (Login Button)
                ElevatedButton(
                  onPressed: _isLoading ? null : _adminLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // لون أزرق بارز
                    foregroundColor: kPrimaryTextColor, // نص أبيض
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isLoading ? "Logging in..." : "Login",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                
                // رسالة الخطأ
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