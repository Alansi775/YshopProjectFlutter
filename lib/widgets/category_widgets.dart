// lib/widgets/category_widgets.dart (الكود المصحح والنهائي)

import 'package:flutter/material.dart';
import '../screens/stores_list_view.dart'; 

// -------------------------------------------------------------
// MARK: - Category Mappings (تبقى ثابتة)
// -------------------------------------------------------------
const Map<String, IconData> categoryIconMappings = {
  "Food": Icons.restaurant_menu_rounded,
  "Pharmacy": Icons.local_hospital_rounded,
  "Clothes": Icons.checkroom_rounded,
  "Market": Icons.shopping_basket_rounded,
  "Restaurants": Icons.restaurant_rounded,
};

const Map<String, Color> categoryColorMappings = {
  "Food": Color.fromRGBO(232, 181, 130, 1.0), // ثابت
  "Pharmacy": Color.fromRGBO(143, 201, 250, 1.0), // ثابت
  "Clothes": Color.fromRGBO(209, 158, 232, 1.0), // ثابت
  "Market": Color.fromRGBO(168, 222, 168, 1.0), // ثابت
  "Restaurants": Color.fromRGBO(250, 153, 153, 1.0), // ثابت
};


// -------------------------------------------------------------
// MARK: - Category Card Component (CategoryCard)
// -------------------------------------------------------------
class CategoryCard extends StatefulWidget {
  final String category;

  const CategoryCard({Key? key, required this.category}) : super(key: key);

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovering = false;
  
  @override
  Widget build(BuildContext context) {
    // 💡 الحصول على الألوان الديناميكية للخلفية والنص
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    final Color cardBackgroundColor = Theme.of(context).cardColor;
    
    // الألوان والأيقونات الثابتة للفئة
    final iconName = categoryIconMappings[widget.category] ?? Icons.category_rounded;
    final cardColor = categoryColorMappings[widget.category] ?? Colors.grey; 

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Container(
          height: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // 💡 التعديل: استخدام لون البطاقة الديناميكي
            color: cardBackgroundColor, 
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // ⚠️ هذا اللون يبقى ثابتًا لتحديد الفئة
                  color: cardColor, 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  iconName,
                  size: 40,
                  color: Colors.white, // لون الأيقونة داخل الدائرة يبقى أبيض
                ),
              ),
              const SizedBox(height: 10),
              // 💡 التعديل: استخدام اللون الأساسي الديناميكي للنص
              Text(
                widget.category,
                textAlign: TextAlign.center,
                style: TextStyle( // ⚠️ إزالة const
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  color: primaryColor, // سيصبح أبيض في الوضع الداكن
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// MARK: - Categories Grid Component (CategoriesGridView)
// -------------------------------------------------------------
class CategoriesGridView extends StatelessWidget {
  final List<String> categories;

  const CategoriesGridView({Key? key, required this.categories}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 💡 الحصول على اللون الأساسي للنص
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 30),
            child: Text(
              "Explore Categories",
              // 💡 التعديل: استخدام اللون الأساسي الديناميكي للنص (لحل مشكلة اللون الأسود الثابت)
              style: TextStyle( // ⚠️ إزالة const
                fontSize: 20, 
                fontWeight: FontWeight.w600,
                color: primaryColor, 
              ),
              textAlign: TextAlign.start,
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), 
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.0, 
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StoresListView(categoryName: category), 
                    ),
                  );
                },
                child: CategoryCard(category: category),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// MARK: - Brand Showcase Component (BrandShowcaseView)
// -------------------------------------------------------------
class BrandShowcaseView extends StatelessWidget {
  const BrandShowcaseView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color cardBackgroundColor = Theme.of(context).cardColor;
    
    // 1. إنشاء ويدجت الصورة الأصلية
    Widget brandImage = Image.asset(
      'assets/images/Brand.png', 
      fit: BoxFit.cover,
      height: 190,
    );

    // 2. تطبيق فلتر الألوان إذا كان الوضع داكناً
    if (brightness == Brightness.dark) {
      // 💡 ColorFilter.matrix لعكس الألوان (تحويل الأسود إلى أبيض)
      brandImage = ColorFiltered(
        // هذه المصفوفة تعكس قيم الألوان (R, G, B) مما يحول الأسود (0) إلى أبيض (255)
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255, // Red
          0, -1, 0, 0, 255, // Green
          0, 0, -1, 0, 255, // Blue
          0, 0, 0, 1, 0, // Alpha
        ]),
        child: brandImage,
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor, // لون الخلفية يتغير ديناميكياً
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: brandImage, // استخدام الصورة التي تم تطبيق الفلتر عليها
        ),
      ),
    );
  }
}