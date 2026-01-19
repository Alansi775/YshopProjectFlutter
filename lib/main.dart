import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

import 'firebase_options.dart'; 
import 'screens/auth/sign_in_view.dart'; 
import 'screens/admin/admin_home_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/order_tracker_widget.dart';
import 'services/navigation_service.dart';

import 'state_management/cart_manager.dart'; 
import 'state_management/auth_manager.dart'; 
import 'state_management/theme_manager.dart'; 

// =======================================================
// MARK: - تعريفات الثيم (Themes Definitions)
// =======================================================

final _lightThemeData = ThemeData(
  brightness: Brightness.light,
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
    titleTextStyle: const TextStyle(
      color: Colors.white, 
      fontSize: 20, 
      fontWeight: FontWeight.bold,
      fontFamily: 'TenorSans',
    ),
  ),
);


// =======================================================
// MARK: - الدالة الرئيسية (main)
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
    //  استخدام Consumer للاستماع للتغييرات تلقائياً
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        debugPrint('🎨 Theme updated: ${themeManager.themeMode}');
        
        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          title: 'YSHOP',
          theme: _lightThemeData, 
          darkTheme: _darkThemeData,
          themeMode: themeManager.themeMode, //  يتحدث تلقائياً

          debugShowCheckedModeBanner: false, 

          // Wrap navigator content with a builder so we can overlay the global OrderTrackerWidget
          builder: (context, child) {
            return Stack(
              children: [
                // The app's normal content (Navigator)
                if (child != null) child,
                // Global persistent order tracker overlay
                const OrderTrackerWidget(),
              ],
            );
          },

          home: FutureBuilder<SharedPreferences?>(
            future: SharedPreferences.getInstance().then((p) => p),
            builder: (context, prefSnap) {
              if (prefSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final prefs = prefSnap.data;
              try {
                final token = prefs?.getString('admin_token');
                final expiryMs = prefs?.getInt('admin_token_expiry');
                if (token != null && expiryMs != null) {
                  final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
                  if (DateTime.now().isBefore(expiry)) {
                    return const AdminHomeView();
                  }
                }
              } catch (_) {}

              return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const SignInView();
                },
              );
            },
          ),
        );
      },
    );
  }
}