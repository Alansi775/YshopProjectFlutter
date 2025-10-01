// lib/widgets/category_widgets.dart (الكود المصحح)

import 'package:flutter/material.dart';
import '../screens/stores_list_view.dart'; 
import '../widgets/custom_form_widgets.dart'; 

// -------------------------------------------------------------
// MARK: - Category Mappings 
// -------------------------------------------------------------
const Map<String, IconData> categoryIconMappings = {
  "Food": Icons.restaurant_menu_rounded,
  "Pharmacy": Icons.local_hospital_rounded,
  "Clothes": Icons.checkroom_rounded,
  "Market": Icons.shopping_basket_rounded,
  "Restaurants": Icons.restaurant_rounded,
};

const Map<String, Color> categoryColorMappings = {
  "Food": Color.fromRGBO(232, 181, 130, 1.0), 
  "Pharmacy": Color.fromRGBO(143, 201, 250, 1.0), 
  "Clothes": Color.fromRGBO(209, 158, 232, 1.0), 
  "Market": Color.fromRGBO(168, 222, 168, 1.0), 
  "Restaurants": Color.fromRGBO(250, 153, 153, 1.0),
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
  // الحالة لتطبيق تأثير onHover
  bool _isHovering = false;
  
  // لافتراض وجود المتغير primaryText في custom_form_widgets.dart
  // وإلا استخدم Colors.black
  final Color primaryText = Colors.black; 

  @override
  Widget build(BuildContext context) {
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
            color: Colors.white, 
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.category,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  color: primaryText, 
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
    // لافتراض وجود المتغير primaryText في custom_form_widgets.dart
    // وإلا استخدم Colors.black
    final Color primaryText = Colors.black;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // جعل النص يبدأ من اليسار
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 30),
            child: Text(
              "Explore Categories",
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w600,
                color: primaryText,
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
                      // استخدام الكلاس الكامل والمستورد
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
    // تأكد من أن 'assets/images/Brand.png' موجود في مشروعك
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
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
          child: Image.asset(
            'assets/images/Brand.png', 
            fit: BoxFit.cover,
            height: 190,
          ),
        ),
      ),
    );
  }
}