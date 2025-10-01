// lib/widgets/settings_widgets.dart

import 'package:flutter/material.dart';

//  التصحيح الأول: تعديل الدالة لتقبل BuildContext واستخدام لون النص الافتراضي للـ Theme
TextStyle _getTenorSansStyle(double size, {FontWeight weight = FontWeight.normal, Color? color, required BuildContext context}) {
  // اللون الافتراضي هو لون النص الأساسي للـ Theme الحالي
  final defaultColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black; 
  
  return TextStyle(
    fontFamily: 'TenorSans', 
    fontSize: size,
    fontWeight: weight,
    // اللون المختار أو اللون الافتراضي للـ Theme
    color: color ?? defaultColor, 
  );
}

// ------------------------------------
// 1. IconTextRow
// ------------------------------------
class IconTextRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const IconTextRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //  الوصول إلى لون الأيقونة الافتراضي من الـ Theme
    final iconColor = Theme.of(context).iconTheme.color; 
    // لون النص الثانوي (الذي كان رماديًا فاتحًا)
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // تقليل الـ Padding هنا
      child: Row(
        children: [
          //  التصحيح: استخدام لون الأيقونة من الـ Theme
          Icon(icon, color: iconColor?.withOpacity(0.7) ?? Colors.black54, size: 24), 
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                //  التصحيح: تمرير context واستخدام اللون الثانوي
                style: _getTenorSansStyle(12, context: context).copyWith(color: secondaryTextColor),
              ),
              Text(
                value,
                //  التصحيح: تمرير context (سيأخذ لون النص الأساسي للـ Theme)
                style: _getTenorSansStyle(15, weight: FontWeight.w500, context: context),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ------------------------------------
// 2. LabeledTextField
// ------------------------------------
class LabeledTextField extends StatelessWidget {
  final IconData icon;
  final String placeholder;
  final TextEditingController controller;
  final bool readOnly;

  const LabeledTextField({
    Key? key,
    required this.icon,
    required this.placeholder,
    required this.controller,
    this.readOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //  الحصول على ألوان الـ Theme
    final iconColor = Theme.of(context).iconTheme.color; 
    // لون خلفية حقل الإدخال (سيكون فاتحًا في الوضع الداكن وعاجيًا في الوضع الفاتح)
    final inputFieldColor = Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).dividerColor.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        //  التصحيح: استخدام لون خلفية متوافق مع الـ Theme
        color: inputFieldColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          //  التصحيح: استخدام لون الأيقونة من الـ Theme
          Icon(icon, color: iconColor?.withOpacity(0.7) ?? Colors.black54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: placeholder,
                //  التصحيح: تمرير context إلى الدالة
                hintStyle: _getTenorSansStyle(14, context: context).copyWith(color: Theme.of(context).hintColor),
                border: InputBorder.none,
              ),
              //  التصحيح: تمرير context إلى الدالة
              style: _getTenorSansStyle(15, context: context),
            ),
          ),
        ],
      ),
    );
  }
}