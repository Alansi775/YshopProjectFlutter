import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// مدير الحالة للربط مع Firebase
class AuthManager with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // يوفر معلومات عن المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // يقوم بتسجيل الخروج وإخطار المستمعين
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners(); 
  }

  // يمكنك إضافة منطق تسجيل الدخول هنا لاحقًا
}