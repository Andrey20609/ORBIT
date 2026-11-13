import 'package:flutter/material.dart';

import '../data/orbit_corrupt_data.dart';
import '../l10n/app_localizations.dart';
import '../visual_engine/appearance_settings.dart';
import 'glass_panel.dart';
import 'orbit_environment.dart';

final class OrbitPersistenceWarning extends StatelessWidget {
  const OrbitPersistenceWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final appearanceCorrupt =
        env.style.lastLoadError is OrbitCorruptDataException;
    final localCorrupt =
        env.appState.lastLoadError is OrbitCorruptDataException;
    if (appearanceCorrupt || localCorrupt) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GlassPanel(
          palette: env.palette,
          quality: ResolvedQuality.static,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  appearanceCorrupt
                      ? AppLocalizations.of(context).appearanceCorrupted
                      : AppLocalizations.of(context).localDataCorrupted,
                ),
              ),
              TextButton(
                key: const Key('corrupt-export'),
                onPressed: () => _exportBackup(context, env, localCorrupt),
                child: Text(AppLocalizations.of(context).exportBackup),
              ),
              TextButton(
                key: const Key('corrupt-reset'),
                onPressed: () => _confirmReset(context, env, localCorrupt),
                child: Text(AppLocalizations.of(context).resetCorruptData),
              ),
            ],
          ),
        ),
      );
    }
    final hasAppearanceLoadError = env.style.lastLoadError != null;
    final hasLocalLoadError = env.appState.lastLoadError != null;
    final hasAppearanceSaveError = env.style.lastPersistenceError != null;
    final hasLocalSaveError = env.appState.lastPersistenceError != null;
    if (!hasAppearanceLoadError &&
        !hasLocalLoadError &&
        !hasAppearanceSaveError &&
        !hasLocalSaveError) {
      return const SizedBox.shrink();
    }
    final message = hasAppearanceLoadError
        ? AppLocalizations.of(context).appearanceLoadFailed
        : hasLocalLoadError
        ? AppLocalizations.of(context).localLoadFailed
        : hasAppearanceSaveError
        ? AppLocalizations.of(context).appearanceSaveFailed
        : AppLocalizations.of(context).localSaveFailed;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GlassPanel(
        palette: env.palette,
        quality: ResolvedQuality.static,
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(
              key: const Key('persistence-retry'),
              onPressed: () async {
                try {
                  if (hasAppearanceLoadError) await env.style.load();
                  if (hasLocalLoadError) await env.appState.load();
                  if (hasAppearanceSaveError) {
                    await env.style.retryPersistence();
                  }
                  if (hasLocalSaveError) {
                    await env.appState.retryPersistence();
                  }
                } on Object {
                  // Keep the warning visible until a save succeeds.
                }
              },
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _exportBackup(
  BuildContext context,
  OrbitEnvironment env,
  bool local,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final exported = AppLocalizations.of(context).backupExported;
  final failed = AppLocalizations.of(context).backupExportFailed;
  try {
    final repository = local ? env.appState.repository : env.style.repository;
    if (repository is! OrbitCorruptDataRecovery) {
      throw StateError('Backup export is unavailable');
    }
    final path = await repository.exportCorruptBackup();
    messenger.showSnackBar(SnackBar(content: Text(exported(path))));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

Future<void> _confirmReset(
  BuildContext context,
  OrbitEnvironment env,
  bool local,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.of(dialogContext).resetCorruptData),
      content: Text(AppLocalizations.of(dialogContext).resetCorruptConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(AppLocalizations.of(dialogContext).cancel),
        ),
        FilledButton(
          key: const Key('corrupt-reset-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(AppLocalizations.of(dialogContext).resetCorruptData),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    if (local) {
      await env.appState.resetCorruptData();
    } else {
      await env.style.resetCorruptData();
    }
  } on Object {
    // Keep the recovery warning visible if reset fails.
  }
}
