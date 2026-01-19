// lib/screens/admin_login_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../admin/admin_home_view.dart'; // AdminHomeView.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

//  تعريف الألوان الداكنة
const Color kDarkBackground = Color(0xFF1C1C1E); // خلفية الشاشة
const Color kCardBackground = Color(0xFF2C2C2E); // خلفية البطاقات والأقسام
const Color kAppBarBackground = Color(0xFF1C1C1E); // خلفية شريط التطبيق
const Color kPrimaryTextColor = Colors.white; // النص الأساسي
const Color kSecondaryTextColor = Colors.white70; // النص الثانوي/الرمادي
const Color kSeparatorColor = Color(0xFF48484A); // لون الفاصل/الحدود
//  يجب التأكد من تعريف kAccentBlue هنا إذا كان غير موجود
const Color kAccentBlue = Color(0xFF007AFF); // اللون الأزرق المميز

//  تعريف ألوان الشيمر (لتشغيل الشيمر بشكل مستقل)
const Color primaryText = Colors.black; // هذا اللون لن يستخدم في الـ Admin View لكن يجب تعريفه
const Color accentBlue = kAccentBlue; 

// MARK: - Welcoming Page Shimmer Widget (تم نسخه من الملف الخارجي)
class WelcomingPageShimmer extends StatelessWidget {
  const WelcomingPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. نص الترحيب العادي
        const Text(
          "Welcome to",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            //  ملاحظة: هذا هو النص الوحيد المسموح بـ bold (و w900 هنا قوي جدًا)
            fontWeight: FontWeight.w700, 
            color: Colors.grey, // لون يتناسب مع الخلفية الداكنة
          ),
        ),
        const SizedBox(height: 5),

        // 2. دمج Shimmer و RichText للتأثير المخصص
        Shimmer.fromColors(
          baseColor: Colors.grey.shade600, // لون نص "HOP" المبدئي
          highlightColor: accentBlue, // اللون الأزرق الجذاب الذي ينتشر
          period: const Duration(seconds: 8), 
          child: Text.rich(
            TextSpan(
              children: [
                // YS بلون أزرق أنيق وثابت
                const TextSpan(
                  text: "YS",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: accentBlue, 
                  ),
                ),
                // HOP بلون يتأثر بالشيمر
                TextSpan(
                  text: "HOP",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade600, // اللون الأساسي للشيمر
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
// MARK: - نهاية Welcoming Page Shimmer

//  ودجت مُبسطة لمحاكاة تصميم SwiftUI
class SimpleTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isSecure;
  final ValueChanged<String>? onSubmitted; // إضافة خاصية onSubmitted
  final bool isBoldText; // خاصية للتحكم في Bold (افتراضيًا False)
  final Color cursorColor; // خاصية للتحكم في لون المؤشر (Cursor)

  const SimpleTextField({
    super.key,
    required this.placeholder,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isSecure = false,
    this.onSubmitted,
    this.isBoldText = false, // القيمة الافتراضية
    this.cursorColor = kPrimaryTextColor, // لون المؤشر الافتراضي أبيض
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
      onSubmitted: onSubmitted, // تمرير خاصية onSubmitted
      cursorColor: cursorColor,// تطبيق لون المؤشر
      //  إلغاء خاصية Bold من نص الإدخال
      style: TextStyle(
        fontSize: 16, 
        color: kPrimaryTextColor,
        fontWeight: isBoldText ? FontWeight.bold : FontWeight.normal,
      ),
      //  تخصيص لون التضليل
      // لم نعد بحاجة إلى selectionHandleColor بعد إزالة الخطأ السابق

      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: kDarkBackground, 
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
          borderSide: const BorderSide(color: kAccentBlue, width: 1),
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
  DateTime? _loginCooldownUntil;

  // Remove hardcoded credentials: use backend admin login


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tryRestoreAdminSession();
  }

  Future<void> _tryRestoreAdminSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('admin_token');
      final expiryMs = prefs.getInt('admin_token_expiry');
      if (token != null && expiryMs != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        if (DateTime.now().isBefore(expiry)) {
          // Already signed in as admin - navigate to admin home
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminHomeView()),
          );
        }
      }
    } catch (_) {}
  }

  // MARK: - Admin Login Logic (تحقق ثابت)
  void _adminLogin() async {
    // منع الضغط على الزر أو Enter إذا كان التحميل جاريًا
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _message = "";
    });

    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text.trim();

    try {
      final res = await ApiService.adminLogin(enteredEmail, enteredPassword);
      if (res != null && res['success'] == true) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AdminHomeView(),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _message = res['message'] ?? 'Invalid email or password';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 429) {
          // Rate limited - show message and set short cooldown
          setState(() {
            _message = 'Too many attempts. Please wait a few seconds and try again.';
            _isLoading = false;
            _loginCooldownUntil = DateTime.now().add(const Duration(seconds: 10));
          });
          // Clear cooldown after period
          Future.delayed(const Duration(seconds: 10), () {
            if (!mounted) return;
            setState(() {
              _loginCooldownUntil = null;
              _message = '';
            });
          });
        } else {
          setState(() {
            _message = 'Login failed: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  // MARK: - Build Method
  @override
  Widget build(BuildContext context) {
    // إعداد النظام ليكون الوضع الداكن
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      //  إضافة AppBar بسيط لزر الرجوع (السهم)
      appBar: AppBar(
        backgroundColor: kDarkBackground, 
        foregroundColor: kPrimaryTextColor, 
        elevation: 0, 
        automaticallyImplyLeading: true, 
        iconTheme: const IconThemeData(color: Colors.white), // أضف هذا السطر
      ),
      //  خلفية الشاشة سوداء أنيقة
      backgroundColor: kDarkBackground,
      //  إزالة الـ AppBar القياسي
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          //  تعديل المسافة العلوية لأننا الآن نستخدم AppBar
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0), 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                //  تم إزالة زر الرجوع اليدوي TextButton من هنا

                //  ويدجت الشيمر المطلوب
                const WelcomingPageShimmer(),
                
                const SizedBox(height: 50),
                
                //  البطاقة التي تضم حقول الإدخال والزر
                Card(
                  elevation: 5,
                  color: kCardBackground, // خلفية داكنة للبطاقة
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey.shade800, width: 0.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         //  العنوان التوجيهي داخل البطاقة
                        const Text(
                          "YSHOP Employee Login", 
                          textAlign: TextAlign.center, // تعديل النص ليكون على اليسار ليتناسب مع تصميم البطاقة
                          style: TextStyle(
                            fontSize: 24, // زيادة الحجم ليكون بارزًا
                            fontWeight: FontWeight.normal,
                            color: kPrimaryTextColor, 
                          ),
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 20),

                        SimpleTextField(
                          placeholder: "Email",
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          cursorColor: kAccentBlue, 
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 15),
                        SimpleTextField(
                          placeholder: "Password",
                          controller: _passwordController,
                          isSecure: true,
                          cursorColor: kAccentBlue, 
                          onSubmitted: (_) => _adminLogin(), 
                        ),
                        const SizedBox(height: 30),
                        
                        // زر الدخول (Login Button)
                        ElevatedButton(
                          onPressed: (_isLoading || (_loginCooldownUntil != null && DateTime.now().isBefore(_loginCooldownUntil!))) ? null : _adminLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccentBlue, // لون أزرق بارز
                            foregroundColor: kPrimaryTextColor, // نص أبيض
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _isLoading
                                ? "Logging in..."
                                : (_loginCooldownUntil != null && DateTime.now().isBefore(_loginCooldownUntil!)
                                    ? 'Please wait...'
                                    : 'Login'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                          ),
                        ),
                      ],
                    ),
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