import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_entry.dart';

class BarcodeCache {
  static const String _cacheKey = 'barcode_cache';
  static const Duration _cacheDuration = Duration(days: 7); // Cache for 7 days

  static Future<Product?> get(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKey);

    if (cacheJson == null) return null;

    final cache = Map<String, dynamic>.from(jsonDecode(cacheJson));
    final entry = cache[barcode];

    if (entry == null) return null;

    // Check if cache entry is expired
    final timestamp = DateTime.fromMillisecondsSinceEpoch(entry['timestamp'] as int);
    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      // Expired - remove it
      await remove(barcode);
      return null;
    }

    // Return cached product
    final productData = entry['product'] as Map<String, dynamic>;
    return Product(
      id: productData['id'] as String,
      name: productData['name'] as String,
      brand: productData['brand'] as String,
      category: productData['category'] as String,
    );
  }

  static Future<void> set(String barcode, Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKey);

    final cache = cacheJson != null ? Map<String, dynamic>.from(jsonDecode(cacheJson)) : <String, dynamic>{};

    cache[barcode] = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'product': {'id': product.id, 'name': product.name, 'brand': product.brand, 'category': product.category},
    };

    // Limit cache size (keep last 100 entries)
    if (cache.length > 100) {
      final sortedKeys = cache.keys.toList()
        ..sort((a, b) {
          final aTime = cache[a]['timestamp'] as int;
          final bTime = cache[b]['timestamp'] as int;
          return aTime.compareTo(bTime);
        });

      // Remove oldest entries
      for (int i = 0; i < cache.length - 100; i++) {
        cache.remove(sortedKeys[i]);
      }
    }

    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  static Future<void> remove(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKey);

    if (cacheJson == null) return;

    final cache = Map<String, dynamic>.from(jsonDecode(cacheJson));
    cache.remove(barcode);

    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
