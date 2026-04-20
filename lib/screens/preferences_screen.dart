/*
  PreferencesScreen - Botanical Refactor
  Configures dietary restrictions and personal ingredient preferences.
  Applied hardcoded vine background and transparent Scaffold.
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
        backgroundColor: AppColors.forestMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset All?', style: TextStyle(color: AppColors.parchment)),
        content: const Text(
          'This will clear your dietary restrictions, keywords, and hidden products.',
          style: TextStyle(color: AppColors.mistGreen),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mistGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
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

  @override
  Widget build(BuildContext context) {
    final restAsync = ref.watch(restrictionsProvider);
    final keywordsAsync = ref.watch(avoidedKeywordsProvider);

    return Scaffold(
      // 🌿 Setting background transparent to reveal the Container's decoration
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Preferences',
            style: TextStyle(color: AppColors.parchment, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 🌿 Hardcoded Botanical Decoration
        decoration: const BoxDecoration(
          color: AppColors.forestDeep,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            repeat: ImageRepeat.repeat,
            scale: 1.8,
            opacity: 0.18,
          ),
        ),
        child: SafeArea(
          child: restAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.agedGold)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            data: (restrictions) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _SectionHeader(title: 'Dietary Restrictions'),
                const SizedBox(height: 12),
                _RestrictionContainer(
                  children: [
                    _RestrictionTile(
                      icon: '🌱',
                      label: 'Vegan',
                      value: restrictions.vegan,
                      onChanged: (v) => ref.read(restrictionsProvider.notifier).toggle(vegan: v),
                    ),
                    _RestrictionTile(
                      icon: '🥦',
                      label: 'Vegetarian',
                      value: restrictions.vegetarian,
                      onChanged: (v) => ref.read(restrictionsProvider.notifier).toggle(vegetarian: v),
                    ),
                    _RestrictionTile(
                      icon: '🌾',
                      label: 'Gluten-Free',
                      value: restrictions.glutenFree,
                      onChanged: (v) => ref.read(restrictionsProvider.notifier).toggle(glutenFree: v),
                    ),
                    _RestrictionTile(
                      icon: '🥛',
                      label: 'Dairy-Free',
                      value: restrictions.dairyFree,
                      onChanged: (v) => ref.read(restrictionsProvider.notifier).toggle(dairyFree: v),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const _SectionHeader(title: 'Avoided Ingredients'),
                const SizedBox(height: 8),
                const Text(
                  'Hide products containing specific keywords:',
                  style: TextStyle(color: AppColors.mistGreen, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildKeywordInput(),
                const SizedBox(height: 16),
                _buildKeywordChips(keywordsAsync),

                const SizedBox(height: 32),
                const _SectionHeader(title: 'Strictness'),
                _RestrictionContainer(
                  children: [
                    _RestrictionTile(
                      icon: '❓',
                      label: 'Show Unknown Status',
                      value: restrictions.showUnknownProducts,
                      onChanged: (v) => ref.read(restrictionsProvider.notifier).toggle(showUnknown: v),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeywordInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keywordController,
            style: const TextStyle(color: AppColors.parchment),
            decoration: InputDecoration(
              hintText: 'e.g. Palm Oil',
              hintStyle: TextStyle(color: AppColors.mossGreen.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.forestMid.withOpacity(0.4),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.mossGreen.withOpacity(0.2))
              ),
            ),
            onSubmitted: (_) => _addKeyword(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _addKeyword,
          style: IconButton.styleFrom(backgroundColor: AppColors.agedGold),
          icon: const Icon(Icons.add, color: AppColors.forestDeep),
        ),
      ],
    );
  }

  Widget _buildKeywordChips(AsyncValue<List<String>> keywordsAsync) {
    return keywordsAsync.when(
      data: (keywords) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: keywords.map((kw) => Chip(
          label: Text(kw, style: const TextStyle(color: AppColors.parchment, fontSize: 12)),
          backgroundColor: AppColors.mossGreen.withOpacity(0.3),
          side: BorderSide(color: AppColors.mossGreen.withOpacity(0.5)),
          deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.agedGold),
          onDeleted: () => ref.read(avoidedKeywordsProvider.notifier).remove(kw),
        )).toList(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Components ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.agedGold,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _RestrictionContainer extends StatelessWidget {
  final List<Widget> children;
  const _RestrictionContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.forestMid.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mossGreen.withOpacity(0.2)),
      ),
      child: Column(children: children),
    );
  }
}

class _RestrictionTile extends StatelessWidget {
  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RestrictionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Text(icon, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: const TextStyle(color: AppColors.parchment, fontSize: 15)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.agedGold,
      activeTrackColor: AppColors.mossGreen,
      inactiveTrackColor: AppColors.forestDeep.withOpacity(0.5),
    );
  }
}