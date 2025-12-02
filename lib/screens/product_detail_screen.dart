import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/scanned_product.dart';
import '../services/openfoodfacts_api.dart';
import '../services/scanned_product_cache.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? railwayProduct;
  final ScannedProduct? scannedProduct;

  const ProductDetailScreen({
    Key? key,
    this.railwayProduct,
    this.scannedProduct,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  ScannedProduct? _productDetails;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String barcode;

      // Get barcode from either Railway product or scanned product
      if (widget.railwayProduct != null) {
        barcode = widget.railwayProduct!.barcode;
      } else if (widget.scannedProduct != null) {
        barcode = widget.scannedProduct!.barcode;
        // If we already have scanned product, just display it
        setState(() {
          _productDetails = widget.scannedProduct;
          _isLoading = false;
        });
        return;
      } else {
        setState(() {
          _errorMessage = 'No product information available';
          _isLoading = false;
        });
        return;
      }

      print('Looking up barcode: $barcode (like a barcode scan)');

      // Act like a barcode scan - fetch from OpenFoodFacts API
      final api = OpenFoodFactsApi();
      final productData = await api.fetchProduct(barcode);

      // Convert to ScannedProduct (same as Screen1 does)
      final scannedProduct = ScannedProduct.fromJson(barcode, productData);

      // Cache it (same as Screen1 does)
      ScannedProductCache.addProduct(scannedProduct);

      setState(() {
        _productDetails = scannedProduct;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading product: $e');
      setState(() {
        _errorMessage = 'Product not found in OpenFoodFacts database';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProductDetails,
            tooltip: 'Refresh from OpenFoodFacts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildProductDetails(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProductDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails() {
    if (_productDetails == null) {
      return const Center(child: Text('No product data'));
    }

    final product = _productDetails!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image from OpenFoodFacts
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.grey[200],
              child: Image.network(
                product.imageUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return _buildPlaceholderImage();
                },
              ),
            )
          else
            _buildPlaceholderImage(),

          // Product Information
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Brand
                Row(
                  children: [
                    Icon(Icons.business, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.brand,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Info Cards Row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Quantity',
                        product.quantity,
                        Icons.scale,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        'Nutri-Score',
                        product.nutriScore,
                        Icons.analytics,
                        color: _getNutriScoreColor(product.nutriScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Barcode
                _buildInfoCard(
                  'Barcode',
                  product.barcode,
                  Icons.qr_code,
                ),
                const SizedBox(height: 24),

                // Ingredients Section
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    product.ingredients,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Data Source Indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Information from OpenFoodFacts database',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No image available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.1) ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color?.withValues(alpha: 0.3) ?? Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color ?? Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNutriScoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A':
        return Colors.green[700]!;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.yellow[700]!;
      case 'D':
        return Colors.orange;
      case 'E':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

