import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
// يجب أن يكون هذا الملف هو مصدر تعريف الألوان
import 'custom_form_widgets.dart'; 
//  ملاحظة: نحن لا نستخدم primaryText هنا بعد الآن.

class WelcomingPageShimmer extends StatelessWidget {
  const WelcomingPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    //  1. الحصول على لون النص الأساسي من الثيم
    final Color primaryTextColor = Theme.of(context).colorScheme.primary; 
    
    //  2. الحصول على لون التمييز الثانوي من الثيم (بدلاً من accentBlue الثابت)
    // هذا اللون يفضل أن يكون ثابتًا في الثيم (نفس الأزرق الخفيف)
    final Color accentColor = const Color(0xFF42A5F5); // الأزرق الخفيف 
    
    //  3. لون رمادي يتغير مع الثيم: أفتح في الداكن وأغمق في الفاتح
    final Color shimmerBaseColor = Theme.of(context).brightness == Brightness.dark 
        ? Colors.grey.shade700 // أغمق قليلاً في الوضع الداكن
        : Colors.grey.shade400; // أفتح قليلاً في الوضع الفاتح

    return Column(
      children: [
        // 1. نص الترحيب العادي (Welcome to)
        Text( //  إزالة const إذا كان سيستخدم متغيراً ديناميكياً
          "Welcome to",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: primaryTextColor, // 👈 التعديل الحاسم: استخدام اللون الديناميكي للثيم
          ),
        ),
        const SizedBox(height: 5),

        // 2. دمج Shimmer و RichText
        Shimmer.fromColors(
          baseColor: shimmerBaseColor, //  استخدام اللون الديناميكي للشيمر
          highlightColor: accentColor, //  استخدام لون التمييز الديناميكي
          period: const Duration(seconds: 8), 
          child: Text.rich(
            TextSpan(
              children: [
                // YS بلون أزرق أنيق وثابت لتمييز العلامة
                 TextSpan( //  إزالة const لـ TextSpan
                  text: "YS",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: accentColor, //  استخدام لون التمييز
                  ),
                ),
                // HOP بلون يتأثر بالشيمر الذي ينتشر من YS
                TextSpan(
                  text: "HOP",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: shimmerBaseColor, //  استخدام لون الشيمر الأساسي
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}