// lib/screens/category_sheet_view.dart

import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';

class CategorySheetView extends StatefulWidget {
  final int storeId;
  final List<Category> existingCategories;
  final String storeType;

  const CategorySheetView({
    Key? key,
    required this.storeId,
    required this.existingCategories,
    required this.storeType,
  }) : super(key: key);

  @override
  State<CategorySheetView> createState() => _CategorySheetViewState();
}

class _CategorySheetViewState extends State<CategorySheetView> {
  late List<Map<String, String>> availableCategories;
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    availableCategories =
        CategoryTemplates.getAvailableCategories(widget.existingCategories, widget.storeType);
  }

  void _filterCategories(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  Future<void> _createCategory(Map<String, String> category) async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createCategory(
        widget.storeId,
        category['name']!,
      );

      if (result != null && mounted) {
        Navigator.pop(context, Category.fromJson(result));
      }
    } catch (e) {
      debugPrint('Error creating category: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? availableCategories
        : availableCategories
            .where((cat) =>
                cat['displayName']!.toLowerCase().contains(_searchQuery) ||
                cat['name']!.toLowerCase().contains(_searchQuery))
            .toList();

    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: TextField(
                    onChanged: _filterCategories,
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Categories list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No categories available'
                          : 'No categories found',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final category = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: ListTile(
                            title: Text(
                              category['displayName']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              category['name']!,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            trailing: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.blue[400],
                                  ),
                            onTap: _isLoading
                                ? null
                                : () => _createCategory(category),
                            hoverColor:
                                Colors.white.withOpacity(0.05),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
