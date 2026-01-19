import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../state_management/theme_manager.dart';
import '../../widgets/custom_form_widgets.dart';

//  ألوان Dark Mode موحدة (مثل admin_login_view.dart)
const Color kDarkBackground = Color(0xFF1C1C1E);
const Color kCardBackgroundDark = Color(0xFF2C2C2E);
const Color kPrimaryTextColorDark = Colors.white;
const Color kSecondaryTextColorDark = Colors.white70;
const Color kAccentBlue = Color(0xFF007AFF);

class DeliverySignupView extends StatefulWidget {
  const DeliverySignupView({super.key});

  @override
  State<DeliverySignupView> createState() => _DeliverySignupViewState();
}

class _DeliverySignupViewState extends State<DeliverySignupView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nationalIDController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  bool _isLoading = false;
  String _message = "";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
      _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIDController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _requestDriverAccount() async {
    if (_isLoading) return;
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || 
        _nameController.text.isEmpty || _phoneController.text.isEmpty) {
      setState(() => _message = "Please fill in all required fields.");
      return;
    }

    // تحقق من تطابق كلمة المرور
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _message = "Passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Failed to create user.");

      await user.sendEmailVerification();

      // Send delivery request to backend for admin approval (instead of Firestore)
      await ApiService.submitDeliveryRequest(
        uid: user.uid,
        email: user.email,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        nationalID: _nationalIDController.text.trim(),
        address: _addressController.text.trim(),
      );

      await FirebaseAuth.instance.signOut();
      
      if (mounted) { 
        setState(() {
          _message = "Your request has been sent! Please check your email to verify and wait for admin approval.";
          _isLoading = false;
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context); 
          }
        });
      }
      
    } on FirebaseAuthException catch (e) {
      if (mounted) { 
        setState(() => _message = "Auth Error: ${e.message}");
      }
    } on FirebaseException catch (e) {
      if (mounted) { 
        setState(() => _message = "DB Error: ${e.message}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = "An unexpected error occurred: ${e.toString()}");
      }
    } finally {
      if (mounted && _isLoading) { 
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.isDarkMode;
    
    //  ألوان موحدة للـ Dark Mode
    final backgroundColor = isDark ? kDarkBackground : Colors.white;
    final cardColor = isDark ? kCardBackgroundDark : Colors.white;
    final cardBorderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final titleColor = isDark ? kPrimaryTextColorDark : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          "Driver Registration",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  "Join Our Delivery Team",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 30),
                
                //  Card مع ألوان موحدة
                Card(
                  elevation: isDark ? 5 : 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: cardBorderColor, width: 0.5),
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UnderlinedTextField(
                          placeholder: "Full Name",
                          controller: _nameController,
                        ),
                        const SizedBox(height: 15),
                        UnderlinedTextField(
                          placeholder: "Phone Number (+Country Code)",
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 15),
                        UnderlinedTextField(
                          placeholder: "National ID (for verification)",
                          controller: _nationalIDController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 15),
                        UnderlinedTextField(
                          placeholder: "Address",
                          controller: _addressController,
                        ),
                        const SizedBox(height: 15),
                        UnderlinedTextField(
                          placeholder: "Email",
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 15),
                        UnderlinedSecureField(
                          placeholder: "Password",
                          controller: _passwordController,
                          onSubmitted: (_) => _requestDriverAccount(),
                        ),
                        const SizedBox(height: 15),
                        UnderlinedSecureField(
                          placeholder: "Confirm Password",
                          controller: _confirmPasswordController,
                          onSubmitted: (_) => _requestDriverAccount(),
                        ),
                        const SizedBox(height: 30),
                        
                        PrimaryActionButton(
                          title: "Submit Registration Request",
                          action: _requestDriverAccount,
                          isLoading: _isLoading,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _message.contains('Error') ? Colors.red : Colors.green,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}