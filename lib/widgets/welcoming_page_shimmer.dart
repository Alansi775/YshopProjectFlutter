import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
// يجب أن يكون هذا الملف هو مصدر تعريف الألوان
import 'custom_form_widgets.dart'; 

class WelcomingPageShimmer extends StatelessWidget {
  const WelcomingPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    // نعتمد على أن primaryText و accentBlue معرفان في custom_form_widgets
    return Column(
      children: [
        // 1. نص الترحيب العادي
        const Text(
          "Welcome to",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: primaryText, 
          ),
        ),
        const SizedBox(height: 5),

        // 2. دمج Shimmer و RichText للتأثير المخصص (YS بلون ثابت، HOP يتوهج)
        Shimmer.fromColors(
          baseColor: Colors.grey.shade400, // لون نص "SHOP" المبدئي
          highlightColor: accentBlue, // اللون الأزرق الجذاب الذي ينتشر
          period: const Duration(seconds: 8), // فترة زمنية أطول لحركة أنيقة
          child: Text.rich(
            TextSpan(
              children: [
                // YS بلون أزرق أنيق وثابت لتمييز العلامة
                const TextSpan(
                  text: "YS",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: accentBlue, 
                  ),
                ),
                // HOP بلون يتأثر بالشيمر الذي ينتشر من YS
                TextSpan(
                  text: "HOP",
                  style: TextStyle(
                    fontFamily: 'TenorSans',
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade400, // اللون الأساسي للشيمر
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