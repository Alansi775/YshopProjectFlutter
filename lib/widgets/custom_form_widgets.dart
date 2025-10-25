// lib/widgets/custom_form_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';


// MARK: - Custom Colors (احتفظنا بالثوابت فقط إن كانت ضرورية لألوان محددة، لكن يفضل استخدام الثيم)
// سنحتفظ بـ accentBlue فقط، والباقي سيُستبدل بألوان الثيم
const Color accentBlue = Color.fromRGBO(64, 128, 230, 1.0); // لون تمييز ثابت إذا لزم الأمر

// MARK: - Custom TextField Styles (UnderlinedTextField)
class UnderlinedTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final ValueChanged<String>? onSubmitted;

  const UnderlinedTextField({
    Key? key,
    required this.placeholder,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //  1. استخراج الألوان من الثيم
    // primaryColor: للخط الأساسي والكتابة (أسود في الفاتح، أبيض في الداكن)
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    // secondaryColor: للنصوص الثانوية (مثل الـ placeholder)
    final Color secondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6); 
    // dividerColor: لون الخط الفاصل
    final Color dividerColor = Theme.of(context).dividerColor; 

    //  2. TextSelectionThemeData: المؤشر والتضليل
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        // استخدام اللون الأساسي للثيم
        cursorColor: primaryColor, 
        selectionColor: primaryColor.withOpacity(0.3), 
        selectionHandleColor: primaryColor, 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Placeholder as a label above the field
          Text(
            placeholder,
            style: TextStyle( //  إزالة const
              fontSize: 12,
              //  استخدام اللون الثانوي الديناميكي
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 6),
          // TextField / SecureField
          TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            //  التعديل الحاسم: تعيين لون الكتابة (style) ليعتمد على الثيم
            style: TextStyle(
              color: primaryColor, // سيصبح أبيض في الوضع الداكن
              fontSize: 16,
            ),
            textCapitalization: (keyboardType == TextInputType.emailAddress || isPassword) 
                ? TextCapitalization.none 
                : TextCapitalization.words,
            textInputAction: onSubmitted != null ? TextInputAction.go : TextInputAction.next,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none, // إزالة الحدود الافتراضية
            ),
          ),
          Padding( //  إزالة const
            padding: const EdgeInsets.only(top: 8.0),
            child: Divider(
              height: 1,
              //  استخدام لون الفاصل الديناميكي
              color: dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: - UnderlinedSecureField
// هذا لا يحتاج إلى تعديل لأنه يستخدم UnderlinedTextField
class UnderlinedSecureField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted; 

  const UnderlinedSecureField({
    Key? key,
    required this.placeholder,
    required this.controller,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UnderlinedTextField(
      placeholder: placeholder,
      controller: controller,
      isPassword: true,
      keyboardType: TextInputType.visiblePassword,
      onSubmitted: onSubmitted,
    );
  }
}

// MARK: - Primary Action Button Style
class PrimaryActionButton extends StatelessWidget {
  final String title;
  final VoidCallback action;
  final bool isLoading;

  const PrimaryActionButton({
    Key? key,
    required this.title,
    required this.action,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //  الحصول على لون التمييز من الثيم (يفترض أنه accentBlue أو ما شابه)
    final Color accentColor = Theme.of(context).colorScheme.secondary; 
    
    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: ElevatedButton(
        onPressed: isLoading ? null : action,
        style: ElevatedButton.styleFrom(
          //  استخدام لون التمييز الديناميكي
          backgroundColor: accentColor, 
          foregroundColor: Colors.white, // النص يبقى أبيض لتحقيق التباين
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50), 
          padding: const EdgeInsets.symmetric(vertical: 15),
          //  استخدام لون التمييز في الظل
          shadowColor: accentColor.withOpacity(0.3), 
          elevation: 8,
        ),
        child: isLoading 
            ? const SizedBox(
                height: 20, 
                width: 20,
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                ),
              )
            : Text( //  أضفنا const مرة أخرى هنا إذا كان النص ثابتاً
                title,
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600, 
          ),
        ),
      ),
    );
  }
}