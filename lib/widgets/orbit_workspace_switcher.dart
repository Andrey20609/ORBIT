import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/workspace_record.dart';
import '../state/app_state.dart';

/// P3-01: модальный лист управления пространствами (переключение,
/// создание, удаление не-дефолтных). Верстка по правилам MAIL-02B r3:
/// useRootNavigator + useSafeArea + SingleChildScrollView + Wrap -
/// без переполнений на 360x780.
Future<void> showWorkspaceSwitcherSheet(
  BuildContext context,
  OrbitAppState state,
) async {
  final nameController = TextEditingController();
  try {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewPadding.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: state,
                builder: (sheetContext, _) {
                  final workspaces = state.workspaces;
                  final activeId = state.activeWorkspaceId;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dashboard_customize_rounded,
                            size: 18,
                            color:
                                Theme.of(sheetContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Пространства',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Активное: ${state.activeWorkspace?.name ?? '-'} — '
                        'задачи, заметки, файлы и контакты фильтруются по '
                        'выбранному пространству.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      for (final ws in workspaces) ...[
                        _WorkspaceTile(
                          key: Key('workspace-tile-${ws.id}'),
                          workspace: ws,
                          isActive: ws.id == activeId,
                          onTap: () async {
                            await state.switchWorkspace(ws.id);
                          },
                          onDelete: ws.isDefault
                              ? null
                              : () async {
                                  final error = await state.deleteWorkspace(
                                    ws.id,
                                  );
                                  if (error != null && sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      SnackBar(
                                        key: const Key(
                                          'workspace-delete-error',
                                        ),
                                        content: Text(error),
                                      ),
                                    );
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Divider(height: 24),
                      TextField(
                        key: const Key('workspace-name-field'),
                        controller: nameController,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Название нового пространства',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('workspace-create'),
                        onPressed: () async {
                          final error = await state.createWorkspace(
                            nameController.text,
                          );
                          if (error != null && sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                key: const Key('workspace-create-error'),
                                content: Text(error),
                              ),
                            );
                            return;
                          }
                          nameController.clear();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Создать и переключиться',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  } finally {
    nameController.dispose();
  }
}

final class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    super.key,
    required this.workspace,
    required this.isActive,
    required this.onTap,
    this.onDelete,
  });

  final WorkspaceRecord workspace;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isActive ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Color(workspace.colorValue).withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Color(workspace.colorValue)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(workspace.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                workspace.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (workspace.isDefault)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.push_pin_outlined,
                  size: 12,
                  color: Colors.grey,
                ),
              ),
            if (isActive)
              const Icon(Icons.check_rounded, size: 16)
            else if (onDelete != null)
              IconButton(
                key: Key('workspace-delete-${workspace.id}'),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
