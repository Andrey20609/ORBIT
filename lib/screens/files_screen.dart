import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/database/memory_orbit_database.dart';
import '../data/database/orbit_data_engine.dart';
import '../data/models/file_record.dart';
import '../services/files/orbit_file_manager.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

final class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

final class _FilesScreenState extends State<FilesScreen> {
  late final OrbitFileManager _fileManager;
  List<FileRecord> _files = [];
  String _selectedFilter = 'Все';
  int _totalBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final engine = OrbitDataEngine(MemoryOrbitDatabase(autoSeed: true));
    _fileManager = OrbitFileManager(dataEngine: engine);
    _seedInitialFilesAndLoad();
  }

  Future<void> _seedInitialFilesAndLoad() async {
    try {
      final existing = await _fileManager.getFiles();
      if (existing.isEmpty) {
        // Seed default reference files from the spec/UI boards
        await _fileManager.attachFile(
          fileName: 'План_недели.pdf',
          sizeBytes: 2516582, // 2.4 MB
          mimeType: 'application/pdf',
          associatedEntityType: 'email',
          associatedEntityId: 'review',
        );
        await _fileManager.attachFile(
          fileName: 'График.xlsx',
          sizeBytes: 1153433, // 1.1 MB
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          associatedEntityType: 'email',
          associatedEntityId: 'review',
        );
        await _fileManager.attachFile(
          fileName: 'Презентация.pdf',
          sizeBytes: 8178892, // 7.8 MB
          mimeType: 'application/pdf',
          associatedEntityType: 'email',
          associatedEntityId: 'compose',
        );
        await _fileManager.attachFile(
          fileName: 'Техническое_задание_v1.0.pdf',
          sizeBytes: 3145728, // 3.0 MB
          mimeType: 'application/pdf',
          associatedEntityType: 'task',
        );
      }
      await _loadFiles();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _fileManager.getFiles();
      final total = await _fileManager.getTotalStorageUsed();
      if (mounted) {
        setState(() {
          _files = files;
          _totalBytes = total;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FileRecord> get _filteredFiles {
    if (_selectedFilter == 'Все') return _files;
    if (_selectedFilter == 'Документы') {
      return _files.where((f) => f.isDocument).toList();
    }
    if (_selectedFilter == 'Таблицы') {
      return _files.where((f) => f.isSpreadsheet).toList();
    }
    if (_selectedFilter == 'Изображения') {
      return _files.where((f) => f.isImage).toList();
    }
    return _files;
  }

  IconData _iconForFile(FileRecord file) {
    if (file.isPdf) return Icons.picture_as_pdf_rounded;
    if (file.isSpreadsheet) return Icons.table_chart_rounded;
    if (file.isImage) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _colorForFile(FileRecord file, OrbitPalette palette) {
    if (file.isPdf) return const Color(0xFFEF4444);
    if (file.isSpreadsheet) return const Color(0xFF10B981);
    if (file.isImage) return const Color(0xFF3B82F6);
    return palette.accent;
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;

    final usedMb = (_totalBytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
    final maxMb = (OrbitFileManager.maxFileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
    final quotaFraction = (_totalBytes / OrbitFileManager.maxFileSizeBytes).clamp(0.0, 1.0);

    return OrbitPage(
      title: 'Файлы и документы',
      subtitle: 'Локальное хранилище и вложения',
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
          icon: Icons.upload_file_rounded,
          tooltip: 'Загрузить файл',
          onTap: () async {
            await _fileManager.attachFile(
              fileName: 'Новый_документ_${DateTime.now().millisecond}.pdf',
              sizeBytes: 1572864, // 1.5 MB
              mimeType: 'application/pdf',
            );
            await _loadFiles();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Файл успешно добавлен в хранилище')),
              );
            }
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage Quota Card
          GlassPanel(
            palette: palette,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Память ORBIT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      '$usedMb МБ из $maxMb МБ',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: quotaFraction,
                    minHeight: 6,
                    backgroundColor: palette.textPrimary.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in ['Все', 'Документы', 'Таблицы', 'Изображения']) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selectedFilter = tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedFilter == tab
                            ? palette.accent
                            : palette.surface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFilter == tab
                              ? palette.accent
                              : palette.textPrimary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedFilter == tab ? FontWeight.w600 : FontWeight.normal,
                          color: _selectedFilter == tab ? Colors.white : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // File List
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_filteredFiles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: palette.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Файлы не найдены',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'В этой категории пока нет документов',
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
              itemCount: _filteredFiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = _filteredFiles[index];
                final iconColor = _colorForFile(file, palette);

                return GlassPanel(
                  palette: palette,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForFile(file), color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  file.formattedSize,
                                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                                ),
                                if (file.associatedEntityType != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: palette.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatAssociation(file.associatedEntityType!),
                                      style: TextStyle(fontSize: 10, color: palette.accent),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          await _fileManager.removeFile(file.id);
                          await _loadFiles();
                        },
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

  String _formatAssociation(String type) {
    return switch (type) {
      'email' => 'В письме',
      'event' => 'Во встрече',
      'task' => 'В задаче',
      'note' => 'В заметке',
      _ => 'Файл',
    };
  }
}
