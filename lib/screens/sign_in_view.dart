import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:provider/provider.dart'; // 💡 تم إضافة Provider
import '../state_management/theme_manager.dart'; // 💡 تم إضافة ThemeManager

// المكونات المخصصة
import '../widgets/custom_form_widgets.dart'; 
// استيراد الشاشات الحقيقية
import 'category_home_view.dart';
import 'store_admin_view.dart';
import 'admin_login_view.dart' as Admin;
import 'admin_home_view.dart'; 
import '../widgets/welcoming_page_shimmer.dart'; 

// ⚠️ ملاحظة هامة: يجب أن تكون الألوان (primaryText, accentBlue, secondaryText)
// معرّفة كـ const في ملف custom_form_widgets.dart لتجنب الأخطاء.

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  // MARK: - State Variables
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeTypeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _nationalIDController = TextEditingController();
  final TextEditingController _storePhoneNumberController = TextEditingController();
  
  bool _isStoreOwner = false;
  bool _isLoading = false;
  bool _isNewStoreOwner = false;
  bool _showSignUp = false;
  String _message = "";
  bool _userIsLoggedIn = false; 

  // MARK: - Lifecycle
  @override
  void initState() {
    super.initState();
    _checkAuthState(); 
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _storeNameController.dispose();
    _storeTypeController.dispose();
    _addressController.dispose();
    _customerAddressController.dispose();
    _contactNumberController.dispose();
    _nationalIDController.dispose();
    _storePhoneNumberController.dispose();
    super.dispose();
  }

  // MARK: - Helper Functions
  void _resetFormFields() {
    if (mounted) {
      setState(() {
        _emailController.clear();
        _passwordController.clear();
        _nameController.clear();
        _surnameController.clear();
        _storeNameController.clear();
        _storeTypeController.clear();
        _addressController.clear();
        _customerAddressController.clear();
        _contactNumberController.clear();
        _nationalIDController.clear();
        _storePhoneNumberController.clear();
        _message = "";
      });
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ----------------------------------------------------------------------
  // MARK: - NEW: Role Check and Navigation (الدالة الرئيسية للتوجيه)
  // ----------------------------------------------------------------------
  void _navigateToHomeScreen(User? user) async {
    if (!mounted || user == null) {
      return;
    }
    
    // 1. فحص المشرف
    try {
      final adminDoc = await FirebaseFirestore.instance.collection("admins").doc(user.uid).get();
      if (adminDoc.exists && adminDoc.data()?["role"] == "YShopAdmin") {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminHomeView()),
          );
        }
        return;
      }
    } catch (e) {
      // تجاهل
    }

    // 2. فحص صاحب المتجر
    try {
      final storeDoc = await FirebaseFirestore.instance.collection("storeRequests").doc(user.uid).get();
      
      if (storeDoc.exists) {
        final data = storeDoc.data()!;
        final status = data["status"] as String?;
        final storeName = data["storeName"] as String?;

        if (status == "Approved" && storeName != null) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => StoreAdminView(initialStoreName: storeName)),
            );
          }
          return;
        }
      }
    } catch (e) {
      // تجاهل
    }

    // 3. توجيه العميل (في حال الفشل أو عدم العثور على دور)
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CategoryHomeView()),
      );
    }
  }
  
  // 💡 تحديث: التحقق من حالة تسجيل الدخول الحالية (عند بدء التشغيل)
  void _checkAuthState() async { // 💡 جعلها async
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload(); // 💡 تحديث حالة المستخدم قبل الفحص
      
      // 💡 التحقق من التفعيل قبل التوجيه التلقائي
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        // سيبقى في شاشة تسجيل الدخول
        return; 
      }
      
      _navigateToHomeScreen(user);
    }
  }
  // ----------------------------------------------------------------------


  // MARK: - Firebase Actions (Customer/General User)
  void _login() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      final user = userCredential.user;
      
      // 1. التحقق من التفعيل 
      if (user != null && !user.emailVerified) {
        if (mounted) {
          setState(() {
            _message = "Please verify your email address to complete your login.";
          });
        }
        await FirebaseAuth.instance.signOut(); 
        return; 
      }
      
      // 2. إذا كان مفعلًا، توجيه المستخدم
      _navigateToHomeScreen(userCredential.user);
      
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _message = e.message ?? "An unknown error occurred.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
}

  void _signUpCustomer() async {
    if (_isLoading) return; 
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,

      );

      final user = userCredential.user;
      if (user != null) {
        // ... (كود إضافة العميل لـ Firestore)

        await user.sendEmailVerification();

        if (mounted) { 
          setState(() {
            _message = "Account created successfully! Please check your email to verify your account.";
          });
        }

        // 💡 إزالة التأخير المكرر
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSignUp = false;
              _emailController.clear();
              _passwordController.clear();
              _isLoading = false; // 💡 إيقاف التحميل بعد التأخير
            });
          }
        });
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Failed to create account: ${e.message}";
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Failed to create user document: ${e.message}";
        });
      }
    } finally { // 💡 ضمان إيقاف التحميل في حالة الفشل
      if (mounted && _isLoading) { 
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // MARK: - Firebase Actions (Store Owner)

  void _storeOwnerLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _message = "";
    });
    
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) return;

      if (!user.emailVerified) {
        if (mounted) { 
          setState(() {
            _message = "Please verify your email before logging in.";
          });
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

      final docRef = FirebaseFirestore.instance.collection("storeRequests").doc(user.uid);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        if (mounted) { 
          setState(() {
            _message = "Store request not found.";
          });
        }
        await FirebaseAuth.instance.signOut();
        _emailController.clear();
        _passwordController.clear();
        return;
      }

      final data = snapshot.data()!;
      final status = data["status"] as String?;
      final storeName = data["storeName"] as String?;

      await docRef.update({"emailVerified": true});

      if (status == "Approved" && storeName != null) {
        _navigateToHomeScreen(user); 
      } else {
        if (mounted) { 
          setState(() {
            _message = "Your account is pending admin approval.";
          });
        }
        await FirebaseAuth.instance.signOut(); 
        _emailController.clear();
        _passwordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Error signing in: ${e.message}";
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Error checking request: ${e.message}";
        });
      }
    } finally { // 💡 ضمان إيقاف التحميل
      if (mounted) { 
        setState(() {
          _isLoading = false;
        });
      }
    }
}

  void _requestStoreOwnerAccount() async {
    final hashedPassword = _hashPassword(_passwordController.text); // لا يتم استخدامه حاليا مع Firebase Auth

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) return;

      // ... (كود إرسال الطلب لـ Firestore)
      
      await user.sendEmailVerification();

      if (mounted) { 
        setState(() {
          _message = "Verification email sent. Please verify your email to complete your request.";
        });
      }

      // 💡 إزالة التأخير المكرر
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isNewStoreOwner = false;
            _emailController.clear();
            _passwordController.clear();
            _isLoading = false; // 💡 إيقاف التحميل بعد التأخير
          });
        }
      });

    } on FirebaseAuthException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Failed to create account: ${e.message}";
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Failed to send request: ${e.message}";
        });
      }
    } finally { // 💡 ضمان إيقاف التحميل في حالة الفشل
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // MARK: - Action Buttons 

  Widget _toggleOwnershipButton() {
    // 💡 استخدام الألوان من الثيم
    return TextButton(
      onPressed: () {
        setState(() {
          _isStoreOwner = !_isStoreOwner;
          _resetFormFields();
        });
      },
      child: Text(
        _isStoreOwner ? "Are you a Customer?" : "Are you a Store Owner?",
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.secondary, // استخدام اللون الثانوي للثيم
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _toggleSignUpLoginButton() {
    // 💡 استخدام الألوان من الثيم
    return TextButton(
      onPressed: () {
        setState(() {
          _showSignUp = !_showSignUp;
          _resetFormFields();
        });
      },
      child: Text(
        _showSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up",
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), // لون خفيف يعتمد على الثيم
        ),
      ),
    );
  }

  Widget _toggleNewStoreOwnerButton() {
    // 💡 استخدام الألوان من الثيم
    return TextButton(
      onPressed: () {
        setState(() {
          _isNewStoreOwner = true;
          _resetFormFields();
        });
      },
      child: Text(
        "New Store Owner? Request to Join",
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _adminLoginButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const Admin.AdminLoginView(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        // 💡 استخدام ألوان ثابتة للمشرف (لأنه دور خاص)
        backgroundColor: Colors.black, 
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        elevation: 0,
      ),
      child: const Text(
        "YShop Admin Login",
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _backButton({required VoidCallback action}) {
    // 💡 استخدام الألوان من الثيم
    return TextButton(
      onPressed: () {
        action();
        _resetFormFields();
      },
      child: Text(
        "Back",
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  // MARK: - Forms (النماذج لم تتغير)
  Widget get _loginCustomerForm {
    return Column(
      children: [
        UnderlinedTextField(
          placeholder: "Email",
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Password",
          controller: _passwordController,
          onSubmitted: (_) => _login(),
        ),
        PrimaryActionButton(title: "Login", action: _login, isLoading: _isLoading),
      ],
    );
  }
  
  Widget get _signUpCustomerForm {
    return Column(
      children: [
        UnderlinedTextField(placeholder: "Name", controller: _nameController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Surname", controller: _surnameController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Address", controller: _customerAddressController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Phone Number", controller: _contactNumberController, keyboardType: TextInputType.phone),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "National ID", controller: _nationalIDController, keyboardType: TextInputType.number),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Email", controller: _emailController, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Password",
          controller: _passwordController,
          onSubmitted: (value) => _signUpCustomer(),
        ),
        PrimaryActionButton(title: "Sign Up", action: _signUpCustomer, isLoading: _isLoading),
      ],
    );
  }

  Widget get _requestStoreOwnerForm {
    return Column(
      children: [
        UnderlinedTextField(placeholder: "Store Name", controller: _storeNameController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Store Type (e.g., Clothes, Food)", controller: _storeTypeController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Address", controller: _addressController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Phone Number (with country code)", controller: _storePhoneNumberController, keyboardType: TextInputType.phone),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Email", controller: _emailController, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Password",
          controller: _passwordController,
          onSubmitted: (value) => _requestStoreOwnerAccount(),
          ),
        PrimaryActionButton(title: "Request to Join", action: _requestStoreOwnerAccount, isLoading: _isLoading),
      ],
    );
  }

  Widget get _loginStoreOwnerForm {
    return Column(
      children: [
        UnderlinedTextField(placeholder: "Email", controller: _emailController, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Password",
          controller: _passwordController,
          onSubmitted: (value) => _storeOwnerLogin(),
          ),
        PrimaryActionButton(title: "Log in to Your Store", action: _storeOwnerLogin, isLoading: _isLoading),
      ],
    );
  }
  

  // MARK: - Sections 
  Widget get _customerSection {
    return Column(
      children: <Widget>[
        if (_showSignUp) _signUpCustomerForm else _loginCustomerForm,
        _toggleOwnershipButton(),
        _toggleSignUpLoginButton(),
      ],
    );
  }

  Widget get _storeOwnerSection {
    // 💡 الحصول على لون النص الرئيسي من الثيم
    final Color primaryColor = Theme.of(context).colorScheme.primary; 

    return Column(
      children: <Widget>[
         Text(
          "Store Owner Sign In",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            // 💡 استخدام اللون من الثيم
            color: primaryColor, 
          ),
        ),
        const SizedBox(height: 20),

        if (_isNewStoreOwner)
          Column(
            children: [
              _requestStoreOwnerForm,
              _backButton(action: () => setState(() => _isNewStoreOwner = false)),
            ],
          )
        else
          Column(
            children: [
              _loginStoreOwnerForm,
              _toggleNewStoreOwnerButton(),
              const SizedBox(height: 15),
              _adminLoginButton(context),
              _backButton(action: () => setState(() => _isStoreOwner = false)),
            ],
          ),
      ],
    );
  }


  // MARK: - Main Build Method (التصميم الجديد)
  @override
  Widget build(BuildContext context) {
    // 💡 الحصول على ThemeManager وإعداد الألوان الديناميكية
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.isDarkMode;
    
    // 💡 استخدام الألوان من الثيم بدلاً من الثابتة
    final cardColor = Theme.of(context).cardColor;
    
    return Scaffold(
      // 💡 إضافة AppBar مع زر تبديل المظهر
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            // 💡 عرض أيقونة الشمس إذا كان الوضع الداكن، وأيقونة القمر إذا كان الوضع الفاتح
            icon: Icon(isDark ? Icons.wb_sunny : Icons.nights_stay),
            onPressed: () {
              themeManager.switchTheme(); 
            },
          ),
        ],
      ),
      body: Container(
        // 💡 إزالة التدرج واستخدام لون الخلفية من الثيم
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const WelcomingPageShimmer(),
                    const SizedBox(height: 30),
                    
                    Card(
                      elevation: 10, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // 💡 استخدام لون البطاقة من الثيم
                      color: cardColor, 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 35.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_isStoreOwner) _storeOwnerSection else _customerSection,
                            Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Text(
                                _message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  // 💡 اللون الأحمر ثابت لرسالة الخطأ
                                  color: Colors.red, 
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}