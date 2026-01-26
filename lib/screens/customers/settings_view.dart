import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../services/api_service.dart';
import 'package:provider/provider.dart'; 
import 'package:latlong2/latlong.dart'; 

// استيراد المكونات المساعدة
import '../../widgets/settings_widgets.dart'; 
import '../../widgets/map_picker_sheet.dart'; 
import '../../state_management/theme_manager.dart';
import '../../state_management/auth_manager.dart';
import '../auth/sign_in_ui.dart'; // LuxuryTheme colors 


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

  double _parseToDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }


  @override
  void initState() {
    super.initState();
    // Fetch customer info asynchronously
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
    // 🔥 CRITICAL FIX: ALWAYS fetch from API first - cache may be incomplete!
    // The cached profile from login might not have all fields (name, surname, etc.)
    
    final authManager = Provider.of<AuthManager>(context, listen: false);
    Map<String, dynamic>? cachedProfile = authManager.userProfile;
    
    // If we have cached profile, show it immediately while fetching fresh data
    if (cachedProfile != null && cachedProfile.containsKey('name')) {
      debugPrint('📋 SettingsView - Showing cached profile, fetching fresh data...');
      _updateProfileData(cachedProfile);
    }

    // ALWAYS fetch fresh from API to ensure complete/updated data
    setState(() => _isLoading = true);
    try {
      debugPrint('📋 SettingsView - Fetching fresh profile from API...');
      Map<String, dynamic>? apiProfile = await ApiService.getUserProfile();
      debugPrint('📋 SettingsView - API Response: ${apiProfile != null ? apiProfile.keys.toString() : 'NULL'}');
      
      if (apiProfile != null && mounted) {
        // Update UI with fresh data
        _updateProfileData(apiProfile);
        // 🔥 CRITICAL: Update AuthManager cache with complete profile
        authManager.updateCachedProfile(apiProfile);
        debugPrint(' SettingsView - Profile updated from API and cached');
      } else {
        debugPrint('❌ SettingsView - API returned null');
        if (mounted) setState(() { _errorMessage = "Could not load profile data from server"; });
      }
    } catch (e) {
      debugPrint('❌ SettingsView - Error: $e');
      if (mounted) setState(() { _errorMessage = "Error: $e"; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  /// Helper to update profile data (used by both cache and API paths)
  void _updateProfileData(Map<String, dynamic> profile) {
    if (!mounted) return;
    
    debugPrint('📋 SettingsView._updateProfileData - Profile data: name=${profile['name']}, phone=${profile['phone']}, address=${profile['address']}');
    setState(() {
      final dn = (profile['display_name'] as String?) ?? (profile['displayName'] as String?) ?? "";
      // Prefer explicit fields when available
      _name = (profile['name'] as String?) ?? "";
      _surname = (profile['surname'] as String?) ?? "";

      // If `name` is empty, derive first name from display_name (use first token)
      if (_name.isEmpty) {
        final parts = dn.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          _name = parts.first;
          // If surname missing, take last token as surname
          if (_surname.isEmpty && parts.length > 1) {
            _surname = parts.last;
          }
        }
      }

      _address = (profile['address'] as String?) ?? "";
      _contactNumber = (profile['phone'] as String?) ?? "";
      _nationalID = (profile['national_id'] as String?) ?? "";
      _latitude = _parseToDouble(profile['latitude']);
      _longitude = _parseToDouble(profile['longitude']);
      _buildingInfo = (profile['building_info'] as String?) ?? (profile['buildingInfo'] as String?) ?? "";
      _apartmentNumber = (profile['apartment_number'] as String?) ?? (profile['apartmentNumber'] as String?) ?? "";
      _deliveryInstructions = (profile['delivery_instructions'] as String?) ?? (profile['deliveryInstructions'] as String?) ?? "";
      debugPrint('📋 SettingsView._updateProfileData - State updated: _name=$_name, _contactNumber=$_contactNumber, _address=$_address');
    });
    _updateControllers();
  }

  void _updateAddress() async {
    // ... (منطق تحديث البيانات يبقى كما هو)
    setState(() { 
      _isLoading = true;
      _errorMessage = "";
      _isSuccessMessage = false;
    });

    try {
      // 🔥 CRITICAL: Only send non-empty values to API
      // Empty values will cause "undefined parameters" error in backend
      
      final updatePayload = <String, dynamic>{};
      
      // Add displayName if not empty
      final displayName = _name.trim().isNotEmpty ? '$_name ${_surname.trim()}'.trim() : null;
      if (displayName != null) updatePayload['displayName'] = displayName;
      
      // Add surname if not empty
      if (_surname.trim().isNotEmpty) updatePayload['surname'] = _surname.trim();
      
      // Add phone if not empty
      if (_contactNumber.trim().isNotEmpty) updatePayload['phone'] = _contactNumber.trim();
      
      // Add address if not empty
      if (_addressController.text.trim().isNotEmpty) updatePayload['address'] = _addressController.text.trim();
      
      // Add latitude/longitude if not 0
      if (_latitude != 0.0) updatePayload['latitude'] = _latitude;
      if (_longitude != 0.0) updatePayload['longitude'] = _longitude;
      
      // Add nationalId if not empty
      if (_nationalID.trim().isNotEmpty) updatePayload['nationalId'] = _nationalID.trim();
      
      // Add building info if not empty
      if (_buildingController.text.trim().isNotEmpty) updatePayload['buildingInfo'] = _buildingController.text.trim();
      
      // Add apartment number if not empty
      if (_apartmentController.text.trim().isNotEmpty) updatePayload['apartmentNumber'] = _apartmentController.text.trim();
      
      // Add delivery instructions if not empty
      if (_instructionsController.text.trim().isNotEmpty) updatePayload['deliveryInstructions'] = _instructionsController.text.trim();
      
      debugPrint(' SettingsView._updateAddress - Sending payload: $updatePayload');
      
      await ApiService.updateUserProfile(
        displayName: updatePayload['displayName'] as String?,
        surname: updatePayload['surname'] as String?,
        phone: updatePayload['phone'] as String?,
        address: updatePayload['address'] as String?,
        latitude: updatePayload['latitude'] as double?,
        longitude: updatePayload['longitude'] as double?,
        nationalId: updatePayload['nationalId'] as String?,
        buildingInfo: updatePayload['buildingInfo'] as String?,
        apartmentNumber: updatePayload['apartmentNumber'] as String?,
        deliveryInstructions: updatePayload['deliveryInstructions'] as String?,
      );

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
      if (mounted) setState(() { _errorMessage = "Update failed: $e"; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapPickerSheet(initialCoordinate: initialCoordinate),
      ),
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

  // MARK: - Theme Section (Luxury Glass Style)

  Widget _buildThemeSection(BuildContext context, bool isDark, Color liquidBg, Color liquidBorder, Color textColor) {
    final themeManager = Provider.of<ThemeManager>(context);

    return _buildLuxurySection(
        context: context,
        title: "App Settings",
        isDark: isDark,
        liquidBg: liquidBg,
        liquidBorder: liquidBorder,
        textColor: textColor,
        children: [
            _buildThemeToggleButtons(context, isDark, themeManager, textColor),
        ]
    );
  }

  // Theme Toggle Buttons - Elegant Two-Button Design
  Widget _buildThemeToggleButtons(BuildContext context, bool isDark, ThemeManager themeManager, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isDark) themeManager.switchTheme();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? LuxuryTheme.kLightBlueAccent.withOpacity(0.25)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? LuxuryTheme.kLightBlueAccent.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.nightlight_round,
                          color: isDark ? LuxuryTheme.kLightBlueAccent : Colors.grey.withOpacity(0.6),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Dark",
                          style: TextStyle(
                            fontFamily: 'TenorSans',
                            fontSize: 14,
                            fontWeight: isDark ? FontWeight.w700 : FontWeight.w500,
                            color: isDark ? LuxuryTheme.kLightBlueAccent : Colors.grey.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isDark) return;
                themeManager.switchTheme();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: !isDark
                          ? LuxuryTheme.kLightBlueAccent.withOpacity(0.25)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !isDark
                            ? LuxuryTheme.kLightBlueAccent.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wb_sunny_rounded,
                          color: !isDark ? LuxuryTheme.kLightBlueAccent : Colors.grey.withOpacity(0.6),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Light",
                          style: TextStyle(
                            fontFamily: 'TenorSans',
                            fontSize: 14,
                            fontWeight: !isDark ? FontWeight.w700 : FontWeight.w500,
                            color: !isDark ? LuxuryTheme.kLightBlueAccent : Colors.grey.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Luxury Glass Containers

  Widget _buildLuxurySection({
    required BuildContext context,
    required String title,
    required bool isDark,
    required Color liquidBg,
    required Color liquidBorder,
    required Color textColor,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: liquidBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: liquidBorder, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Didot',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isDark ? LuxuryTheme.kPlatinum.withOpacity(0.4) : LuxuryTheme.kDeepNavy.withOpacity(0.3),
                          isDark ? LuxuryTheme.kPlatinum.withOpacity(0.1) : LuxuryTheme.kDeepNavy.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
                ...children.map((child) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                )).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MARK: - Build Method

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.isDarkMode;
    
    // Luxury Colors
    final bgColor = isDark ? LuxuryTheme.kDarkBackground : LuxuryTheme.kLightBackground;
    final surfaceColor = isDark ? LuxuryTheme.kDarkSurface : LuxuryTheme.kLightSurface;
    final textColor = isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy;
    final liquidBgColor = isDark 
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);
    final liquidBorderColor = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.1);
    
    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Settings",
          style: TextStyle(
            fontFamily: 'Didot',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A1A)]
                : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _isLoading && _name.isEmpty 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 16),
                    child: Column(
                      children: [
                        // 1. Personal Info Section - Luxury Glass
                        _buildLuxurySection(
                          context: context,
                          title: "Personal Information",
                          isDark: isDark,
                          liquidBg: liquidBgColor,
                          liquidBorder: liquidBorderColor,
                          textColor: textColor,
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
                        
                        const SizedBox(height: 28),

                        _buildThemeSection(context, isDark, liquidBgColor, liquidBorderColor, textColor), 
                        
                        const SizedBox(height: 28),
                        
                        // 2. Address Form Section - Luxury Glass
                        _buildLuxurySection(
                          context: context,
                          title: "Address Details",
                          isDark: isDark,
                          liquidBg: liquidBgColor,
                          liquidBorder: liquidBorderColor,
                          textColor: textColor,
                          children: [
                            LabeledTextField(
                              icon: Icons.house_rounded, 
                              placeholder: "Enter your full address", 
                              controller: _addressController,
                              readOnly: true, 
                            ),
                            
                            _buildMapButton(isDark),
                            
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
                                      fontFamily: 'TenorSans',
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
                        _buildSaveButton(isDark, liquidBgColor, textColor),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }



  Widget _buildMapButton(bool isDark) {
    final textColor = isDark ? LuxuryTheme.kPlatinum : LuxuryTheme.kDeepNavy;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Location icon - standalone above button
          Icon(
            Icons.location_on_rounded,
            size: 42,
            color: LuxuryTheme.kLightBlueAccent.withOpacity(0.85),
          ),
          const SizedBox(height: 12),
          // Map button
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ElevatedButton(
                onPressed: _showMapPicker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LuxuryTheme.kLightBlueAccent.withOpacity(0.85),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  shadowColor: LuxuryTheme.kLightBlueAccent.withOpacity(0.3),
                  elevation: 6,
                ),
                child: Text(
                  "Select Location",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark, Color liquidBg, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: [
          // Icon above button - standalone
          Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: LuxuryTheme.kLightBlueAccent.withOpacity(0.8),
          ),
          const SizedBox(height: 16),
          // Save button
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LuxuryTheme.kLightBlueAccent.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  shadowColor: LuxuryTheme.kLightBlueAccent.withOpacity(0.4),
                  elevation: 8,
                  disabledBackgroundColor: LuxuryTheme.kLightBlueAccent.withOpacity(0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        "Save Address",
                        style: TextStyle(
                          fontFamily: 'TenorSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}