import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_view.dart';
// يجب استيراد شاشة تسجيل الدخول لاستخدامها في التوجيه
import '../screens/sign_in_view.dart'; 
import '../state_management/auth_manager.dart'; 

// دالة مساعدة لخط "TenorSans" (مُعدّلة لاستخدام لون النص من الـ Theme عند عدم تحديد لون)
TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color, required BuildContext context}) {
  // اللون الافتراضي هو لون النص الأساسي للـ Theme الحالي
  final defaultColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  
  return TextStyle(
    fontFamily: 'TenorSans', 
    fontSize: size,
    fontWeight: weight,
    color: color ?? defaultColor,
  );
}

class SideMenuViewContents extends StatefulWidget {
  const SideMenuViewContents({Key? key}) : super(key: key);

  @override
  State<SideMenuViewContents> createState() => _SideMenuViewContentsState();
}

class _SideMenuViewContentsState extends State<SideMenuViewContents> {
  int _selectedCategoryIndex = 0;
  String _name = "Guest";
  String _surname = "User";
  
  final List<String> _categoryTabs = ["WOMEN", "MEN", "KIDS"];
  final List<String> _categories = ["All", "Apparel", "Dress", "T-Shirt", "Bag"];
  
  // لتقليل عمليات جلب البيانات
  User? _lastCheckedUser;

