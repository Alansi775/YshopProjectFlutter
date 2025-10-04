import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart'; 
import 'package:latlong2/latlong.dart'; 

// استيراد المكونات المساعدة
import '../widgets/settings_widgets.dart'; 
import '../widgets/map_picker_sheet.dart'; 
import '../state_management/theme_manager.dart'; 

//  التصحيح الأول: تعديل الدالة المساعدة لتقبل BuildContext
TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color, required BuildContext context}) {
  // استخدام لون النص الأساسي للـ Theme الحالي كلون افتراضي
  final defaultColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black; 
  
  return TextStyle(
    fontFamily: 'TenorSans', 
    fontSize: size,
    fontWeight: weight,
    // اللون الافتراضي هو اللون المناسب للـ Theme
    color: color ?? defaultColor, 
  );
}


class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // ... (State variables remain the same)
  String _name = "";
  String _surname = "";
  String _address = "";
  String _contactNumber = "";
  String _nationalID = "";
  String _errorMessage = "";
  bool _isLoading = false;
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isSuccessMessage = false;
  String _buildingInfo = "";
  String _apartmentNumber = "";
  String _deliveryInstructions = "";

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _fetchCustomerInfo();
  }
  
  void _updateControllers() {
    _addressController.text = _address;
    _buildingController.text = _buildingInfo;
    _apartmentController.text = _apartmentNumber;
    _instructionsController.text = _deliveryInstructions;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _buildingController.dispose();
    _apartmentController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // MARK: - Firebase Ops (No change)
  void _fetchCustomerInfo() async {
    // ... (منطق جلب البيانات يبقى كما هو)
    setState(() { _isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() { 
        _errorMessage = "User is not authenticated";
        _isLoading = false;
      });
      return;
    }

    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _name = data['name'] as String? ?? "";
          _surname = data['surname'] as String? ?? "";
          _address = data['address'] as String? ?? "";
          _contactNumber = data['contactNumber'] as String? ?? "";
          _nationalID = data['nationalID'] as String? ?? "";
          _latitude = (data['latitude'] as num?)?.toDouble() ?? 0.0;
          _longitude = (data['longitude'] as num?)?.toDouble() ?? 0.0;
          _buildingInfo = data['buildingInfo'] as String? ?? "";
          _apartmentNumber = data['apartmentNumber'] as String? ?? "";
          _deliveryInstructions = data['deliveryInstructions'] as String? ?? "";
        });
        _updateControllers();
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _errorMessage = "Error fetching data: $e";
        });
      }
      print("Error fetching customer info: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _updateAddress() async {
    // ... (منطق تحديث البيانات يبقى كما هو)
    setState(() { 
      _isLoading = true;
      _errorMessage = "";
      _isSuccessMessage = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { 
        _errorMessage = "Authentication error";
        _isLoading = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .update({
            "address": _addressController.text,
            "latitude": _latitude, 
            "longitude": _longitude, 
            "buildingInfo": _buildingController.text,
            "apartmentNumber": _apartmentController.text,
            "deliveryInstructions": _instructionsController.text,
          });

      if (mounted) {
        setState(() {
          _errorMessage = "Address updated successfully!";
          _isSuccessMessage = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _errorMessage = "");
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Update failed: $e";
        });
      }
      print("Update address failed: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showMapPicker() async {
    // ... (منطق عرض الخريطة يبقى كما هو)
    final defaultLat = 24.7136; 
    final defaultLng = 46.6753;
    
    final initialCoordinate = LatLng(
        _latitude != 0.0 ? _latitude : defaultLat,
        _longitude != 0.0 ? _longitude : defaultLng
    );
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MapPickerSheet(initialCoordinate: initialCoordinate),
    );

    if (result != null) {
      setState(() {
        _address = result['address'] as String;
        _latitude = result['latitude'] as double;
        _longitude = result['longitude'] as double;
        _addressController.text = _address; 
      });
    }
  }

  // MARK: - Theme Section (No change needed here, it uses context correctly)

  Widget _buildThemeSection(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final iconColor = Theme.of(context).colorScheme.secondary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Theme.of(context).primaryColor;
    
    final themeSwitch = Switch.adaptive(
      value: themeManager.isDarkMode,
      onChanged: (bool newValue) {
        themeManager.switchTheme(); 
      },
      activeColor: iconColor,
    );

    return _buildSection(
        title: "App Settings",
        children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      themeManager.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded, 
                      color: iconColor, 
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      themeManager.isDarkMode ? "Dark Mode" : "Light Mode",
                      //  تحديث: تمرير context للدالة
                      style: _getTenorSansStyle(15, weight: FontWeight.w500, context: context).copyWith(color: textColor),
                    ),
                  ],
                ),
                themeSwitch,
              ],
            )
        ]
    );
  }

  // MARK: - Build Method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //  التصحيح الثاني: تمرير context للدالة
        title: Text("Settings", style: _getTenorSansStyle(18, weight: FontWeight.w600, context: context)),
        centerTitle: true,
        // باقي الخصائص تأتي من AppBarTheme في main.dart
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600, 
          ),
          child: _isLoading && _name.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      // 1. Personal Info Section
                      _buildSection(
                        title: "Personal Information",
                        children: [
                          IconTextRow(
                            icon: Icons.person_rounded, 
                            label: "Name", 
                            value: "$_name $_surname"
                          ),
                          IconTextRow(
                            icon: Icons.phone_android_rounded, 
                            label: "Phone", 
                            value: _contactNumber
                          ),
                          IconTextRow(
                            icon: Icons.credit_card_rounded, 
                            label: "National ID", 
                            value: _nationalID
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      _buildThemeSection(context), 
                      
                      const SizedBox(height: 24),
                      
                      // 2. Address Form Section
                      _buildSection(
                        title: "Address Details",
                        children: [
                          // ... (باقي الـ LabeledTextFields والـ MapButton لا تستخدم _getTenorSansStyle مباشرة، لكنها تستفيد من ألوان الـ Theme العامة)
                          LabeledTextField(
                            icon: Icons.house_rounded, 
                            placeholder: "Enter your full address", 
                            controller: _addressController,
                            readOnly: true, 
                          ),
                          
                          _buildMapButton(),
                          
                          LabeledTextField(
                            icon: Icons.business_rounded, 
                            placeholder: "Building Info", 
                            controller: _buildingController,
                          ),
                          LabeledTextField(
                            icon: Icons.dialpad_rounded, 
                            placeholder: "Apartment Number", 
                            controller: _apartmentController,
                          ),
                          LabeledTextField(
                            icon: Icons.edit_note_rounded, 
                            placeholder: "Delivery Instructions", 
                            controller: _instructionsController,
                          ),

                          if (_errorMessage.isNotEmpty)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _errorMessage,
                                  key: ValueKey(_errorMessage),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _isSuccessMessage ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 3. Save Button
                      _buildSaveButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // MARK: - Helper Widgets

  Widget _buildSection({required String title, required List<Widget> children}) {
    final containerColor = Theme.of(context).cardColor; 

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1), 
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            //  التصحيح الثالث: تمرير context للدالة
            style: _getTenorSansStyle(17, weight: FontWeight.w600, context: context),
          ),
          Divider(height: 24, color: Theme.of(context).dividerColor), 
          ...children.map((child) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: child,
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildMapButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: ElevatedButton.icon(
        onPressed: _showMapPicker,
        icon: const Icon(Icons.map_rounded),
        label: const Text("Select on Map"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor, 
          foregroundColor: Theme.of(context).colorScheme.background, 
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          //  التصحيح الرابع: تمرير context للدالة
          textStyle: _getTenorSansStyle(15, context: context), 
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, 
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: Colors.green.withOpacity(0.5),
          elevation: 5,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Save Address",
                    //  التصحيح الخامس: تمرير context للدالة
                    style: _getTenorSansStyle(16, weight: FontWeight.w600, context: context).copyWith(color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}