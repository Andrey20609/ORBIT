import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tasks/task_models.dart';
import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_motion_engine.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_spatial_surfaces.dart';

/// Универсальная модель данных заметки для детального редактора.
@immutable
final class OrbitNoteDetailModel {
  const OrbitNoteDetailModel({
    required this.id,
    required this.title,
    required this.markdownBody,
    required this.updatedAt,
    this.tags = const <String>[],
    this.linkedTaskIds = const <String>[],
  });

  final String id;
  final String title;
  final String markdownBody;
  final DateTime updatedAt;
  final List<String> tags;
  final List<String> linkedTaskIds;

  OrbitNoteDetailModel copyWith({
    String? title,
    String? markdownBody,
    DateTime? updatedAt,
    List<String>? tags,
    List<String>? linkedTaskIds,
  }) {
    return OrbitNoteDetailModel(
      id: id,
      title: title ?? this.title,
      markdownBody: markdownBody ?? this.markdownBody,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
    );
  }
}

/// Результат работы модального окна заметки.
@immutable
final class NoteDetailSheetResult {
  const NoteDetailSheetResult({
    this.updatedNote,
    this.deletedNoteId,
    this.createdLink,
  });

  final OrbitNoteDetailModel? updatedNote;
  final String? deletedNoteId;
  final CrossEntityLink? createdLink;
}

/// Открывает модальную шторку просмотра и редактирования заметки.
Future<NoteDetailSheetResult?> showNoteDetailSheet(
  BuildContext context, {
  required OrbitPalette palette,
  required OrbitProfile profile,
  required OrbitNoteDetailModel note,
  ValueChanged<OrbitNoteDetailModel>? onSave,
  ValueChanged<String>? onDelete,
  ValueChanged<CrossEntityLink>? onConvertToTask,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<NoteDetailSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => NoteDetailSheet(
      palette: palette,
      profile: profile,
      note: note,
      onSave: onSave,
      onDelete: onDelete,
      onConvertToTask: onConvertToTask,
    ),
  );
}

final class NoteDetailSheet extends StatefulWidget {
  const NoteDetailSheet({
    required this.palette,
    required this.profile,
    required this.note,
    this.onSave,
    this.onDelete,
    this.onConvertToTask,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitNoteDetailModel note;
  final ValueChanged<OrbitNoteDetailModel>? onSave;
  final ValueChanged<String>? onDelete;
  final ValueChanged<CrossEntityLink>? onConvertToTask;

  @override
  State<NoteDetailSheet> createState() => _NoteDetailSheetState();
}

final class _NoteDetailSheetState extends State<NoteDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _newTagController;
  late List<String> _tags;
  late List<String> _linkedTaskIds;
  bool _isPreviewMode = false;

  double get _radius => orbitRadiusForProfile(widget.profile);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _bodyController = TextEditingController(text: widget.note.markdownBody);
    _newTagController = TextEditingController();
    _tags = List<String>.from(widget.note.tags);
    _linkedTaskIds = List<String>.from(widget.note.linkedTaskIds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final cleaned = raw.trim().replaceAll('#', '').toLowerCase();
    if (cleaned.isEmpty || _tags.contains(cleaned)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tags.add(cleaned);
      _newTagController.clear();
    });
  }

  void _removeTag(String tag) {
    HapticFeedback.lightImpact();
    setState(() => _tags.remove(tag));
  }

  void _insertMarkdownSnippet(String prefix, [String suffix = '']) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';

