import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/demo_data.dart';
import '../services/mail/mail_connection_verifier.dart';
import '../visual_engine/orbit_palette.dart';
import '../visual_engine/orbit_profile.dart';
import 'glass_panel.dart';
import 'orbit_environment.dart';
import 'orbit_pressable.dart';
import 'orbit_spatial_surfaces.dart';

/// Открывает модальную шторку управления почтовыми аккаунтами и диагностики соединения поверх нижнего дока.
Future<void> showOrbitMailAccountsSheet(
  BuildContext context, {
  required OrbitPalette palette,
  OrbitProfile? profile,
  List<OrbitMailAccount>? accounts,
  ValueChanged<String>? onSelectActiveAccount,
  ValueChanged<OrbitMailAccount>? onSaveAccount,
  ValueChanged<String>? onRemoveAccount,
  OrbitMailConnectionVerifier? verifier,
}) {
  HapticFeedback.mediumImpact();
  final appState = OrbitEnvironment.maybeOf(context)?.appState;
  final effectiveProfile = profile ?? palette.profile;
  final effectiveAccounts = accounts ?? appState?.mailAccounts ?? initialMailAccounts;

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // Гарантирует открытие поверх нижнего дока навигации
    isScrollControlled: true,
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(
      alpha: palette.isLight ? 0.28 : 0.58,
    ),
    builder: (sheetCtx) => OrbitMailAccountsSheet(
      palette: palette,
      profile: effectiveProfile,
      initialAccounts: effectiveAccounts,
      onSelectActiveAccount: onSelectActiveAccount ??
          ((id) => appState?.setActiveMailAccount(id)),
      onSaveAccount: onSaveAccount ??
          ((acc) => appState?.addMailAccount(acc)),
      onRemoveAccount: onRemoveAccount ??
          ((id) => appState?.removeMailAccount(id)),
      verifier: verifier ?? OrbitMailConnectionVerifier(),
    ),
  );
}

final class OrbitMailAccountsSheet extends StatefulWidget {
  const OrbitMailAccountsSheet({
    required this.palette,
    required this.profile,
    required this.initialAccounts,
    required this.onSelectActiveAccount,
    required this.onSaveAccount,
    required this.onRemoveAccount,
    required this.verifier,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final List<OrbitMailAccount> initialAccounts;
  final ValueChanged<String> onSelectActiveAccount;
  final ValueChanged<OrbitMailAccount> onSaveAccount;
  final ValueChanged<String> onRemoveAccount;
  final OrbitMailConnectionVerifier verifier;

  @override
  State<OrbitMailAccountsSheet> createState() => _OrbitMailAccountsSheetState();
}

final class _OrbitMailAccountsSheetState extends State<OrbitMailAccountsSheet> {
  late List<OrbitMailAccount> _accounts;
  bool _isAddingAccount = false;

  OrbitMailProviderType _selectedProvider = OrbitMailProviderType.yandex;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _useSsl = true;

  MailVerificationStage _currentStage = MailVerificationStage.idle;
  MailDiagnosticResult? _lastDiagnostic;
  bool _isVerifying = false;

  double get _radius => orbitRadiusForProfile(widget.profile);

  @override
  void initState() {
    super.initState();
    _accounts = List<OrbitMailAccount>.from(widget.initialAccounts);
    _nameController = TextEditingController(text: 'Рабочая почта');
    _emailController = TextEditingController(text: 'architect@yandex.ru');
    _hostController = TextEditingController(
      text: _selectedProvider.defaultIncomingHost,
    );
    _portController = TextEditingController(
      text: '${_selectedProvider.defaultIncomingPort}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onProviderChanged(OrbitMailProviderType provider) {
    setState(() {
      _selectedProvider = provider;
      _hostController.text = provider.defaultIncomingHost;
      _portController.text = '${provider.defaultIncomingPort}';
      _useSsl = provider.defaultIncomingPort == 993 ||
          provider.defaultIncomingPort == 465;
      _currentStage = MailVerificationStage.idle;
      _lastDiagnostic = null;
    });
  }

  Future<void> _runLiveVerification() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 993;

    setState(() {
      _isVerifying = true;
      _currentStage = MailVerificationStage.resolvingDns;
      _lastDiagnostic = null;
    });

    final result = await widget.verifier.verifyEndpoint(
      host: host,
      port: port,
      useSsl: _useSsl,
      onStageChanged: (stage) {
        if (!mounted) return;
        setState(() => _currentStage = stage);
      },
    );

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _lastDiagnostic = result;
      _currentStage = result.isSuccess
          ? MailVerificationStage.success
          : result.failedStage;
    });
  }

