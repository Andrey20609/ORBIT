import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_spatial_surfaces.dart';

/// Модель метаданных файла для детальной шторки `FileDetailSheet`.
@immutable
final class OrbitFileDetailModel {
  const OrbitFileDetailModel({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.addedAt,
    this.storageUsedBytes = 19293798, // ~18.4 МБ
    this.storageQuotaBytes = 52428800, // 50.0 МБ
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime addedAt;
  final int storageUsedBytes;
  final int storageQuotaBytes;

  double get sizeMb => sizeBytes / (1024 * 1024);
  double get storageUsedMb => storageUsedBytes / (1024 * 1024);
  double get storageQuotaMb => storageQuotaBytes / (1024 * 1024);

  double get quotaRatio =>
      (storageUsedBytes / storageQuotaBytes).clamp(0.0, 1.2);

  bool get isQuotaWarning => storageUsedBytes >= (storageQuotaBytes * 0.85);
  bool get isQuotaExceeded => storageUsedBytes > storageQuotaBytes;
}

/// Открывает интерактивную шторку просмотра файла и управления квотой.
Future<void> showFileDetailSheet(
  BuildContext context, {
  required OrbitPalette palette,
  required OrbitProfile profile,
  required OrbitFileDetailModel file,
  ValueChanged<String>? onDeleteFile,
  ValueChanged<String>? onAttachToTask,
  ValueChanged<String>? onAttachToMail,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => FileDetailSheet(
      palette: palette,
      profile: profile,
      file: file,
      onDeleteFile: onDeleteFile,
      onAttachToTask: onAttachToTask,
      onAttachToMail: onAttachToMail,
    ),
  );
}

final class FileDetailSheet extends StatelessWidget {
  const FileDetailSheet({
    required this.palette,
    required this.profile,
    required this.file,
    this.onDeleteFile,
    this.onAttachToTask,
    this.onAttachToMail,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitFileDetailModel file;
  final ValueChanged<String>? onDeleteFile;
  final ValueChanged<String>? onAttachToTask;
  final ValueChanged<String>? onAttachToMail;

  double get _radius => orbitRadiusForProfile(profile);

  (IconData, String, Color) _resolvePreviewStyle() {
    final lower = file.mimeType.toLowerCase();
    if (lower.contains('pdf')) {
      return (Icons.picture_as_pdf_rounded, 'PDF Документ', Colors.redAccent);
    }
    if (lower.contains('word') ||
        lower.contains('docx') ||
        file.fileName.endsWith('.docx')) {
      return (Icons.description_rounded, 'Документ DOCX', Colors.blueAccent);
    }
    if (lower.contains('image') ||
        lower.contains('png') ||
        lower.contains('jpg')) {
      return (Icons.image_rounded, 'Изображение', palette.accent);
    }
    if (lower.contains('zip') || lower.contains('tar')) {
      return (Icons.folder_zip_rounded, 'Архив данных', Colors.amber.shade700);
    }
    return (
      Icons.insert_drive_file_rounded,
      'Файл экосистемы',
      palette.accentSecondary,
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} в $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final (previewIcon, typeLabel, previewTint) = _resolvePreviewStyle();
    final isWarning = file.isQuotaWarning || file.isQuotaExceeded;
    final barColor = file.isQuotaExceeded
        ? Colors.redAccent
        : (file.isQuotaWarning ? Colors.orangeAccent : palette.accent);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: OrbitSpatialCard(
        palette: palette,
        radius: _radius + 8,
        tintColor: previewTint,
        tintIntensity: 0.14,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                const SizedBox(height: 16),

                // Визуальное превью файла в стиле visionOS
                OrbitSpatialCard(
                  palette: palette,
                  radius: _radius,
                  tintColor: previewTint,
                  tintIntensity: 0.22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 22,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: previewTint.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(_radius * 0.7),
                          border: Border.all(
                            color: previewTint.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Icon(
                          previewIcon,
                          size: 36,
                          color: previewTint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        file.fileName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$typeLabel • ${file.sizeMb.toStringAsFixed(2)} МБ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Метаданные: точный размер, дата добавления, MIME-тип
                GlassPanel(
                  palette: palette,
                  radius: _radius * 0.85,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _MetaRow(
                        palette: palette,
                        label: 'MIME-тип',
                        value: file.mimeType,
                      ),
                      const Divider(height: 16),
                      _MetaRow(
                        palette: palette,
                        label: 'Точный размер',
                        value:
                            '${file.sizeMb.toStringAsFixed(2)} МБ (${file.sizeBytes} байт)',
                      ),
                      const Divider(height: 16),
                      _MetaRow(
                        palette: palette,
                        label: 'Дата добавления',
                        value: _formatDate(file.addedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Контроль квоты 50 МБ с визуальной подсветкой прогресс-бара
                GlassPanel(
                  palette: palette,
                  radius: _radius * 0.85,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Квота хранилища ORBIT Vault',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${file.storageUsedMb.toStringAsFixed(1)} / ${file.storageQuotaMb.toInt()} МБ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: file.quotaRatio.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              palette.textSecondary.withValues(alpha: 0.16),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      if (isWarning) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: barColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.isQuotaExceeded
                                    ? 'Лимит 50 МБ превышен! Удалите неиспользуемые вложения для синхронизации.'
                                    : 'Хранилище заполнено более чем на 85% лимита в 50 МБ.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: barColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Кнопки действий с файлом (полное заполнение)
                OrbitFilledButton(
                  buttonKey: const Key('file-attach-to-task-button'),
                  palette: palette,
                  radius: _radius * 0.8,
                  icon: Icons.add_task_rounded,
                  label: 'Прикрепить к задаче',
                  subtitle: 'Создать связь файла с задачей экосистемы',
                  onTap: () {
                    onAttachToTask?.call(file.id);
                    Navigator.of(context).pop();
                    context.push('/tasks?attachFileId=${file.id}');
                  },
                ),
                const SizedBox(height: 8),
                OrbitFilledButton(
                  buttonKey: const Key('file-attach-to-mail-button'),
                  palette: palette,
                  radius: _radius * 0.8,
                  isPrimary: false,
                  icon: Icons.attach_email_rounded,
                  label: 'Прикрепить к письму',
                  subtitle: 'Вложить в новый черновик почты',
                  onTap: () {
                    onAttachToMail?.call(file.id);
                    Navigator.of(context).pop();
                    context.push('/mail?attachFileId=${file.id}');
                  },
                ),
                const SizedBox(height: 8),
                OrbitFilledButton(
                  buttonKey: const Key('file-delete-button'),
                  palette: palette,
                  radius: _radius * 0.8,
                  isPrimary: false,
                  primaryColor: Colors.redAccent,
                  icon: Icons.delete_outline_rounded,
                  label: 'Удалить файл из хранилища',
                  subtitle:
                      'Освободит ${file.sizeMb.toStringAsFixed(2)} МБ в квоте',
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    onDeleteFile?.call(file.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.palette,
    required this.label,
    required this.value,
  });

  final OrbitPalette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
