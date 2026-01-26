import 'package:flutter/material.dart';
import 'dart:ui'; // For glassmorphism effects
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../screens/customers/settings_view.dart';
import '../screens/auth/sign_in_view.dart'; 
import '../screens/auth/sign_in_ui.dart'; // Import luxury theme
import '../state_management/auth_manager.dart';
import '../state_management/theme_manager.dart'; // Import theme manager
import '../state_management/cart_manager.dart'; 

class SideMenuViewContents extends StatefulWidget {
  const SideMenuViewContents({Key? key}) : super(key: key);

  @override
  State<SideMenuViewContents> createState() => _SideMenuViewContentsState();
}

class _SideMenuViewContentsState extends State<SideMenuViewContents> {
  int _selectedCategoryIndex = 0;
  String _name = "Guest";
  String _surname = "User";
  
  final List<String> _storeTypes = ["FASHION", "PHARMACY", "RESTAURANT", "MARKET"];
  
  late Map<String, List<String>> categoriesByType;

  @override
  void initState() {
    super.initState();
    
    // Initialize categories by store type
    categoriesByType = {
      "FASHION": ["All", "Men", "Women", "Kids", "Shoes", "Accessories"],
      "PHARMACY": ["All", "Pain Relief", "Cold & Flu", "Vitamins", "First Aid", "Skincare"],
      "RESTAURANT": ["All", "Burgers", "Pizza", "Salads", "Desserts", "Beverages"],
      "MARKET": ["All", "Fruits", "Vegetables", "Dairy", "Grains", "Beverages"],
    };
    
    // Call immediately, no delay!
    _fetchUserData();
  }

