import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

import 'firebase_options.dart'; 
import 'screens/sign_in_view.dart'; 
import 'screens/category_home_view.dart'; // ستبقى مستوردة

//  التأكد من وجود هذه الملفات في مسار 'lib/state_management/'
import 'state_management/cart_manager.dart'; 
import 'state_management/auth_manager.dart'; 
import 'state_management/theme_manager.dart'; 

// =======================================================
// MARK: - تعريفات الثيم (Themes Definitions)
// ... (لا تغيير في تعريفات الثيم)
// =======================================================

final _lightThemeData = ThemeData(
  // ... (تعريفات الثيم)
  scaffoldBackgroundColor: Colors.white, 
  primaryColor: Colors.black,
  colorScheme: ColorScheme.light(
    primary: Colors.black, 
    secondary: Colors.blueAccent, 
    background: Colors.white, 
  ),
  primarySwatch: Colors.blue, 
  splashColor: Colors.black.withOpacity(0.1), 
  highlightColor: Colors.black.withOpacity(0.05), 
  fontFamily: 'TenorSans',
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white, 
    elevation: 0, 
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.black), 
    titleTextStyle: TextStyle(
      color: Colors.black, 
      fontSize: 20, 
      fontWeight: FontWeight.bold,
      fontFamily: 'TenorSans',
    ),
  ),
);

final _darkThemeData = ThemeData(
  // ... (تعريفات الثيم)
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.grey[900], 
  primaryColor: Colors.white, 
  colorScheme: ColorScheme.dark(
    primary: Colors.white, 
    secondary: Colors.blueAccent,
    background: Colors.grey[900]!,
  ),
  primarySwatch: Colors.blue, 
  splashColor: Colors.white.withOpacity(0.1), 
  highlightColor: Colors.white.withOpacity(0.05), 
  fontFamily: 'TenorSans',
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey[900], 
    elevation: 0, 
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white), 
    titleTextStyle: TextStyle(
      color: Colors.white, 
      fontSize: 20, 
      fontWeight: FontWeight.bold,
      fontFamily: 'TenorSans',
    ),
  ),
);


// =======================================================
// MARK: - الدالة الرئيسية (main)
// ... (لا تغيير في دالة main)
// =======================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthManager()),
        ChangeNotifierProvider(create: (_) => CartManager()),
        ChangeNotifierProvider(create: (_) => ThemeManager()), 
      ],
      child: const MyApp(),
    ),
  );
}


// =======================================================
// MARK: - Widget التطبيق (MyApp)
// =======================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context); 
    
    return MaterialApp(
      title: 'YSHOP',
      
      theme: _lightThemeData, 
      darkTheme: _darkThemeData,
      themeMode: themeManager.themeMode,
      
      debugShowCheckedModeBanner: false, 
      
      //  التعديل الحاسم هنا!
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // سواء كان المستخدم مسجلاً دخوله (hasData) أو غير مسجل،
          // نبدأ دائماً من شاشة تسجيل الدخول (SignInView).
          // وظيفة SignInView.initState -> _checkAuthState هي تحديد الوجهة الصحيحة.
          return const SignInView();
        },
      ),
    );
  }
}