  Future<void> _saveVerifiedAccount() async {
    if (_lastDiagnostic == null) {
      await _runLiveVerification();
    }
    if (!mounted) return;

    final diag = _lastDiagnostic;
    final port = int.tryParse(_portController.text.trim()) ?? 993;
    final newAccount = OrbitMailAccount(
      id: 'acc_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? _selectedProvider.label
          : _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? 'user@orbit.app'
          : _emailController.text.trim(),
      providerType: _selectedProvider,
      incomingHost: _hostController.text.trim(),
      incomingPort: port,
      useIncomingSsl: _useSsl,
      outgoingHost: _selectedProvider.defaultOutgoingHost,
      outgoingPort: _selectedProvider.defaultOutgoingPort,
      useOutgoingSsl: _useSsl,
      lastVerifiedAtIso: DateTime.now().toIso8601String(),
      lastLatencyMs: diag?.latencyMs,
      isActive: true,
      status: (diag?.isSuccess ?? false)
          ? OrbitMailAccountStatus.verified
          : OrbitMailAccountStatus.failed,
    );

    widget.onSaveAccount(newAccount);
    setState(() {
      _accounts = [
        for (final a in _accounts) a.copyWith(isActive: false),
        newAccount,
      ];
      _isAddingAccount = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final isLight = palette.isLight;
    final sheetRadius = _radius + 8.0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sheetRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: isLight ? 0.86 : 0.80),
              borderRadius: BorderRadius.circular(sheetRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isLight ? 0.55 : 0.16),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed Sheet Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: palette.textSecondary.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.alternate_email_rounded,
                              color: palette.accent,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isAddingAccount ? 'Новый почтовый аккаунт' : 'Почтовые аккаунты',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            OrbitIconButton(
                              key: const Key('close-mail-accounts-sheet-btn'),
                              palette: palette,
                              icon: Icons.close_rounded,
                              tooltip: 'Закрыть',
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OrbitFilledButton(
                            buttonKey: const Key('toggle-add-mail-account-btn'),
                            palette: palette,
                            radius: _radius * 0.7,
                            compact: true,
                            isPrimary: !_isAddingAccount,
                            icon: _isAddingAccount
                                ? Icons.arrow_back_rounded
                                : Icons.add_rounded,
                            label: _isAddingAccount ? 'К списку аккаунтов' : 'Добавить почтовый аккаунт',
                            onTap: () => setState(
                              () => _isAddingAccount = !_isAddingAccount,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Bounded scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isAddingAccount)
                            _buildAddAndVerifyForm(palette)
                          else
                            _buildAccountsList(palette),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsList(OrbitPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final acc in _accounts) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrbitSpatialCard(
              key: Key('mail-account-card-${acc.id}'),
              palette: palette,
              radius: _radius * 0.85,
              tintColor: acc.isActive ? palette.accent : null,
              tintIntensity: acc.isActive ? 0.20 : 0.06,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Icon(
                          acc.providerType == OrbitMailProviderType.yandex
                              ? Icons.mail_lock_rounded
                              : Icons.mark_email_read_rounded,
                          size: 20,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    acc.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                                if (acc.isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          palette.accent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'АКТИВЕН',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: palette.accent,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!acc.isActive)
                        OrbitPressable(
                          key: Key('select-mail-account-${acc.id}'),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onSelectActiveAccount(acc.id);
                            setState(() {
                              _accounts = [
                                for (final a in _accounts)
                                  a.copyWith(isActive: a.id == acc.id),
                              ];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    palette.textPrimary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              'Выбрать',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      if (_accounts.length > 1) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          key: Key('remove-mail-account-${acc.id}'),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: palette.textSecondary,
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            widget.onRemoveAccount(acc.id);
                            setState(() {
                              _accounts.removeWhere((a) => a.id == acc.id);
                              if (!_accounts.any((a) => a.isActive) &&
                                  _accounts.isNotEmpty) {
                                _accounts[0] =
                                    _accounts[0].copyWith(isActive: true);
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          acc.status == OrbitMailAccountStatus.verified
                              ? Icons.verified_user_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: acc.status == OrbitMailAccountStatus.verified
                              ? Colors.greenAccent.shade400
                              : Colors.amberAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'IMAP: ${acc.incomingHost}:${acc.incomingPort} • ${acc.useIncomingSsl ? "SSL" : "Plain"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                        if (acc.lastLatencyMs != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${acc.lastLatencyMs} ms',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddAndVerifyForm(OrbitPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ПРОВАЙДЕР ПОЧТЫ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final p in OrbitMailProviderType.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('mail-provider-chip-${p.name}'),
                    selected: _selectedProvider == p,
                    label: Text(p.label),
                    selectedColor: palette.accent.withValues(alpha: 0.28),
                    backgroundColor: palette.surface.withValues(alpha: 0.4),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedProvider == p
                          ? palette.accent
                          : palette.textPrimary,
                    ),
                    side: BorderSide(
                      color: _selectedProvider == p
                          ? palette.accent
                          : Colors.transparent,
                    ),
                    onSelected: (_) => _onProviderChanged(p),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InputBox(
          controller: _nameController,
          label: 'Название ящика',
          icon: Icons.badge_outlined,
          palette: palette,
        ),
        const SizedBox(height: 8),
        _InputBox(
          fieldKey: const Key('mail-account-email-input'),
          controller: _emailController,
          label: 'Адрес e-mail',
          icon: Icons.email_outlined,
          palette: palette,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _InputBox(
                fieldKey: const Key('mail-account-host-input'),
                controller: _hostController,
                label: 'IMAP Сервер',
                icon: Icons.dns_outlined,
                palette: palette,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _InputBox(
                fieldKey: const Key('mail-account-port-input'),
                controller: _portController,
                label: 'Порт',
                icon: Icons.numbers_rounded,
                palette: palette,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Защита соединения (SSL/TLS)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Switch(
              key: const Key('mail-account-ssl-switch'),
              value: _useSsl,
              activeThumbColor: palette.accent,
              onChanged: (val) => setState(() => _useSsl = val),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 4-этапная диагностика сокетов и сертификатов
        OrbitSpatialCard(
          palette: palette,
          radius: _radius * 0.75,
          tintColor: _lastDiagnostic?.isSuccess == true
              ? Colors.greenAccent
              : (_lastDiagnostic != null ? Colors.redAccent : null),
          tintIntensity: 0.12,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.network_check_rounded,
                    size: 18,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Диагностика сокетов IMAP/TLS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (_isVerifying)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_lastDiagnostic != null)
                    Text(
                      _lastDiagnostic!.isSuccess
                          ? '${_lastDiagnostic!.latencyMs} ms • OK'
                          : 'Ошибка',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _lastDiagnostic!.isSuccess
                            ? Colors.greenAccent.shade400
                            : Colors.redAccent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _StageDiagnosticRow(
                stage: MailVerificationStage.resolvingDns,
                currentStage: _currentStage,
                isSuccess: _lastDiagnostic?.isSuccess == true,
                palette: palette,
              ),
              _StageDiagnosticRow(
                stage: MailVerificationStage.connectingTcp,
                currentStage: _currentStage,
                isSuccess: _lastDiagnostic?.isSuccess == true,
                palette: palette,
              ),
              _StageDiagnosticRow(
                stage: MailVerificationStage.performingTlsHandshake,
                currentStage: _currentStage,
                isSuccess: _lastDiagnostic?.isSuccess == true,
                palette: palette,
              ),
              _StageDiagnosticRow(
                stage: MailVerificationStage.readingGreeting,
                currentStage: _currentStage,
                isSuccess: _lastDiagnostic?.isSuccess == true,
                palette: palette,
              ),
              if (_lastDiagnostic != null && !_lastDiagnostic!.isSuccess) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('mail-verification-error-recommendation'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastDiagnostic!.recommendation ??
                              _lastDiagnostic!.errorMessage ??
                              'Ошибка соединения с почтовым сервером',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrbitFilledButton(
              buttonKey: const Key('verify-mail-connection-btn'),
              palette: palette,
              radius: _radius * 0.7,
              isPrimary: false,
              icon: Icons.wifi_protected_setup_rounded,
              label: _isVerifying ? 'Проверка соединения...' : 'Проверить соединение',
              onTap: _isVerifying ? () {} : () => _runLiveVerification(),
            ),
            const SizedBox(height: 10),
            OrbitFilledButton(
              buttonKey: const Key('save-mail-account-btn'),
              palette: palette,
              radius: _radius * 0.7,
              isPrimary: true,
              icon: Icons.check_circle_outline_rounded,
              label: 'Сохранить аккаунт',
              onTap: _isVerifying ? () {} : () => _saveVerifiedAccount(),
            ),
          ],
        ),
      ],
    );
  }
}

final class _StageDiagnosticRow extends StatelessWidget {
  const _StageDiagnosticRow({
    required this.stage,
    required this.currentStage,
    required this.isSuccess,
    required this.palette,
  });

  final MailVerificationStage stage;
  final MailVerificationStage currentStage;
  final bool isSuccess;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    final isDone = isSuccess ||
        (currentStage.index > stage.index &&
            currentStage != MailVerificationStage.failed);
    final isRunning =
        currentStage == stage && currentStage != MailVerificationStage.failed;
    final isFailed = currentStage == stage && !isSuccess;

    Color iconColor;
    IconData iconData;

    if (isDone) {
      iconColor = Colors.greenAccent.shade400;
      iconData = Icons.check_circle_rounded;
    } else if (isRunning) {
      iconColor = palette.accent;
      iconData = Icons.sync_rounded;
    } else if (isFailed) {
      iconColor = Colors.redAccent;
      iconData = Icons.cancel_rounded;
    } else {
      iconColor = palette.textSecondary.withValues(alpha: 0.35);
      iconData = Icons.radio_button_unchecked_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(iconData, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stage.label,
              style: TextStyle(
                fontSize: 12,
                color: isDone || isRunning
                    ? palette.textPrimary
                    : palette.textSecondary,
                fontWeight: isRunning ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.label,
    required this.icon,
    required this.palette,
    this.fieldKey,
    this.keyboardType,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final OrbitPalette palette;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 13, color: palette.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 11,
              color: palette.textSecondary,
            ),
            icon: Icon(icon, size: 16, color: palette.accent),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
