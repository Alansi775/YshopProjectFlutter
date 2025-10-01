import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/store_admin_widgets.dart'; // لاستخدام ProductS

class ProductDetailsView extends StatelessWidget {
  final ProductS product;
  
  const ProductDetailsView({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    //  نستخدم عرضًا أقصى لجعل الشاشة تبدو جيدة على الويب
    const double maxWidth = 700.0;
    
    //  لون الحالة
    Color statusColor = product.approved ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // 1. عرض الصورة الرئيسية
                _buildProductImage(context),
                const SizedBox(height: 32),

                // 2. حالة المنتج (Approved/Pending)
                Row(
                  children: [
                    const Text(
                      "Status: ",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        product.status,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: statusColor,
                    ),
                    const Spacer(),
                    // يمكنك هنا إضافة زر "Edit" أو "Delete" لاحقًا
                  ],
                ),
                const Divider(height: 32),

                // 3. التفاصيل الأساسية (الاسم والسعر)
                _buildDetailRow(
                  context, 
                  label: "Product Name:", 
                  value: product.name, 
                  isTitle: true,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context, 
                  label: "Price:", 
                  value: "\$${product.price}", 
                  isPrice: true,
                ),
                const Divider(height: 32),

                // 4. الوصف
                Text(
                  "Description:",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Divider(height: 32),

                // 5. بيانات المتجر الداخلية
                Text(
                  "Store Metadata:",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(context, label: "Owner Email:", value: product.storeOwnerEmail),
                _buildDetailRow(context, label: "Store Name:", value: product.storeName),
                _buildDetailRow(context, label: "Store Phone:", value: product.storePhone),
                _buildDetailRow(context, label: "Product ID:", value: product.id, isID: true),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MARK: - Widgets Helpers

  Widget _buildProductImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: product.imageUrl,
        width: double.infinity,
        height: 300, // ارتفاع ثابت
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 300,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 300,
          color: Colors.red.withOpacity(0.1),
          child: const Center(child: Icon(Icons.error, color: Colors.red, size: 50)),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isTitle = false,
    bool isPrice = false,
    bool isID = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // عرض ثابت للتسمية
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
                color: isPrice ? Colors.blue.shade700 : (isID ? Colors.grey.shade600 : Colors.black87),
                fontSize: isTitle ? 24 : null, // حجم أكبر لاسم المنتج
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}