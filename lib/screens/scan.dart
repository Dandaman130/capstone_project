/*
  ScanScreen - Botanical Refactor
  Functionality: Barcode scanning with rate limiting.
  Theme: Forest Deep / Aged Gold / Vine Background.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/product_provider.dart';
import '../models/scanned_product.dart';
import '../services/scanned_product_cache.dart';
import '../services/rate_limiter_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  String? _barcode;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller.barcodes.listen((barcodeCapture) {
      if (_hasScanned) return;

      for (final barcode in barcodeCapture.barcodes) {
        final String? code = barcode.rawValue;
        if (code != null) {
          if (!RateLimiterService.canMakeCall(RateLimitType.barcodeScan)) {
            _showRateLimitSnackBar();
            setState(() {
              _hasScanned = true;
              _controller.stop();
            });
            return;
          }

          setState(() {
            _barcode = code;
            _hasScanned = true;
            _controller.stop();
          });
          break;
        }
      }
    });
  }

  void _showRateLimitSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rate limit exceeded. Please wait.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScannedProduct? cachedProduct;
    if (_barcode != null) {
      cachedProduct = ScannedProductCache.getByBarcode(_barcode!);
      if (cachedProduct == null) {
        RateLimiterService.recordCall(RateLimitType.barcodeScan);
      }
    }

    final productAsync = (_barcode != null && cachedProduct == null)
        ? ref.watch(productProvider(_barcode!))
        : null;

    final remainingScans = RateLimiterService.getRemainingCalls(RateLimitType.barcodeScan);

    return Scaffold(
      backgroundColor: AppColors.forestDeep,
      appBar: AppBar(
        title: const Text('Scan Product', style: TextStyle(color: AppColors.parchment)),
        backgroundColor: AppColors.forestDeep,
        elevation: 0,
        actions: [_buildRateLimitBadge(remainingScans)],
      ),
      body: Container(
        decoration: AppTheme.vineBackground,
        child: Column(
          children: [
            if (!_hasScanned)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.agedGold.withOpacity(0.5), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: MobileScanner(controller: _controller),
                  ),
                ),
              ),
            if (_barcode != null)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: cachedProduct != null
                      ? _buildProductDetails(cachedProduct)
                      : productAsync!.when(
                    data: (product) {
                      final scanned = ScannedProduct.fromJson(_barcode!, product);
                      ScannedProductCache.addProduct(scanned);
                      return _buildProductDetails(scanned);
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.agedGold)),
                    error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateLimitBadge(int remaining) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: remaining <= 3 ? Colors.redAccent.withOpacity(0.8) : AppColors.forestMid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.mossGreen.withOpacity(0.3)),
          ),
          child: Text(
            '$remaining/15',
            style: const TextStyle(color: AppColors.agedGold, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails(ScannedProduct scanned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Scanned Result
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.forestMid.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.mossGreen.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scanned.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.parchment)),
              const SizedBox(height: 4),
              Text(scanned.brand, style: const TextStyle(color: AppColors.agedGold, fontSize: 14)),
              const Divider(color: AppColors.mossGreen, height: 24),
              _buildInfoRow('Nutri-Score', scanned.nutriScore),
              _buildInfoRow('Quantity', scanned.quantity),
              const SizedBox(height: 12),
              Text('Ingredients:', style: TextStyle(color: AppColors.parchment.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
              Text(scanned.ingredients, style: const TextStyle(color: AppColors.mistGreen, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Scan Again Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan Next Item'),
            onPressed: () {
              setState(() {
                _barcode = null;
                _hasScanned = false;
                _controller.start();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.agedGold,
              foregroundColor: AppColors.forestDeep,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 32),
        const Text('Recent History', style: TextStyle(color: AppColors.agedGold, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),

        // History List
        ...ScannedProductCache.all.reversed.map((p) => _buildHistoryCard(p)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppColors.mistGreen, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.parchment, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ScannedProduct p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.forestMid.withOpacity(0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.mossGreen.withOpacity(0.1)),
      ),
      child: ListTile(
        title: Text(p.name, style: const TextStyle(color: AppColors.parchment, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('${p.brand} • Score: ${p.nutriScore}', style: const TextStyle(color: AppColors.mistGreen, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mossGreen),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}