    _bodyController.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(
        offset: start + replacement.length,
      ),
    );
  }

  void _handleConvertToTask() {
    HapticFeedback.mediumImpact();
    final generatedTaskId = 'task_from_${widget.note.id}_${DateTime.now().millisecondsSinceEpoch}';
    final link = CrossEntityLink(
      id: 'link_${widget.note.id}_$generatedTaskId',
      sourceType: EntityType.note,
      sourceId: widget.note.id,
      targetType: EntityType.task,
      targetId: generatedTaskId,
      title: widget.note.title,
      createdAt: DateTime.now(),
    );

    setState(() {
      if (!_linkedTaskIds.contains(generatedTaskId)) {
        _linkedTaskIds.add(generatedTaskId);
      }
    });

    widget.onConvertToTask?.call(link);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.palette.accent,
        content: Text(
          'Создана задача и связь CrossEntityLink (${link.targetId})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _handleSave() {
    HapticFeedback.mediumImpact();
    final updated = widget.note.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'Без названия'
          : _titleController.text.trim(),
      markdownBody: _bodyController.text,
      updatedAt: DateTime.now(),
      tags: _tags,
      linkedTaskIds: _linkedTaskIds,
    );
    widget.onSave?.call(updated);
    Navigator.of(context).pop(
      NoteDetailSheetResult(updatedNote: updated),
    );
  }

  void _handleDelete() {
    HapticFeedback.heavyImpact();
    widget.onDelete?.call(widget.note.id);
    Navigator.of(context).pop(
      NoteDetailSheetResult(deletedNoteId: widget.note.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.25;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 12),
      child: OrbitSpatialCard(
        palette: palette,
        radius: _radius + 8,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Верхний индикатор и шапка действий
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Заметка Markdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    OrbitPressable(
                      semanticLabel: _isPreviewMode
                          ? 'Режим редактирования'
                          : 'Режим предпросмотра Markdown',
                      onTap: () =>
                          setState(() => _isPreviewMode = !_isPreviewMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(_radius * 0.6),
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _isPreviewMode ? 'Редактор' : 'Превью MD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Поле заголовка заметки
                GlassPanel(
                  palette: palette,
                  radius: _radius * 0.8,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: TextField(
                    key: const Key('note-title-input'),
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Заголовок заметки…',
                      hintStyle: TextStyle(color: palette.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Панель быстрого форматирования Markdown
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MarkdownFormatChip(
                        palette: palette,
                        label: 'H1',
                        onTap: () => _insertMarkdownSnippet('# '),
                      ),
                      const SizedBox(width: 6),
                      _MarkdownFormatChip(
                        palette: palette,
                        label: 'Жирный',
                        onTap: () => _insertMarkdownSnippet('**', '**'),
                      ),
                      const SizedBox(width: 6),
                      _MarkdownFormatChip(
                        palette: palette,
                        label: 'Чек-лист',
                        onTap: () => _insertMarkdownSnippet('- [ ] '),
                      ),
                      const SizedBox(width: 6),
                      _MarkdownFormatChip(
                        palette: palette,
                        label: 'Код',
                        onTap: () => _insertMarkdownSnippet('`', '`'),
                      ),
                      const SizedBox(width: 6),
                      _MarkdownFormatChip(
                        palette: palette,
                        label: 'Цитата',
                        onTap: () => _insertMarkdownSnippet('> '),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Поле текста заметки или рендер превью Markdown
                GlassPanel(
                  palette: palette,
                  radius: _radius * 0.85,
                  padding: const EdgeInsets.all(14),
                  child: _isPreviewMode
                      ? _MarkdownLightweightPreview(
                          markdown: _bodyController.text,
                          palette: palette,
                        )
                      : TextField(
                          key: const Key('note-markdown-input'),
                          controller: _bodyController,
                          minLines: 6,
                          maxLines: 12,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: palette.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Пишите в формате Markdown (# заголовки, - списки, **акценты**)…',
                            hintStyle: TextStyle(color: palette.textSecondary),
                            border: InputBorder.none,
                          ),
                        ),
                ),
                const SizedBox(height: 14),

                // Секция тегов (добавление и удаление chips)
                Text(
                  'ТЕГИ ЭКОСИСТЕМЫ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            OrbitPressable(
                              semanticLabel: 'Удалить тег $tag',
                              onTap: () => _removeTag(tag),
                              child: Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GlassPanel(
                        palette: palette,
                        radius: _radius * 0.7,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: TextField(
                          key: const Key('note-add-tag-input'),
                          controller: _newTagController,
                          onSubmitted: _addTag,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: palette.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Добавить тег (например: релиз, идея)…',
                            hintStyle: TextStyle(color: palette.textSecondary),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrbitFilledButton(
                      buttonKey: const Key('note-add-tag-button'),
                      palette: palette,
                      radius: _radius * 0.7,
                      compact: true,
                      icon: Icons.tag_rounded,
                      label: 'Добавить',
                      onTap: () => _addTag(_newTagController.text),
                    ),
                  ],
                ),

                if (_linkedTaskIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassPanel(
                    palette: palette,
                    radius: _radius * 0.7,
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: palette.accentSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Связано с задачами (${_linkedTaskIds.length}): ${_linkedTaskIds.join(", ")}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Кнопка конвертации заметки в Задачу (CrossEntityLink)
                OrbitFilledButton(
                  buttonKey: const Key('note-convert-to-task-button'),
                  palette: palette,
                  radius: _radius * 0.8,
                  isPrimary: false,
                  primaryColor: palette.accentSecondary,
                  icon: Icons.add_task_rounded,
                  label: 'Перевести заметку в Задачу',
                  subtitle: 'Создаст задачу и сквозную связь CrossEntityLink',
                  onTap: _handleConvertToTask,
                ),
                const SizedBox(height: 12),

                // Нижний ряд: Удалить и Сохранить
                if (isLargeText) ...[
                  OrbitFilledButton(
                    buttonKey: const Key('note-save-button'),
                    palette: palette,
                    radius: _radius * 0.8,
                    icon: Icons.check_rounded,
                    label: 'Сохранить изменения',
                    onTap: _handleSave,
                  ),
                  const SizedBox(height: 8),
                  OrbitFilledButton(
                    buttonKey: const Key('note-delete-button'),
                    palette: palette,
                    radius: _radius * 0.8,
                    isPrimary: false,
                    primaryColor: Colors.redAccent,
                    icon: Icons.delete_outline_rounded,
                    label: 'Удалить заметку',
                    onTap: _handleDelete,
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OrbitFilledButton(
                          buttonKey: const Key('note-delete-button'),
                          palette: palette,
                          radius: _radius * 0.8,
                          isPrimary: false,
                          primaryColor: Colors.redAccent,
                          icon: Icons.delete_outline_rounded,
                          label: 'Удалить',
                          onTap: _handleDelete,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: OrbitFilledButton(
                          buttonKey: const Key('note-save-button'),
                          palette: palette,
                          radius: _radius * 0.8,
                          icon: Icons.check_rounded,
                          label: 'Сохранить заметку',
                          onTap: _handleSave,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _MarkdownFormatChip extends StatelessWidget {
  const _MarkdownFormatChip({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final OrbitPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OrbitPressable(
      semanticLabel: 'Форматирование $label',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: palette.textSecondary.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

final class _MarkdownLightweightPreview extends StatelessWidget {
  const _MarkdownLightweightPreview({
    required this.markdown,
    required this.palette,
  });

  final String markdown;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    final lines = markdown.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _renderLine(line),
          ),
      ],
    );
  }

  Widget _renderLine(String line) {
    if (line.startsWith('# ')) {
      return Text(
        line.substring(2),
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
      );
    }
    if (line.startsWith('- [ ] ') || line.startsWith('- [x] ')) {
      final checked = line.startsWith('- [x] ');
      return Row(
        children: [
          Icon(
            checked
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 18,
            color: palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.substring(6),
              style: TextStyle(
                fontSize: 14,
                color: palette.textPrimary,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      line,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.4,
        color: palette.textPrimary,
      ),
    );
  }
}