  // منطق جلب بيانات المستخدم المصحح
  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == _lastCheckedUser && user != null) return;
    _lastCheckedUser = user;

    if (user != null) {
      try {
        DocumentSnapshot userData = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();

        if (userData.exists && mounted) {
          setState(() {
            _name = userData['name'] as String? ?? "User";
            _surname = userData['surname'] as String? ?? "";
          });
        } else if (mounted) {
           setState(() {
            _name = user.displayName?.split(' ').first ?? user.email?.split('@').first ?? "User";
            _surname = user.displayName?.split(' ').last ?? "";
          });
        }
      } catch (e) {
        if (mounted) {
           setState(() {
            _name = "Error";
            _surname = "Loading";
          });
        }
        print("Error fetching user data: $e");
      }
    } else if (mounted) {
       setState(() {
            _name = "Guest";
            _surname = "User";
          });
    }
  }

  @override
  void initState() {
    super.initState();
    // لا نحتاج لاستدعاء _fetchUserData() هنا، نعتمد على didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // الاستماع لتغييرات حالة تسجيل الدخول/الخروج
    Provider.of<AuthManager>(context, listen: true); 
    _fetchUserData(); 
  }
  
  // MARK: - Components

  Widget _buildUserProfileSection(BuildContext context) {
    final authManager = Provider.of<AuthManager>(context, listen: false);
    final isLoggedIn = authManager.currentUser != null;
    
    // الحصول على لون النص الافتراضي من الـ Theme
    final defaultTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          //  تحديث: استخدام لون خلفية يتغير مع الـ Theme
          backgroundColor: Theme.of(context).dividerColor.withOpacity(0.5),
          child: Icon(Icons.person_rounded, size: 30, color: defaultTextColor.withOpacity(0.7)), 
        ),
        const SizedBox(width: 16),
        VStack(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLoggedIn ? '$_name $_surname' : 'Welcome Guest',
              //  تحديث: تمرير context إلى الدالة
              style: _getTenorSansStyle(16, weight: FontWeight.w600, context: context),
              overflow: TextOverflow.ellipsis, 
            ),
            const SizedBox(height: 4),
            Text(
              isLoggedIn ? 'Account Settings' : 'Sign In / Register',
              //  تحديث: تمرير context إلى الدالة
              style: _getTenorSansStyle(12, color: Colors.grey, context: context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    // لون البطاقة (Card Color) يتغير بين الأبيض والداكن
    final cardColor = Theme.of(context).cardColor;
    
    return GestureDetector( 
      onTap: () => Navigator.of(context).pop(), 
      child: Container(
        width: 32, 
        height: 32, 
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          //  تحديث: استخدام لون البطاقة
          color: cardColor, 
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              //  تحديث: استخدام لون الظل من الـ Theme
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.close, size: 24, color: Colors.grey),
      ),
    );
  }
  
  Widget _buildCategorySelector() {
     // استخدام context لتمريره إلى الدالة المساعدة
     final BuildContext context = this.context; 
     final dividerColor = Theme.of(context).dividerColor; // لون الفاصل/الحدود

     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(_categoryTabs.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  //  تحديث: استخدام الألوان الرئيسية من الـ Theme
                  color: isSelected ? Theme.of(context).primaryColor : Colors.transparent, 
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? null : Border.all(color: dividerColor, width: 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  _categoryTabs[index],
                  //  تحديث: تمرير context إلى الدالة
                  style: _getTenorSansStyle(12, weight: FontWeight.w600, context: context).copyWith(
                    // لون النص يصبح عكس لون الخلفية (أبيض في الداكن، أسود في الفاتح)
                    color: isSelected ? Theme.of(context).colorScheme.background : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildCategoryItem(String title, VoidCallback onTap) {
    // الحصول على الألوان من الـ Theme
    final cardColor = Theme.of(context).cardColor;
    final shadowColor = Theme.of(context).shadowColor;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          //  تحديث: استخدام لون البطاقة
          color: cardColor, 
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              //  تحديث: استخدام لون الظل
              color: shadowColor.withOpacity(0.05), 
              blurRadius: 8, 
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              title,
              //  تحديث: تمرير context إلى الدالة
              style: _getTenorSansStyle(15, weight: FontWeight.w500, context: context),
            ),
            const Spacer(),
            //  تحديث: أيقونة بلون يتوافق مع الـ Theme
            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuFooter(BuildContext context) {
    final authManager = Provider.of<AuthManager>(context); 
    final isLoggedIn = authManager.currentUser != null;
    
    // الحصول على الألوان من الـ Theme
    final cardColor = Theme.of(context).cardColor;
    final shadowColor = Theme.of(context).shadowColor;
    final dividerColor = Theme.of(context).dividerColor;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          //  تحديث: استخدام لون البطاقة
          color: cardColor, 
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              //  تحديث: استخدام لون الظل
              color: shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Menu Buttons
            _buildMenuButton(
              context,
              icon: Icons.phone_rounded, 
              text: "(+90) 39 255 4609",
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              context,
              icon: Icons.location_on,
              text: "Store Locator",
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              context,
              icon: Icons.settings,
              text: "Settings",
              onTap: () {
                Navigator.of(context).pop(); 
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SettingsView())
                );
              },
            ),
            
            const SizedBox(height: 24),
            //  تحديث: استخدام لون الفاصل
            Divider(height: 1, color: dividerColor), 
            const SizedBox(height: 24),

            // Logout/Login Button
            TextButton(
              onPressed: () async {
                if (isLoggedIn) {
                  await authManager.signOut();
                  
                  if (mounted) {
                    //  تم تصحيح الخطأ: حذف كلمة const من أمام SignInView
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const SignInView()),
                      (Route<dynamic> route) => false,
                    );
                  }
                } else {
                  Navigator.of(context).pop(); 
                  // توجيه المستخدم لصفحة تسجيل الدخول
                  Navigator.of(context).push(
                    //  تم تصحيح الخطأ: حذف كلمة const من أمام SignInView
                    MaterialPageRoute(builder: (context) => const SignInView()),
                  );
                }
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              //  تم تصحيح الخطأ: إضافة الوسيط child
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isLoggedIn ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLoggedIn ? "Logout" : "Sign In",
                      style: _getTenorSansStyle(14, weight: FontWeight.w600, context: context).copyWith(color: isLoggedIn ? Colors.red : Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Icon(isLoggedIn ? Icons.logout : Icons.login, size: 20, color: isLoggedIn ? Colors.red : Colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuButton(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    // الحصول على الألوان من الـ Theme
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final buttonColor = Theme.of(context).dividerColor.withOpacity(0.5); // لون خلفية خفيف

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          //  تحديث: استخدام لون خلفية يتغير مع الـ Theme
          color: buttonColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            //  تحديث: أيقونة بلون يتوافق مع الـ Theme
            Icon(icon, size: 24, color: Theme.of(context).iconTheme.color?.withOpacity(0.7)),
            const SizedBox(width: 16),
            Expanded( 
              child: Text(
                text,
                //  تحديث: تمرير context إلى الدالة
                style: _getTenorSansStyle(14, context: context).copyWith(color: primaryTextColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            //  تحديث: أيقونة بلون يتوافق مع الـ Theme
            Icon(Icons.chevron_right, size: 16, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // لون خلفية الـ Scaffold (القائمة الجانبية)
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final menuWidth = screenWidth > 600 ? 300.0 : screenWidth * 0.8; 
    
    return SizedBox(
      width: menuWidth, 
      child: Container(
        //  تحديث: استخدام لون خلفية الـ Scaffold
        color: scaffoldColor, 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
              child: Row(
                children: [
                  Expanded( 
                    child: _buildUserProfileSection(context),
                  ),
                  const SizedBox(width: 10),
                  _buildCloseButton(context),
                ],
              ),
            ),
            
            // Categories and Footer
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategorySelector(),
                    
                    // Category Items List
                    ..._categories.map((category) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildCategoryItem(category, () {
                        Navigator.of(context).pop(); 
                      }),
                    )).toList(),

                    const SizedBox(height: 30),
                    
                    _buildMenuFooter(context),
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