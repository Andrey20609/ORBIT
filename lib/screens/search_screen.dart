import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/database/memory_orbit_database.dart';
import '../data/database/orbit_data_engine.dart';
import '../services/search/search_models.dart';
import '../services/search/unified_search_service.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

final class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

final class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final UnifiedSearchService _searchService;
  List<SearchResultItem> _results = [];
  SearchCategory? _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default shared or memory instance
    final engine = OrbitDataEngine(MemoryOrbitDatabase(autoSeed: true));
    _searchService = UnifiedSearchService(engine);
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await _searchService.search(
        query,
        category: _selectedCategory ?? SearchCategory.all,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconForCategory(SearchCategory category) {
    return switch (category) {
      SearchCategory.all => Icons.search_rounded,
      SearchCategory.email => Icons.mail_outline_rounded,
      SearchCategory.event => Icons.calendar_today_rounded,
      SearchCategory.task => Icons.check_circle_outline_rounded,
      SearchCategory.note => Icons.edit_note_rounded,
      SearchCategory.contact => Icons.person_outline_rounded,
    };
  }

  Color _colorForCategory(SearchCategory category, OrbitPalette palette) {
    return switch (category) {
      SearchCategory.all => palette.accent,
      SearchCategory.email => const Color(0xFF82B9FF),
      SearchCategory.event => const Color(0xFFFFB366),
      SearchCategory.task => const Color(0xFF52D093),
      SearchCategory.note => const Color(0xFFFFA066),
      SearchCategory.contact => palette.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;

    return OrbitPage(
      title: 'Единый поиск',
      subtitle: 'Почта, встречи, задачи, заметки, контакты',
      leading: OrbitBackButton(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/today');
          }
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          GlassPanel(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: palette.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    key: const Key('unified-search-input'),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск по всей экосистеме...',
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: _performSearch,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryFilterChip(
                  label: 'Все',
                  isSelected: _selectedCategory == null,
                  palette: palette,
                  onTap: () {
                    setState(() => _selectedCategory = null);
                    _performSearch(_searchController.text);
                  },
                ),
                for (final cat in SearchCategory.values) ...[
                  const SizedBox(width: 8),
                  _CategoryFilterChip(
                    label: cat.displayName,
                    isSelected: _selectedCategory == cat,
                    palette: palette,
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _performSearch(_searchController.text);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Найдено результатов: ${_results.length}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Results list
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_results.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: palette.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ничего не найдено',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Попробуйте изменить запрос или категорию',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _results[index];
                final catColor = _colorForCategory(item.category, palette);

                return GlassPanel(
                  palette: palette,
                  padding: const EdgeInsets.all(14),
                  onTap: () {
                    // Navigate based on category
                    switch (item.category) {
                      case SearchCategory.email:
                        context.push('/mail/message/${item.id}');
                      case SearchCategory.event:
                        context.push('/event/${item.id}');
                      case SearchCategory.task:
                        context.push('/tasks/task/${item.id}');
                      case SearchCategory.note:
                        // Show note detail sheet
                        _showNoteDetailSheet(context, item, palette);
                      case SearchCategory.contact:
                        context.push('/mail/compose');
                      case SearchCategory.all:
                        break;
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          _iconForCategory(item.category),
                          size: 18,
                          color: catColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.category.displayName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(item.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.snippet,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  void _showNoteDetailSheet(
    BuildContext context,
    SearchResultItem item,
    OrbitPalette palette,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.isLight
              ? Colors.white.withValues(alpha: 0.96)
              : const Color(0xFF1E2028).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.snippet,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                ),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final OrbitPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.accent
              : palette.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? palette.accent
                : palette.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
