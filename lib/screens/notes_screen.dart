import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/database/memory_orbit_database.dart';
import '../data/database/orbit_data_engine.dart';
import '../data/drift_local_state_repository.dart';
import '../data/models/note_record.dart';
import '../services/notes/notes_service.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

final class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, this.openAdd = false});

  final bool openAdd;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

final class _NotesScreenState extends State<NotesScreen> {
  NotesService? _notesService;
  OrbitDataEngine? _engine;
  String? _loadedWorkspaceId;
  bool _engineReady = false;
  List<NoteRecord> _notes = [];
  Set<String> _tags = {};
  String? _selectedTag;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditNoteDialog();
      });
    }
  }

  /// P3-01: движок поверх production SQLite (единый владелец файла -
  /// DriftLocalStateRepository) с активным workspace; fallback на
  /// Memory-движок для memory-репозитория (тесты).
  Future<void> _ensureEngine() async {
    final state = OrbitEnvironment.of(context).appState;
    final repo = state.repository;
    OrbitDataEngine engine;
    if (repo is DriftLocalStateRepository) {
      engine = OrbitDataEngine(await repo.outboxDatabase());
      _loadedWorkspaceId = state.activeWorkspaceId;
      engine.setActiveWorkspace(_loadedWorkspaceId!);
    } else {
      engine = OrbitDataEngine(MemoryOrbitDatabase(autoSeed: true));
      _loadedWorkspaceId = engine.activeWorkspaceId;
    }
    _engine = engine;
    _notesService = NotesService(dataEngine: engine);
    await _loadNotes();
  }

  /// P3-01: смена активного пространства - перезагрузка данных.
  Future<void> _syncWorkspace() async {
    final engine = _engine;
    if (engine == null) return;
    final state = OrbitEnvironment.of(context).appState;
    if (state.activeWorkspaceId == _loadedWorkspaceId) return;
    engine.setActiveWorkspace(state.activeWorkspaceId);
    _loadedWorkspaceId = state.activeWorkspaceId;
    await _loadNotes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_engineReady) {
      _engineReady = true;
      unawaited(_ensureEngine());
    } else {
      unawaited(_syncWorkspace());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _notesService!.getNotes(tagFilter: _selectedTag);
      final tags = await _notesService!.getAllTags();
      if (mounted) {
        setState(() {
          _notes = notes;
          _tags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditNoteDialog([NoteRecord? existing]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final tagsCtrl = TextEditingController(
      text: existing != null ? existing.tags.join(', ') : '',
    );

    final palette = OrbitEnvironment.of(context).palette;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: palette.isLight
                ? Colors.white.withValues(alpha: 0.98)
                : const Color(0xFF1E2028).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    existing == null ? 'Новая заметка' : 'Редактировать',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () async {
                        await _notesService!.deleteNote(existing.id);
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        await _loadNotes();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Заголовок',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Текст заметки',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsCtrl,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Теги (через запятую)',
                  hintText: 'Проект, Идеи, Встреча',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text('Отмена', style: TextStyle(color: palette.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: palette.accent),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final tags = tagsCtrl.text
                          .split(',')
                          .map((t) => t.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();

                      if (existing == null) {
                        await _notesService!.createNote(
                          title: title,
                          content: contentCtrl.text.trim(),
                          tags: tags,
                        );
                      } else {
                        await _notesService!.updateNote(
                          existing.copyWith(
                            title: title,
                            content: contentCtrl.text.trim(),
                            tags: tags,
                          ),
                        );
                      }
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      await _loadNotes();
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;

    return OrbitPage(
      title: 'Заметки',
      subtitle: 'Быстрые мысли, идеи и документы',
      leading: OrbitBackButton(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/today');
          }
        },
      ),
      actions: [
        OrbitIconButton(
          palette: palette,
          icon: Icons.add_rounded,
          tooltip: 'Добавить заметку',
          onTap: () => _showEditNoteDialog(),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter
          GlassPanel(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: palette.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: palette.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Поиск по заметкам...',
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (q) async {
                      final res = await _notesService!.searchNotes(q);
                      setState(() => _notes = res);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tag chips
          if (_tags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TagChip(
                    label: 'Все',
                    isSelected: _selectedTag == null,
                    palette: palette,
                    onTap: () {
                      setState(() => _selectedTag = null);
                      _loadNotes();
                    },
                  ),
                  for (final tag in _tags) ...[
                    const SizedBox(width: 8),
                    _TagChip(
                      label: tag,
                      isSelected: _selectedTag == tag,
                      palette: palette,
                      onTap: () {
                        setState(() => _selectedTag = tag);
                        _loadNotes();
                      },
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_notes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 48,
                      color: palette.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Нет заметок',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажмите + чтобы создать новую заметку',
                      style: TextStyle(fontSize: 13, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = _notes[index];
                return GlassPanel(
                  palette: palette,
                  padding: const EdgeInsets.all(16),
                  onTap: () => _showEditNoteDialog(note),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(note.updatedAt),
                            style: TextStyle(fontSize: 11, color: palette.textSecondary),
                          ),
                        ],
                      ),
                      if (note.content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: palette.textSecondary, height: 1.3),
                        ),
                      ],
                      if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in note.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: palette.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: palette.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

final class _TagChip extends StatelessWidget {
  const _TagChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.accent : palette.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? palette.accent : palette.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
