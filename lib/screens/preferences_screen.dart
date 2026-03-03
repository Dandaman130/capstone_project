/*
  PreferencesScreen
  Lets the user configure dietary restrictions and personal ingredient preferences.
  Changes are persisted immediately via UserPreferencesService (SharedPreferences).
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/preferences_provider.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_colors.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _addKeyword() {
    final word = _keywordController.text.trim();
    if (word.isEmpty) return;
    ref.read(avoidedKeywordsProvider.notifier).add(word);
    _keywordController.clear();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Preferences'),
        content: const Text(
          'This will clear all dietary restrictions, avoided keywords, '
              'and hidden products. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await UserPreferencesService.clearAll();
      ref.invalidate(restrictionsProvider);
      ref.invalidate(avoidedKeywordsProvider);
      ref.invalidate(dislikedBarcodesProvider);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final restAsync     = ref.watch(restrictionsProvider);
    final keywordsAsync = ref.watch(avoidedKeywordsProvider);
    final dislikedAsync = ref.watch(dislikedBarcodesProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('My Preferences',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset all preferences',
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: restAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (restrictions) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Dietary restrictions ────────────────────────────────────────
            _SectionHeader(title: 'Dietary Restrictions'),
            const SizedBox(height: 8),
            _RestrictionCard(
              children: [
                _RestrictionTile(
                  icon: '🌱',
                  label: 'Vegan',
                  subtitle: 'No animal products',
                  value: restrictions.vegan,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(vegan: v),
                ),
                _RestrictionTile(
                  icon: '🥦',
                  label: 'Vegetarian',
                  subtitle: 'No meat or fish',
                  value: restrictions.vegetarian,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(vegetarian: v),
                ),
                _RestrictionTile(
                  icon: '🐟',
                  label: 'Pescatarian',
                  subtitle: 'Vegetarian + seafood OK',
                  value: restrictions.pescatarian,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(pescatarian: v),
                ),
                _RestrictionTile(
                  icon: '🌾',
                  label: 'Gluten-Free',
                  subtitle: 'No wheat, barley, rye…',
                  value: restrictions.glutenFree,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(glutenFree: v),
                ),
                _RestrictionTile(
                  icon: '🥛',
                  label: 'Dairy-Free',
                  subtitle: 'No milk, cheese, butter…',
                  value: restrictions.dairyFree,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(dairyFree: v),
                ),
                _RestrictionTile(
                  icon: '🥜',
                  label: 'Nut-Free',
                  subtitle: 'No tree nuts or peanuts',
                  value: restrictions.nutFree,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(nutFree: v),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Unknown-status toggle ───────────────────────────────────────
            _SectionHeader(title: 'Filter Strictness'),
            const SizedBox(height: 8),
            _RestrictionCard(
              children: [
                _RestrictionTile(
                  icon: '❓',
                  label: 'Show products with unknown status',
                  subtitle:
                  'When off, products missing dietary info are hidden',
                  value: restrictions.showUnknownProducts,
                  onChanged: (v) => ref
                      .read(restrictionsProvider.notifier)
                      .toggle(showUnknown: v),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Avoided keywords ────────────────────────────────────────────
            _SectionHeader(title: 'Avoided Ingredients'),
            const SizedBox(height: 4),
            Text(
              'Products containing any of these words in their ingredients '
                  'will be hidden.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: InputDecoration(
                      hintText: 'e.g. palm oil, msg, aspartame',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _addKeyword(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addKeyword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            keywordsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (keywords) => keywords.isEmpty
                  ? Text(
                'No avoided ingredients yet.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              )
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords
                    .map(
                      (kw) => Chip(
                    label: Text(kw),
                    backgroundColor: Colors.red[50],
                    side: BorderSide(color: Colors.red[200]!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => ref
                        .read(avoidedKeywordsProvider.notifier)
                        .remove(kw),
                  ),
                )
                    .toList(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Hidden products ─────────────────────────────────────────────
            _SectionHeader(title: 'Hidden Products'),
            const SizedBox(height: 4),
            Text(
              'Products you\'ve manually hidden from your feed.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            dislikedAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (barcodes) => barcodes.isEmpty
                  ? Text(
                'No hidden products.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              )
                  : Column(
                children: barcodes
                    .map(
                      (bc) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_off,
                        color: Colors.grey),
                    title: Text(bc,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13)),
                    trailing: TextButton(
                      onPressed: () => ref
                          .read(dislikedBarcodesProvider.notifier)
                          .undislike(bc),
                      child: const Text('Unhide'),
                    ),
                  ),
                )
                    .toList(),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class _RestrictionCard extends StatelessWidget {
  final List<Widget> children;
  const _RestrictionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Column(children: children),
    );
  }
}

class _RestrictionTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RestrictionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.sageGreen,
    );
  }
}