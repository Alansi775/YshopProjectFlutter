// lib/widgets/custom_form_widgets.dart
import 'package:flutter/material.dart';

// MARK: - Custom Colors (مكافئ لـ extension Color في SwiftUI)
// يجب أن تكون هذه الألوان معرفة في ملف الثيم (Theme) الرئيسي، لكن سنعرفها هنا مؤقتاً
const Color accentBlue = Color.fromRGBO(64, 128, 230, 1.0); // 0.25, 0.5, 0.9
const Color primaryText = Color.fromRGBO(26, 26, 26, 1.0); // 0.1, 0.1, 0.1
const Color secondaryText = Color.fromRGBO(102, 102, 102, 1.0); // 0.4, 0.4, 0.4
const Color backgroundGray = Color.fromRGBO(247, 247, 250, 1.0); // 0.97, 0.97, 0.98
const Color dividerGray = Color.fromRGBO(217, 217, 222, 1.0); // 0.85, 0.85, 0.87

// MARK: - Custom TextField Styles (UnderlinedTextField)
class UnderlinedTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isPassword;

  const UnderlinedTextField({
    Key? key,
    required this.placeholder,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // نستخدم TextSelectionTheme لتغيير لون المؤشر والتضليل والمقابض
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        cursorColor: primaryText, // لون المؤشر (أسود)
        selectionColor: primaryText.withOpacity(0.3), // لون التضليل (أسود شفاف)
        selectionHandleColor: primaryText, // لون مقابض التحديد
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Placeholder as a label above the field (مكافئ لـ Text(placeholder))
          Text(
            placeholder,
            style: const TextStyle(
              fontSize: 12,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          // TextField / SecureField
          TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(color: primaryText),
            textCapitalization: (keyboardType == TextInputType.emailAddress || isPassword) 
                ? TextCapitalization.none 
                : TextCapitalization.words,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none, // إزالة الحدود الافتراضية
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Divider(
              height: 1,
              color: dividerGray,
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: - UnderlinedSecureField (يستخدم نفس الـ Widget لكن مع isPassword = true)
class UnderlinedSecureField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;

  const UnderlinedSecureField({
    Key? key,
    required this.placeholder,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UnderlinedTextField(
      placeholder: placeholder,
      controller: controller,
      isPassword: true,
      keyboardType: TextInputType.visiblePassword,
    );
  }
}

// MARK: - Primary Action Button Style
class PrimaryActionButton extends StatelessWidget {
  final String title;
  final VoidCallback action;

  const PrimaryActionButton({
    Key? key,
    required this.title,
    required this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue, // خلفية الزر
          foregroundColor: Colors.white, // لون النص
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50), // توسيع الزر بالكامل
          padding: const EdgeInsets.symmetric(vertical: 15),
          shadowColor: accentBlue.withOpacity(0.3),
          elevation: 8,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16, // مكافئ لـ .headline
            fontWeight: FontWeight.w600, // مكافئ لـ .semibold
          ),
        ),
      ),
    );
  }
}