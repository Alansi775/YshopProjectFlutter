import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:io' show Platform;
import 'dart:html' as html show document, SelectElement, OptionElement, window;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../state_management/cart_manager.dart'; 
import '../../state_management/theme_manager.dart';
import '../../services/api_service.dart';
import '../../constants/store_categories.dart';

import '../../widgets/custom_form_widgets.dart';
import '../../widgets/map_picker_sheet.dart';
import 'package:latlong2/latlong.dart';
import '../customers/category_home_view.dart';
import '../stores/store_admin_view.dart';
import 'admin_login_view.dart' as Admin;
import '../admin/admin_home_view.dart';
import '../admin/common.dart'; 
import '../../widgets/welcoming_page_shimmer.dart'; 
import '../delivery/delivery_signup_view.dart';
import '../delivery/delivery_home_view.dart';

//  ألوان Dark Mode موحدة (مثل admin_login_view.dart)
const Color kDarkBackground = Color(0xFF1C1C1E);
const Color kCardBackgroundDark = Color(0xFF2C2C2E);
const Color kPrimaryTextColorDark = Colors.white;
const Color kSecondaryTextColorDark = Colors.white70;
const Color kAccentBlue = Color(0xFF007AFF);

class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  // MARK: - State Variables
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeTypeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  double _latitude = 0.0;
  double _longitude = 0.0;
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _nationalIDController = TextEditingController();
  final TextEditingController _storePhoneNumberController = TextEditingController();
  
  bool _isStoreOwner = false;
  bool _isLoading = false;
  bool _isNewStoreOwner = false;
  bool _showSignUp = false;
  String _message = "";

  @override
  void initState() {
    super.initState();
    _checkAuthState(); 
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _showMapPickerForSignup() async {
    final defaultLat = 0.0;
    final defaultLng = 0.0;

    final initialCoordinate = LatLng(
      _latitude != 0.0 ? _latitude : defaultLat,
      _longitude != 0.0 ? _longitude : defaultLng,
    );

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapPickerSheet(initialCoordinate: initialCoordinate),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _customerAddressController.text = result['address'] as String? ?? '';
        _latitude = result['latitude'] as double? ?? 0.0;
        _longitude = result['longitude'] as double? ?? 0.0;
      });
    }
  }

  // Map picker for store owner (saves to _addressController)
  Future<void> _showMapPickerForStoreOwner() async {
    final defaultLat = 0.0;
    final defaultLng = 0.0;

    final initialCoordinate = LatLng(
      _latitude != 0.0 ? _latitude : defaultLat,
      _longitude != 0.0 ? _longitude : defaultLng,
    );

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapPickerSheet(initialCoordinate: initialCoordinate),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _addressController.text = result['address'] as String? ?? '';
        _latitude = result['latitude'] as double? ?? 0.0;
        _longitude = result['longitude'] as double? ?? 0.0;
      });
    }
  }

  void _resetFormFields() {
    if (mounted) {
      setState(() {
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
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

  //  Show NATIVE store category picker (iOS/macOS/Android) - Web compatible
  Future<void> _showStoreCategoryPicker() async {
    if (kIsWeb) {
      // Web: use native HTML select picker on all browsers
      await _showHtmlNativeStorePicker();
      return;
    }
    
    try {
      // Check platform safely
      final isCupertino = defaultTargetPlatform == TargetPlatform.iOS || 
                          defaultTargetPlatform == TargetPlatform.macOS;
      
      if (isCupertino) {
        // 🍎 Native iOS/macOS Picker (Cupertino style)
        _showCupertinoStorePicker();
      } else {
        // 🤖 Native Android Material Picker
        _showMaterialStorePicker();
      }
    } catch (e) {
      // Fallback to material picker
      _showMaterialStorePicker();
    }
  }

  // 🌐 Web: Native HTML select picker (shows native macOS/iOS picker in browser)
  Future<void> _showHtmlNativeStorePicker() async {
    try {
      final select = html.SelectElement();
      
      // Style: elegant centered select - VISIBLE
      select.style.position = 'fixed';
      select.style.top = '50%';
      select.style.left = '50%';
      select.style.transform = 'translate(-50%, -50%)';
      select.style.width = '280px';
      select.style.height = '45px';
      select.style.padding = '10px 12px';
      select.style.fontSize = '15px';
      select.style.borderRadius = '10px';
      select.style.border = '1px solid #444';
      select.style.backgroundColor = '#2c2c2e';
      select.style.color = '#fff';
      select.style.boxShadow = '0 8px 32px rgba(0,0,0,0.4)';
      select.style.zIndex = '99999';
      select.style.cursor = 'pointer';
      select.style.outline = 'none';
      
      // Add empty option first (placeholder)
      final emptyOption = html.OptionElement()
        ..value = ''
        ..text = 'Select Store Type'
        ..disabled = true;
      select.append(emptyOption);
      
      // Add category options
      for (final category in StoreCategories.all) {
        final option = html.OptionElement()
          ..value = category
          ..text = category;
        select.append(option);
      }
      
      // Select the empty option by default (no selection)
      select.selectedIndex = 0;
      
      // Append to body
      html.document.body!.append(select);
      
      // Flag to track if already handled
      bool handled = false;
      
      // Handle change
      select.onChange.listen((event) {
        if (!handled) {
          handled = true;
          final selected = select.value;
          select.remove();
          if (selected != null && selected.isNotEmpty && mounted) {
            setState(() {
              _storeTypeController.text = selected;
            });
          }
        }
      });
      
      // Handle cancel/blur
      select.onBlur.listen((event) {
        if (!handled) {
          handled = true;
          if (select.parent != null) {
            select.remove();
          }
        }
      });
      
      // Immediately trigger the picker
      select.click();
      
    } catch (e) {
      debugPrint('Error in native picker: $e');
      _showMaterialStorePicker();
    }
  }

  // 🍎 iOS/macOS Native Cupertino Picker (الشكل الانيق مثل اختيار اللغات)
  void _showCupertinoStorePicker() {
    int selectedIndex = StoreCategories.all.indexOf(_storeTypeController.text);
    if (selectedIndex < 0) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoPicker(
            magnification: 1.22,
            itemExtent: 32.0,
            scrollController: FixedExtentScrollController(
              initialItem: selectedIndex,
            ),
            onSelectedItemChanged: (int index) {
              setState(() {
                _storeTypeController.text = StoreCategories.all[index];
              });
            },
            children: List<Widget>.generate(
              StoreCategories.all.length,
              (int index) => Center(
                child: Text(
                  StoreCategories.all[index],
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🤖 Android/Web Material Picker - Enhanced with smooth animations
  Future<void> _showMaterialStorePicker() async {
    int selectedIndex = StoreCategories.all.indexOf(_storeTypeController.text);
    if (selectedIndex < 0) selectedIndex = 0;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Select Store Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Divider(height: 1, thickness: 0.5),
              // Categories List with smooth scroll
              ListView.builder(
                shrinkWrap: true,
                itemCount: StoreCategories.all.length,
                itemBuilder: (context, index) {
                  final category = StoreCategories.all[index];
                  final isSelected = _storeTypeController.text == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _storeTypeController.text = category);
                      Navigator.pop(context);
                    },
                    child: Container(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _navigateToHomeScreen(User? user) async {
    if (!mounted || user == null) return;
    
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
    } catch (e) {}

    try {
      final storeDoc = await FirebaseFirestore.instance.collection("storeRequests").doc(user.uid).get();
      if (storeDoc.exists) {
        final data = storeDoc.data()!;
        final status = data["status"] as String?;
        final storeName = data["storeName"] as String?;
        if (status == "Approved" && storeName != null) {
          //  Set admin role for store owner to hide order tracker
          ApiService.setAdminRole('StoreAdmin');
          ApiService.setAdminProfile({'role': 'StoreAdmin', 'storeName': storeName});
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => StoreAdminView(initialStoreName: storeName)),
            );
          }
          return;
        }
      }
    } catch (e) {}

    try {
      final drv = await ApiService.getDeliveryRequestByUid(user.uid);
      if (drv != null) {
        final status = (drv['status'] ?? drv['Status'])?.toString();
        final driverName = (drv['name'] ?? drv['Name'] ?? user.displayName ?? 'Driver').toString();

        // Allow drivers with either Approved or Pending status to enter
        // the DeliveryHomeView. DeliveryHomeView will show a Pending
        // approval UI when appropriate, so we don't force sign-out here.
        if (status == 'Approved' || status == 'Pending') {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => DeliveryHomeView(driverName: driverName)),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Driver lookup failed: $e');
    }

    if (mounted) {
      final userEmail = user.email;
      if (userEmail != null) {
        //  Clear admin role for regular users
        ApiService.setAdminRole(null);
        ApiService.setAdminProfile(null);
        
        try {
          final orders = await ApiService.getUserOrders(page: 1, limit: 5);
          // find first non-delivered order
          String? lastOrderId;
          for (final o in orders) {
            final status = (o['status'] as String?) ?? '';
            if (status.toLowerCase() != 'delivered') {
              lastOrderId = (o['id'] ?? o['order_id'] ?? o['documentId'])?.toString();
              break;
            }
          }
          Provider.of<CartManager>(context, listen: false).setLastOrderId(lastOrderId);
        } catch (e) {
          debugPrint('Failed to fetch user orders on sign-in: $e');
          Provider.of<CartManager>(context, listen: false).setLastOrderId(null);
        }
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CategoryHomeView()),
      );
    }
  }
  
  void _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        return; 
      }
      _navigateToHomeScreen(user);
    }
  }

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
      if (user != null && !user.emailVerified) {
        if (mounted) {
          setState(() {
            _message = "Please verify your email address to complete your login.";
          });
        }
        await FirebaseAuth.instance.signOut(); 
        return; 
      }
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

    // تحقق من تطابق كلمة المرور
    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        setState(() {
          _message = "Passwords do not match.";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();

        // Sync user profile to backend and store basic customer info
        try {
          await ApiService.syncUser(
            uid: user.uid,
            email: user.email ?? '',
            displayName: '${_nameController.text} ${_surnameController.text}'.trim(),
          );

          await ApiService.updateUserProfile(
            displayName: '${_nameController.text} ${_surnameController.text}'.trim(),
            surname: _surnameController.text.isNotEmpty ? _surnameController.text : null,
            phone: _contactNumberController.text.isNotEmpty ? _contactNumberController.text : null,
            address: _customerAddressController.text.isNotEmpty ? _customerAddressController.text : null,
            nationalId: _nationalIDController.text.isNotEmpty ? _nationalIDController.text : null,
            latitude: _latitude != 0.0 ? _latitude : null,
            longitude: _longitude != 0.0 ? _longitude : null,
          );
        } catch (e) {
          debugPrint('Warning: could not sync user profile to backend: $e');
        }

        if (mounted) {
          setState(() {
            _message = "Account created successfully! Please check your email to verify your account.";
          });
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSignUp = false;
              _emailController.clear();
              _passwordController.clear();
              _isLoading = false;
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
    } finally {
      if (mounted && _isLoading) { 
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

      await user.reload();
      
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
      
      if (status == "Approved" && storeName != null) {
        // If the store request was approved but not yet synced, perform sync now
        if (data["syncedToMySQL"] != true) {
          try {
            await ApiService.syncUser(
              uid: user.uid,
              email: user.email ?? "",
              displayName: user.displayName ?? "",
            );
            await ApiService.createStore(
              name: storeName,
              description: data["storeType"] as String? ?? "",
              phone: data["phone"] as String? ?? "",
              address: data["address"] as String? ?? "",
              latitude: data["latitude"] is num ? (data["latitude"] as num).toDouble() : 0.0,
              longitude: data["longitude"] is num ? (data["longitude"] as num).toDouble() : 0.0,
              ownerUid: user.uid,
              storeType: data["storeType"] as String? ?? "",
              email: data["email"] as String? ?? "",
            );
            await docRef.update({"syncedToMySQL": true, "emailVerified": true});
          } catch (e) {
            debugPrint("Error syncing store to MySQL: $e");
          }
        }
        _navigateToHomeScreen(user);
      } else {
        if (mounted) { 
          setState(() {
            _message = "Your store request is pending admin approval.";
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
    } finally {
      if (mounted) { 
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _requestStoreOwnerAccount() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _message = "";
    });

    try {
      // تحقق من تطابق كلمة المرور
      if (_passwordController.text != _confirmPasswordController.text) {
        if (mounted) {
          setState(() {
            _message = "Passwords do not match.";
            _isLoading = false;
          });
        }
        return;
      }

      if (_storeNameController.text.isEmpty || 
          _emailController.text.isEmpty || 
          _passwordController.text.isEmpty ||
          _addressController.text.isEmpty ||
          _storePhoneNumberController.text.isEmpty) {
        if (mounted) {
          setState(() {
            _message = "Please fill in all fields";
            _isLoading = false;
          });
        }
        return;
      }

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) return;

      // 1️⃣ حفظ في Firestore
      await FirebaseFirestore.instance.collection("storeRequests").doc(user.uid).set({
        "storeName": _storeNameController.text.trim(),
        "storeType": _storeTypeController.text.trim(),
        "address": _addressController.text.trim(),
        "phone": _storePhoneNumberController.text.trim(),
        "email": _emailController.text.trim(),
        "status": "Pending",
        "ownerEmail": _emailController.text.trim(),
        "ownerUid": user.uid,
        "createdAt": FieldValue.serverTimestamp(),
        "syncedToMySQL": false, // ← أضف هذا
      });

      // 2️⃣ Do NOT sync to MySQL immediately. Store owner requests are reviewed by admins.
      // The admin UI will call the backend to create the store and sync the owner when approved.

      // 3️⃣ إرسال إيميل التحقق
      await user.sendEmailVerification();

      if (mounted) { 
        setState(() {
          _message = "Verification email sent. Please verify your email to complete registration.";
        });
      }

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isNewStoreOwner = false;
            _storeNameController.clear();
            _storeTypeController.clear();
            _addressController.clear();
            _storePhoneNumberController.clear();
            _emailController.clear();
            _passwordController.clear();
            _isLoading = false;
          });
        }
      });

    } on FirebaseAuthException catch (e) {
      if (mounted) { 
        setState(() {
          _message = "Failed to create account: ${e.message}";
          _isLoading = false;
        });
      }
    }
  }

  // MARK: - Action Buttons 
  Widget _toggleOwnershipButton(bool isDark) {
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
          color: kAccentBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _toggleSignUpLoginButton(bool isDark) {
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
          color: isDark ? kSecondaryTextColorDark : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _toggleNewStoreOwnerButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isNewStoreOwner = true;
          _resetFormFields();
        });
      },
      child: const Text(
        "New Store Owner? Request to Join",
        style: TextStyle(
          fontSize: 14,
          color: kAccentBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _deliveryDriverSignupButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const DeliverySignupView(),
          ),
        );
      },
      child: const Text(
        "Want to be a Delivery Driver? Sign Up",
        style: TextStyle(
          fontSize: 14,
          color: kAccentBlue,
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

  Widget _backButton(bool isDark, {required VoidCallback action}) {
    return TextButton(
      onPressed: () {
        action();
        _resetFormFields();
      },
      child: Text(
        "Back",
        style: TextStyle(
          fontSize: 14,
          color: isDark ? kSecondaryTextColorDark : Colors.grey.shade600,
        ),
      ),
    );
  }

  // MARK: - Forms
  Widget _loginCustomerForm(bool isDark) {
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
  
  Widget _signUpCustomerForm(bool isDark) {
    return Column(
      children: [
        UnderlinedTextField(placeholder: "Name", controller: _nameController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Surname", controller: _surnameController),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Address", controller: _customerAddressController, readOnly: true),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showMapPickerForSignup,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Select on Map'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
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
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Confirm Password",
          controller: _confirmPasswordController,
          onSubmitted: (value) => _signUpCustomer(),
        ),
        PrimaryActionButton(title: "Sign Up", action: _signUpCustomer, isLoading: _isLoading),
      ],
    );
  }

  Widget _requestStoreOwnerForm(bool isDark) {
    return Column(
      children: [
        UnderlinedTextField(placeholder: "Store Name", controller: _storeNameController),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          onPressed: () => _showStoreCategoryPicker(),
          icon: const Icon(Icons.category_rounded),
          label: Text(
            _storeTypeController.text.isEmpty 
              ? "Select Store Type" 
              : _storeTypeController.text,
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Address", controller: _addressController, readOnly: true),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showMapPickerForStoreOwner,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Select on Map'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Phone Number", controller: _storePhoneNumberController, keyboardType: TextInputType.phone),
        const SizedBox(height: 15),
        UnderlinedTextField(placeholder: "Email", controller: _emailController, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Password",
          controller: _passwordController,
          onSubmitted: (value) => _requestStoreOwnerAccount(),
        ),
        const SizedBox(height: 15),
        UnderlinedSecureField(
          placeholder: "Confirm Password",
          controller: _confirmPasswordController,
          onSubmitted: (value) => _requestStoreOwnerAccount(),
        ),
        PrimaryActionButton(title: "Request to Join", action: _requestStoreOwnerAccount, isLoading: _isLoading),
      ],
    );
  }

  Widget _loginStoreOwnerForm(bool isDark) {
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
  Widget _customerSection(bool isDark) {
    return Column(
      children: <Widget>[
        if (_showSignUp) _signUpCustomerForm(isDark) else _loginCustomerForm(isDark),
        _toggleOwnershipButton(isDark),
        _toggleSignUpLoginButton(isDark),
      ],
    );
  }

  Widget _storeOwnerSection(bool isDark) {
    final Color titleColor = isDark ? kPrimaryTextColorDark : Colors.black;

    return Column(
      children: <Widget>[
        Text(
          "Store Owner Sign In",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 20),

        if (_isNewStoreOwner)
          Column(
            children: [
              _requestStoreOwnerForm(isDark),
              _backButton(isDark, action: () => setState(() => _isNewStoreOwner = false)),
            ],
          )
        else
          Column(
            children: [
              _loginStoreOwnerForm(isDark),
              _toggleNewStoreOwnerButton(),
              _deliveryDriverSignupButton(context),
              const SizedBox(height: 15),
              _adminLoginButton(context),
              _backButton(isDark, action: () => setState(() => _isStoreOwner = false)),
            ],
          ),
      ],
    );
  }

  // MARK: - Main Build Method
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.isDarkMode;
    
    //  ألوان موحدة للـ Dark Mode مثل admin_login_view.dart
    final backgroundColor = isDark ? kDarkBackground : Colors.white;
    final cardColor = isDark ? kCardBackgroundDark : Colors.white;
    final cardBorderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny : Icons.nights_stay,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              themeManager.switchTheme();
            },
          ),
        ],
      ),
      body: Container(
        color: backgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
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
                      elevation: isDark ? 5 : 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: cardBorderColor, width: 0.5),
                      ),
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 35.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (_isStoreOwner) _storeOwnerSection(isDark) else _customerSection(isDark),
                            Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Text(
                                _message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _message.contains('success') ? Colors.green : Colors.red,
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