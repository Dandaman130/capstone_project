/*
Current State 9/24/25 Last Modified v(beta 1.0)Runs the opefoodfacts_api in Services directory to fetch products

Things to Consider
None should be finalized
*/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/openfoodfacts_api.dart';

final productProvider = FutureProvider.family((ref, String barcode) async {
  final api = OpenFoodFactsApi();
  return await api.fetchProduct(barcode);
});