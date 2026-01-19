import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/multi_media_picker.dart';
import '../../models/currency.dart';

class AddProductView extends StatefulWidget {
  const AddProductView({super.key});

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController(text: '1');

  List<MediaItem> _selectedMedia = [];
  bool _isLoading = false;
  Currency _selectedCurrency = Currency.currencies[1] ?? Currency.getAll().first;

  // --- Theme Colors (Modern & Minimalist) ---
  final Color _bgDark = const Color(0xFF121212); // خلفية أصلية
  final Color _surfaceColor = const Color(0xFF1E1E1E); // لون الكروت
  final Color _accentColor = const Color(0xFF2979FF); // أزرق كهربائي عصري (بديل البنفسجي)
  final Color _textPrimary = Colors.white;
  final Color _textSecondary = const Color(0xFF9E9E9E);

  // --- Logic (Same as before) ---
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _selectedMedia.isEmpty) {
      _showSnack("Please fill required fields & add an image", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final storeResponse = await ApiService.getUserStore(uid: user.uid);
      final storeId = storeResponse?['id'] ?? 1;

      final productData = {
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "price": double.tryParse(_priceController.text.trim()) ?? 0.0,
        "stock": int.tryParse(_stockController.text.trim()) ?? 1,
        "storeId": storeId,
        "currencyId": _selectedCurrency.id,
        "currencyCode": _selectedCurrency.code,
      };

      final firstImageMedia = _selectedMedia.firstWhere((m) => !m.isVideo);
      final imageFile = kIsWeb ? firstImageMedia.fileNative : firstImageMedia.fileWeb;
      
      await ApiService.createProductWithImage(productData, imageFile as dynamic);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) _showSnack("Error: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : _accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Custom Input Style
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.transparent, // Glass effect
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontWeight: FontWeight.w300, fontSize: 16),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );

    return Scaffold(
      backgroundColor: _bgDark,
      // Minimal App Bar
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create Product",
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w300, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- 1. Product Name (SwiftUI Style) ---
                  _buildSectionTitle("PRODUCT DETAILS"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w400),
                          cursorColor: _accentColor,
                          decoration: inputDecoration.copyWith(
                            hintText: "Product Name",
                            labelText: "Name",
                            labelStyle: TextStyle(color: _textSecondary),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        Divider(color: _textSecondary.withOpacity(0.1), height: 1),
                        TextFormField(
                          controller: _descriptionController,
                          style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w300),
                          cursorColor: _accentColor,
                          maxLines: 3,
                          decoration: inputDecoration.copyWith(
                            hintText: "Describe your product...",
                            labelText: "Description",
                            labelStyle: TextStyle(color: _textSecondary),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 2. Price & Currency (Clean Row) ---
                  _buildSectionTitle("PRICING"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Row(
                      children: [
                        // Currency "Pill" - Minimalist
                        Theme(
                          data: Theme.of(context).copyWith(canvasColor: _surfaceColor),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Currency>(
                              value: _selectedCurrency,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: _accentColor, size: 18),
                              style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                              items: Currency.getAll().map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text("${c.code} (${c.symbol})"),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedCurrency = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(width: 1, height: 30, color: _textSecondary.withOpacity(0.2)),
                        const SizedBox(width: 15),
                        // Price Input
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w300),
                            cursorColor: _accentColor,
                            decoration: inputDecoration.copyWith(
                              hintText: "0.00",
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 3. Inventory (Modern Counter) ---
                  _buildSectionTitle("INVENTORY"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Stock Available", 
                          style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w400)),
                        
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _textSecondary.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              _buildIconButton(Icons.remove, () {
                                int val = int.tryParse(_stockController.text) ?? 1;
                                if (val > 1) _stockController.text = (val - 1).toString();
                              }),
                              SizedBox(
                                width: 40,
                                child: TextFormField(
                                  controller: _stockController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                ),
                              ),
                              _buildIconButton(Icons.add, () {
                                int val = int.tryParse(_stockController.text) ?? 0;
                                _stockController.text = (val + 1).toString();
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 4. Media (Clean Grid) ---
                  _buildSectionTitle("MEDIA"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.all(20),
                    child: MultiMediaPicker(
                      onMediaSelected: (media) => setState(() => _selectedMedia = media),
                      maxImages: 4,
                      allowVideo: true,
                      maxVideoDurationSeconds: 40,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Submit Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Publish Product",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  // Stylish small header (SwiftUI List Section style)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: _textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // The modern "Glass/Card" effect
  BoxDecoration _modernBoxDecoration() {
    return BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      // Very subtle border to define edges without looking "boxy"
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 18, color: _textPrimary),
      ),
    );
  }
}