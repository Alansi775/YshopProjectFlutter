import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../widgets/store_admin_widgets.dart';
import '../../models/currency.dart';

class EditProductView extends StatefulWidget {
  final ProductS product;

  const EditProductView({super.key, required this.product});

  @override
  State<EditProductView> createState() => _EditProductViewState();
}

class _EditProductViewState extends State<EditProductView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late Currency _selectedCurrency;

  bool _isLoading = false;

  // --- Theme Colors (Modern & Minimalist) ---
  final Color _bgDark = const Color(0xFF121212);
  final Color _surfaceColor = const Color(0xFF1E1E1E);
  final Color _accentColor = const Color(0xFF2979FF);
  final Color _textPrimary = Colors.white;
  final Color _textSecondary = const Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _stockController = TextEditingController(text: widget.product.stock?.toString() ?? '1');
    _selectedCurrency = Currency.fromCode(widget.product.currency ?? 'USD') ?? Currency.getAll().first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }

      await ApiService.updateProduct(
        widget.product.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        stock: int.tryParse(_stockController.text.trim()) ?? 1,
        currency: _selectedCurrency.code,
      );

      
      if (mounted) {
        // Clear API cache to force refresh
        ApiService.clearCache();
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint("Error updating product: $e");
      _showSnack("❌ Failed to update product: ${e.toString()}", isError: true);
    } finally {
      setState(() => _isLoading = false);
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

  BoxDecoration _modernBoxDecoration() {
    return BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 18, color: _textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double _maxWidth = 600.0;

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      hintStyle: TextStyle(
        color: _textSecondary.withOpacity(0.5),
        fontWeight: FontWeight.w300,
        fontSize: 16,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Product",
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w300, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Product Name & Description ---
                  _buildSectionTitle("PRODUCT DETAILS"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                          cursorColor: _accentColor,
                          decoration: inputDecoration.copyWith(
                            hintText: "Product Name",
                          ),
                          validator: (v) => v!.isEmpty ? 'Enter product name' : null,
                        ),
                        Divider(color: _textSecondary.withOpacity(0.1), height: 1),
                        TextFormField(
                          controller: _descriptionController,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                          cursorColor: _accentColor,
                          maxLines: 3,
                          decoration: inputDecoration.copyWith(
                            hintText: "Describe your product...",
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => v!.isEmpty ? 'Enter description' : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 2. Price & Currency ---
                  _buildSectionTitle("PRICING"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Row(
                      children: [
                        // Currency Dropdown
                        Theme(
                          data: Theme.of(context).copyWith(canvasColor: _surfaceColor),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Currency>(
                              value: _selectedCurrency,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _accentColor,
                                size: 18,
                              ),
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              items: Currency.getAll().map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text("${c.code} (${c.symbol})"),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() {
                                _selectedCurrency = v!;
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          width: 1,
                          height: 30,
                          color: _textSecondary.withOpacity(0.2),
                        ),
                        const SizedBox(width: 15),
                        // Price Input
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                            ),
                            cursorColor: _accentColor,
                            decoration: inputDecoration.copyWith(
                              hintText: "0.00",
                            ),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Enter price';
                              if (double.tryParse(v!) == null) return 'Invalid price';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 3. Inventory (Stock Counter) ---
                  _buildSectionTitle("INVENTORY"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _modernBoxDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Stock Available",
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _textSecondary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildIconButton(Icons.remove, () {
                                int val = int.tryParse(_stockController.text) ?? 1;
                                if (val > 1) {
                                  _stockController.text = (val - 1).toString();
                                }
                              }),
                              SizedBox(
                                width: 40,
                                child: TextFormField(
                                  controller: _stockController,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  validator: (value) {
                                    if (value!.isEmpty) return 'Required';
                                    final stock = int.tryParse(value);
                                    if (stock == null || stock < 1) return 'Min 1';
                                    return null;
                                  },
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

                  const SizedBox(height: 40),

                  // --- Submit Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : const Text(
                              "Save Changes",
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
}
