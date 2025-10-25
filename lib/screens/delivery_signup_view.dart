import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import '../widgets/custom_form_widgets.dart'; // افترض أنك تستورد هذه

class DeliverySignupView extends StatefulWidget {
  const DeliverySignupView({super.key});

  @override
  State<DeliverySignupView> createState() => _DeliverySignupViewState();
}

class _DeliverySignupViewState extends State<DeliverySignupView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIDController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // MARK: - Firebase Action: Request Delivery Driver Account
  // ----------------------------------------------------------------------
  void _requestDriverAccount() async {
    if (_isLoading) return;
    
    // 1. التحقق من صحة المدخلات الأساسية
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || 
        _nameController.text.isEmpty || _phoneController.text.isEmpty) {
        setState(() => _message = "Please fill in all required fields.");
        return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      // 2. إنشاء مستخدم جديد في Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("Failed to create user.");

      // 3. إرسال بريد التحقق (Email Verification)
      await user.sendEmailVerification();

      // 4. حفظ بيانات طلب الموصل في Firestore
      await FirebaseFirestore.instance.collection('deliveryRequests').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'nationalID': _nationalIDController.text.trim(),
        'address': _addressController.text.trim(),
        'status': 'Pending', // 💡 الحالة الأولية: معلقة بانتظار موافقة الإدارة
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. تسجيل الخروج وإرسال رسالة نجاح
      await FirebaseAuth.instance.signOut();
      
      if (mounted) { 
        setState(() {
          _message = "Your request has been sent! Please check your email to verify and wait for admin approval.";
          _isLoading = false;
        });
        // إغلاق الشاشة بعد فترة
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
        setState(() => _message = "DB Error: Failed to save request. ${e.message}");
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

  // ----------------------------------------------------------------------
  // MARK: - Build Method
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text("Driver Registration", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: primaryColor),
                ),
                const SizedBox(height: 30),
                
                // 💡 نموذج التسجيل
                UnderlinedTextField(placeholder: "Full Name", controller: _nameController),
                const SizedBox(height: 15),
                UnderlinedTextField(
                    placeholder: "Phone Number (+Country Code)", 
                    controller: _phoneController, 
                    keyboardType: TextInputType.phone
                ),
                const SizedBox(height: 15),
                UnderlinedTextField(
                    placeholder: "National ID (for verification)", 
                    controller: _nationalIDController, 
                    keyboardType: TextInputType.number
                ),
                const SizedBox(height: 15),
                UnderlinedTextField(placeholder: "Address", controller: _addressController),
                const SizedBox(height: 15),
                UnderlinedTextField(
                    placeholder: "Email", 
                    controller: _emailController, 
                    keyboardType: TextInputType.emailAddress
                ),
                const SizedBox(height: 15),
                UnderlinedSecureField(
                    placeholder: "Password", 
                    controller: _passwordController,
                    onSubmitted: (_) => _requestDriverAccount(),
                ),
                
                const SizedBox(height: 30),
                
                // زر الإرسال
                PrimaryActionButton(
                    title: "Submit Registration Request", 
                    action: _requestDriverAccount, 
                    isLoading: _isLoading
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _message.contains('Error') ? Colors.red : Colors.green, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}