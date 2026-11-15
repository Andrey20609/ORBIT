import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/database/memory_orbit_database.dart';
import '../data/database/orbit_data_engine.dart';
import '../data/drift_local_state_repository.dart';
import '../data/models/contact_record.dart';
import '../services/contacts/contacts_service.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

final class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

final class _ContactsScreenState extends State<ContactsScreen> {
  ContactsService? _contactsService;
  Map<String, List<ContactRecord>> _groupedContacts = {};
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;

  OrbitDataEngine? _engine;
  String? _loadedWorkspaceId;
  bool _engineReady = false;

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

  /// P3-01: движок поверх production SQLite с активным workspace;
  /// fallback - Memory-движок (memory-репозиторий / тесты).
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
    _contactsService = ContactsService(dataEngine: engine);
    await _loadContacts();
  }

  /// P3-01: смена активного пространства - перезагрузка данных.
  Future<void> _syncWorkspace() async {
    final engine = _engine;
    if (engine == null) return;
    final state = OrbitEnvironment.of(context).appState;
    if (state.activeWorkspaceId == _loadedWorkspaceId) return;
    engine.setActiveWorkspace(state.activeWorkspaceId);
    _loadedWorkspaceId = state.activeWorkspaceId;
    await _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final grouped = await _contactsService!.getContactsGroupedByLetter();
      if (mounted) {
        setState(() {
          _groupedContacts = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final roleCtrl = TextEditingController();

    final palette = OrbitEnvironment.of(context).palette;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
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
              Text(
                'Новый контакт',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Имя и фамилия',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Телефон',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: companyCtrl,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Компания',
                        labelStyle: TextStyle(color: palette.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: roleCtrl,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Должность',
                        labelStyle: TextStyle(color: palette.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
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
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) return;

                      await _contactsService!.createContact(
                        name: name,
                        email: email,
                        phone: phoneCtrl.text.trim(),
                        company: companyCtrl.text.trim(),
                        role: roleCtrl.text.trim(),
                      );
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      await _loadContacts();
                    },
                    child: const Text('Создать'),
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

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;

    final letters = _groupedContacts.keys.toList()..sort();

    return OrbitPage(
      title: 'Контакты',
      subtitle: 'Адресная книга и коллеги',
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
          icon: Icons.person_add_rounded,
          tooltip: 'Добавить контакт',
          onTap: _showAddContactDialog,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
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
                      hintText: 'Поиск контактов по имени или email...',
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (q) async {
                      if (q.isEmpty) {
                        await _loadContacts();
                      } else {
                        final found = await _contactsService!.searchContacts(q);
                        final grouped = <String, List<ContactRecord>>{};
                        for (final c in found) {
                          final letter = c.name.isNotEmpty ? c.name.substring(0, 1).toUpperCase() : '#';
                          grouped.putIfAbsent(letter, () => []).add(c);
                        }
                        setState(() => _groupedContacts = grouped);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_groupedContacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 48,
                      color: palette.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Список контактов пуст',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Добавьте коллег для быстрой связи',
                      style: TextStyle(fontSize: 13, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final letter in letters) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 12, bottom: 6),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: palette.accent,
                  ),
                ),
              ),
              for (final contact in _groupedContacts[letter]!) ...[
                GlassPanel(
                  palette: palette,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Monogram avatar
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              palette.accent,
                              palette.accentSecondary,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          contact.name.isNotEmpty ? contact.name.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              contact.role != null && contact.company != null
                                  ? '${contact.role} · ${contact.company}'
                                  : contact.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quick Action: Write email
                      IconButton(
                        icon: Icon(Icons.mail_outline_rounded, color: palette.accent, size: 20),
                        tooltip: 'Написать письмо',
                        onPressed: () {
                          env.appState.updateDraft(to: contact.email);
                          context.push('/mail/compose');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );
  }
}