  // منطق جلب بيانات المستخدم المصحح
  void _fetchUserData() {
    final authManager = Provider.of<AuthManager>(context, listen: false);
    
    // If not authenticated, show Guest
    if (!authManager.isAuthenticated) {
      if (mounted) setState(() { _name = 'Guest'; _surname = 'User'; });
      return;
    }

    // If authenticated, get profile from cache (don't fetch from API here)
    try {
      final profile = authManager.userProfile;
      if (profile != null && mounted) {
        final display = (profile['display_name'] as String?) ?? '';
        String first = '';
        String last = '';
        if (display.isNotEmpty) {
          final parts = display.split(' ');
          first = parts.first;
          last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
        
        final name = (profile['name'] as String?) ?? (first.isNotEmpty ? first : 'User');
        final surname = (profile['surname'] as String?) ?? last;
        
        debugPrint('📋 SideMenu - Updated from profile: name=$name, surname=$surname');
        setState(() {
          _name = name;
          _surname = surname;
        });
      } else {
        // No profile yet, use display_name
        setState(() { _name = 'User'; _surname = ''; });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() { _name = 'User'; _surname = ''; });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // استمع فقط للتغييرات، لا تستدعي _fetchUserData هنا
    Provider.of<AuthManager>(context, listen: true); 
  }
  
  // MARK: - Components

  Widget _buildUserProfileSection(BuildContext context, bool isDark, Color liquidBg) {
    final authManager = Provider.of<AuthManager>(context, listen: false);
    final isLoggedIn = authManager.isAuthenticated;
    
    final textColor = isDark 
        ? LuxuryTheme.kPlatinum 
        : LuxuryTheme.kDeepNavy;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: liquidBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isDark 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                child: Icon(Icons.person_rounded, size: 28, color: textColor.withOpacity(0.7)), 
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VStack(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoggedIn ? '$_name $_surname' : 'Welcome Guest',
                      style: TextStyle(
                        fontFamily: 'TenorSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 0.4,
                      ),
                      softWrap: true,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoggedIn ? 'Account Settings' : 'Sign In / Register',
                      style: TextStyle(
                        fontFamily: 'TenorSans',
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.2,
                      ),
                      softWrap: true,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context, bool isDark, Color liquidBg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector( 
          onTap: () => Navigator.of(context).pop(), 
          child: Container(
            width: 48, 
            height: 48, 
            decoration: BoxDecoration(
              color: liquidBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: Icon(
              Icons.close, 
              size: 24, 
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategorySelector(bool isDark, Color liquidBg, Color liquidBorder) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: liquidBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: liquidBorder),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: List.generate(_storeTypes.length, (index) {
                final isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? LuxuryTheme.kLightBlueAccent.withOpacity(0.8)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _storeTypes[index],
                      style: TextStyle(
                        fontFamily: 'TenorSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategoryItem(String title, bool isDark, Color liquidBg, Color liquidBorder, VoidCallback onTap) {
    final textColor = isDark 
        ? LuxuryTheme.kPlatinum 
        : LuxuryTheme.kDeepNavy;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: liquidBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: liquidBorder),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'TenorSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right, 
                    size: 18, 
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuFooter(BuildContext context, bool isDark, Color liquidBg, Color liquidBorder) {
    final authManager = Provider.of<AuthManager>(context); 
    final isLoggedIn = authManager.isAuthenticated;
    
    final textColor = isDark 
        ? LuxuryTheme.kPlatinum 
        : LuxuryTheme.kDeepNavy;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: liquidBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: liquidBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Support Button (Centered and featured)
                _buildSupportButton(context, isDark, liquidBg, liquidBorder, textColor),
                const SizedBox(height: 16),
                
                // Settings Button
                _buildMenuButton(
                  context,
                  icon: Icons.settings,
                  text: "Settings",
                  isDark: isDark,
                  textColor: textColor,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const SettingsView(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation.drive(Tween(begin: 0.0, end: 1.0)),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                Divider(
                  height: 1, 
                  color: isDark 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ), 
                const SizedBox(height: 16),

                // Logout/Login Button
                TextButton(
                  onPressed: () async {
                    if (isLoggedIn) {
                      final cartManager = context.read<CartManager>();
                      await cartManager.clearCart();
                      
                      await authManager.signOut();
                      
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const SignInView()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } else {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const SignInView()),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isLoggedIn 
                              ? Colors.red.withOpacity(0.15)
                              : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLoggedIn 
                                ? Colors.red.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLoggedIn ? "Logout" : "Sign In",
                              style: TextStyle(
                                fontFamily: 'TenorSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isLoggedIn ? Colors.red[400] : Colors.green[400],
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              isLoggedIn ? Icons.logout : Icons.login, 
                              size: 18, 
                              color: isLoggedIn ? Colors.red[400] : Colors.green[400],
                            ),
                          ],
                        ),
                      ),
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
  
  Widget _buildSupportButton(BuildContext context, bool isDark, Color liquidBg, Color liquidBorder, Color textColor) {
    return GestureDetector(
      onTap: () {
        // Call support number
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: liquidBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: liquidBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Support Label
                  Text(
                    'Support',
                    style: TextStyle(
                      fontFamily: 'TenorSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: LuxuryTheme.kLightBlueAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Phone Number (Main)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 20,
                        color: LuxuryTheme.kLightBlueAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '+90 539 255 4609',
                        style: TextStyle(
                          fontFamily: 'TenorSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon, 
    required String text, 
    required bool isDark,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon, 
                  size: 24, 
                  color: LuxuryTheme.kLightBlueAccent,
                ),
                const SizedBox(width: 16),
                Expanded( 
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'TenorSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right, 
                  size: 16, 
                  color: isDark ? Colors.white.withOpacity(0.24) : Colors.black.withOpacity(0.24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.isDarkMode;
    
    // Liquid Glass Colors
    final backgroundColor = isDark 
        ? LuxuryTheme.kDarkBackground 
        : LuxuryTheme.kLightBackground;
    
    final liquidBg = isDark 
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.08);
    
    final liquidBorder = isDark 
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.15);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final menuWidth = screenWidth > 600 ? 300.0 : screenWidth * 0.8; 
    
    return SizedBox(
      width: menuWidth, 
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A1A)]
                : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header with Liquid Glass effect
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Row(
                children: [
                  Expanded( 
                    child: _buildUserProfileSection(context, isDark, liquidBg),
                  ),
                  const SizedBox(width: 10),
                  _buildCloseButton(context, isDark, liquidBg),
                ],
              ),
            ),
            
            // Categories and Footer
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategorySelector(isDark, liquidBg, liquidBorder),
                    
                    // Category Items List (Dynamic based on selected store type)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: categoriesByType[_storeTypes[_selectedCategoryIndex]]!
                            .map((category) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _buildCategoryItem(category, isDark, liquidBg, liquidBorder, () {
                                Navigator.of(context).pop(); 
                              }),
                            ))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    
                    _buildMenuFooter(context, isDark, liquidBg, liquidBorder),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// VStack Helper (لا تغيير فيها)
class VStack extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  const VStack({Key? key, required this.children, this.crossAxisAlignment = CrossAxisAlignment.center}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}