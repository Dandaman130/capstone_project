/*
  UserPreferencesService
  Persists dietary restrictions + disliked/avoided ingredients locally
  using SharedPreferences.

  Keys stored:
    pref_vegan            bool
    pref_vegetarian       bool
    pref_gluten_free      bool
    pref_dairy_free       bool
    pref_nut_free         bool
    pref_pescatarian      bool
    pref_show_unknown     bool   – whether to show products with unknown flags
    pref_avoided_keywords List<String>  – user-defined ingredient keywords to avoid
    pref_disliked_barcodes List<String> – barcodes the user has explicitly hidden
*/

import 'package:shared_preferences/shared_preferences.dart';

class DietaryRestrictions {
  final bool vegan;
  final bool vegetarian;
  final bool glutenFree;
  final bool dairyFree;
  final bool nutFree;
  final bool pescatarian;
  final bool showUnknownProducts;

  const DietaryRestrictions({
    this.vegan = false,
    this.vegetarian = false,
    this.glutenFree = false,
    this.dairyFree = false,
    this.nutFree = false,
    this.pescatarian = false,
    this.showUnknownProducts = true,
  });

  DietaryRestrictions copyWith({
    bool? vegan,
    bool? vegetarian,
    bool? glutenFree,
    bool? dairyFree,
    bool? nutFree,
    bool? pescatarian,
    bool? showUnknownProducts,
  }) {
    return DietaryRestrictions(
      vegan: vegan ?? this.vegan,
      vegetarian: vegetarian ?? this.vegetarian,
      glutenFree: glutenFree ?? this.glutenFree,
      dairyFree: dairyFree ?? this.dairyFree,
      nutFree: nutFree ?? this.nutFree,
      pescatarian: pescatarian ?? this.pescatarian,
      showUnknownProducts: showUnknownProducts ?? this.showUnknownProducts,
    );
  }

  /// Returns true when no restrictions are set at all.
  bool get isEmpty =>
      !vegan &&
          !vegetarian &&
          !glutenFree &&
          !dairyFree &&
          !nutFree &&
          !pescatarian;

  /// Human-readable list of active restrictions.
  List<String> get activeLabels {
    final labels = <String>[];
    if (vegan) labels.add('Vegan');
    if (vegetarian) labels.add('Vegetarian');
    if (glutenFree) labels.add('Gluten-Free');
    if (dairyFree) labels.add('Dairy-Free');
    if (nutFree) labels.add('Nut-Free');
    if (pescatarian) labels.add('Pescatarian');
    return labels;
  }
}

class UserPreferencesService {
  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const String _keyVegan             = 'pref_vegan';
  static const String _keyVegetarian        = 'pref_vegetarian';
  static const String _keyGlutenFree        = 'pref_gluten_free';
  static const String _keyDairyFree         = 'pref_dairy_free';
  static const String _keyNutFree           = 'pref_nut_free';
  static const String _keyPescatarian       = 'pref_pescatarian';
  static const String _keyShowUnknown       = 'pref_show_unknown';
  static const String _keyAvoidedKeywords   = 'pref_avoided_keywords';
  static const String _keyDislikedBarcodes  = 'pref_disliked_barcodes';

  // ── Load ────────────────────────────────────────────────────────────────────

  /// Loads the full [DietaryRestrictions] object from local storage.
  static Future<DietaryRestrictions> loadRestrictions() async {
    final prefs = await SharedPreferences.getInstance();
    return DietaryRestrictions(
      vegan:               prefs.getBool(_keyVegan)        ?? false,
      vegetarian:          prefs.getBool(_keyVegetarian)   ?? false,
      glutenFree:          prefs.getBool(_keyGlutenFree)   ?? false,
      dairyFree:           prefs.getBool(_keyDairyFree)    ?? false,
      nutFree:             prefs.getBool(_keyNutFree)       ?? false,
      pescatarian:         prefs.getBool(_keyPescatarian)  ?? false,
      showUnknownProducts: prefs.getBool(_keyShowUnknown)  ?? true,
    );
  }

  /// Returns the list of ingredient keywords the user wants to avoid.
  static Future<List<String>> loadAvoidedKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyAvoidedKeywords) ?? [];
  }

  /// Returns the set of barcodes the user has manually hidden.
  static Future<Set<String>> loadDislikedBarcodes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_keyDislikedBarcodes) ?? []).toSet();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Persists the full [DietaryRestrictions] object.
  static Future<void> saveRestrictions(DietaryRestrictions r) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyVegan,       r.vegan),
      prefs.setBool(_keyVegetarian,  r.vegetarian),
      prefs.setBool(_keyGlutenFree,  r.glutenFree),
      prefs.setBool(_keyDairyFree,   r.dairyFree),
      prefs.setBool(_keyNutFree,     r.nutFree),
      prefs.setBool(_keyPescatarian, r.pescatarian),
      prefs.setBool(_keyShowUnknown, r.showUnknownProducts),
    ]);
  }

  /// Replaces the avoided-keywords list.
  static Future<void> saveAvoidedKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    // Normalise: lowercase + trim, remove duplicates/blanks
    final cleaned = keywords
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    await prefs.setStringList(_keyAvoidedKeywords, cleaned);
  }

  /// Adds a single keyword to the avoided list.
  static Future<void> addAvoidedKeyword(String keyword) async {
    final current = await loadAvoidedKeywords();
    final normalised = keyword.trim().toLowerCase();
    if (normalised.isEmpty || current.contains(normalised)) return;
    await saveAvoidedKeywords([...current, normalised]);
  }

  /// Removes a single keyword from the avoided list.
  static Future<void> removeAvoidedKeyword(String keyword) async {
    final current = await loadAvoidedKeywords();
    await saveAvoidedKeywords(
      current.where((k) => k != keyword.trim().toLowerCase()).toList(),
    );
  }

  /// Adds a barcode to the disliked / hidden list.
  static Future<void> dislikeProduct(String barcode) async {
    final current = await loadDislikedBarcodes();
    if (current.contains(barcode)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDislikedBarcodes, [...current, barcode]);
  }

  /// Removes a barcode from the disliked list (un-hide).
  static Future<void> undislikeProduct(String barcode) async {
    final current = await loadDislikedBarcodes();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyDislikedBarcodes,
      current.where((b) => b != barcode).toList(),
    );
  }

  // ── Clear ───────────────────────────────────────────────────────────────────

  /// Wipes all preference data (useful for account reset / logout).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyVegan),
      prefs.remove(_keyVegetarian),
      prefs.remove(_keyGlutenFree),
      prefs.remove(_keyDairyFree),
      prefs.remove(_keyNutFree),
      prefs.remove(_keyPescatarian),
      prefs.remove(_keyShowUnknown),
      prefs.remove(_keyAvoidedKeywords),
      prefs.remove(_keyDislikedBarcodes),
    ]);
  }
}