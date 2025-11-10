import 'package:flutter/material.dart';
import '../models/scanned_product.dart';
import '../services/product_cache_service.dart';

class ProductDetailsWidget extends StatelessWidget {
  final ScannedProduct product;
  final VoidCallback onScanAgain;

  const ProductDetailsWidget({
    Key? key,
    required this.product,
    required this.onScanAgain,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get all cached products from Hive
    final cachedProducts = ProductCacheService.getAllCached();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product header
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Brand', product.brand),
                  _buildInfoRow('Quantity', product.quantity),
                  _buildInfoRow('Nutri-Score', product.nutriScore),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingredients:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.ingredients,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Scan again button
          Center(
            child: ElevatedButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Another Product'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Cached products history from Hive
          if (cachedProducts.isNotEmpty) ...[
            Text(
              'Cached Products (${cachedProducts.length}):',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...cachedProducts.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getNutriScoreColor(p.nutriScore),
                  child: Text(
                    p.nutriScore.isNotEmpty ? p.nutriScore.toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${p.brand} • ${p.quantity}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Could navigate to detailed product view
                },
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getNutriScoreColor(String nutriScore) {
    switch (nutriScore.toLowerCase()) {
      case 'a':
        return Colors.green;
      case 'b':
        return Colors.lightGreen;
      case 'c':
        return Colors.yellow[700]!;
      case 'd':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
