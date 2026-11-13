import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_visual_engine.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_logo.dart';
import '../widgets/orbit_mail_account_sheet.dart';
import '../widgets/orbit_page.dart';
import '../widgets/orbit_photoreal_scene.dart';

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final settings = env.style.settings;
    return OrbitPage(
      title: context.l10n.settings,
      subtitle: context.l10n.settingsSubtitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            palette: palette,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final identity = Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: palette.accent.withValues(alpha: 0.25),
                      child: Text(
                        context.l10n.demoUserInitials,
                        style: TextStyle(color: palette.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.demoUserName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'alexey@example.demo',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth < 430) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 68),
                        child: DemoLabel(palette: palette),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 12),
                    DemoLabel(palette: palette),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.personalization),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: context.l10n.interface,
                  subtitle: palette.name,
                  onTap: () =>
                      context.push('/settings/personalization/interface'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.speed_rounded,
                  title: context.l10n.graphicsQuality,
                  subtitle: settings.quality.localizedSummary(context),
                  onTap: () => context.push('/settings/personalization'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.compare_arrows_rounded,
                  title: 'ORBIT Visual Lab',
                  subtitle: context.l10n.visualLabExperiments,
                  onTap: () => context.push('/settings/lab'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.monitor_heart_outlined,
                  title: context.l10n.diagnostics,
                  subtitle: context.l10n.measurementStatus,
                  onTap: () => context.push('/settings/lab'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.accentColor),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in const [
                  Color(0xFF9B8CFF),
                  Color(0xFF78D9FF),
                  Color(0xFF77D9C2),
                  Color(0xFFFFB68C),
                  Color(0xFFFF9EBD),
                ])
                  OrbitPressable(
                    semanticLabel: context.l10n.accentColorValue(
                      color.toARGB32().toRadixString(16),
                    ),
                    onTap: () => env.style.setAccentColor(color),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              settings.accentColor.toARGB32() ==
                                  color.toARGB32()
                              ? palette.textPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: settings.accentColor.toARGB32() == color.toARGB32()
                          ? Icon(
                              Icons.check_rounded,
                              color: palette.skyTop,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const OrbitSectionTitle('Данные и сервисы'),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Почтовые аккаунты',
                  subtitle: 'Подключение Яндекс, Mail.ru, Gmail, IMAP/SMTP',
                  onTap: () =>
                      showOrbitMailAccountsSheet(context, palette: palette),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.folder_outlined,
                  title: 'Файлы и хранилище',
                  subtitle: 'Квота 50 МБ · локально и вложения',
                  onTap: () => context.push('/files'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'Заметки',
                  subtitle: 'Теги, Markdown-разметка и поиск',
                  onTap: () => context.push('/notes'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Контакты',
                  subtitle: 'Адресная книга и быстрый вызов',
                  onTap: () => context.push('/contacts'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.search_rounded,
                  title: 'Сквозной поиск',
                  subtitle: 'Индексация писем, событий, задач',
                  onTap: () => context.push('/search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.system),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.language_rounded,
                  title: context.l10n.language,
                  subtitle:
                      '${localizedLanguageName(context, settings.languageCode)} · ${settings.languageCode}',
                  onTap: () => _chooseLanguage(context),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'ORBIT Brain',
                  subtitle: context.l10n.brainDemoSubtitle,
                  onTap: () => context.push('/brain'),
                ),
                const Divider(height: 1, indent: 54),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: context.l10n.aboutVisualLab,
                  subtitle: context.l10n.versionLabel,
                  onTap: () => _about(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _chooseLanguage(BuildContext context) {
    final env = OrbitEnvironment.read(context);
    const codes = ['ru', 'en', 'de', 'fr', 'es'];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.language),
        scrollable: true,
        content: RadioGroup<String>(
          groupValue: env.style.settings.languageCode,
          onChanged: (value) {
            if (value == null) return;
            env.style.setLanguage(value);
            Navigator.of(dialogContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in codes)
                RadioListTile<String>(
                  key: Key('language-$code'),
                  value: code,
                  title: Text(localizedLanguageName(context, code)),
                  subtitle: Text(code),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ORBIT',
      applicationVersion: '0.5.30+36',
      applicationLegalese: context.l10n.aboutLegalese,
      children: [const SizedBox(height: 12), Text(context.l10n.aboutTech)],
    );
  }
}

final class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final settings = env.style.settings;
    return OrbitPage(
      title: context.l10n.personalization,
      subtitle: context.l10n.settingsSaved,
      reduceEffects: true,
      leading: OrbitBackButton(onTap: () => context.pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            palette: palette,
            onTap: () => context.push('/settings/personalization/interface'),
            child: Row(
              children: [
                OrbitLogo(
                  palette: palette,
                  size: 44,
                  animate:
                      settings.motionEnabled &&
                      env.resolvedQuality != ResolvedQuality.static,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.interfaceGallery,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${palette.name} · ${context.l10n.livePreview}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.graphicsQuality),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            padding: const EdgeInsets.all(10),
            child: RadioGroup<OrbitQuality>(
              groupValue: settings.quality,
              onChanged: (value) {
                if (value != null) env.style.setQuality(value);
              },
              child: Column(
                children: [
                  for (final quality in OrbitQuality.values)
                    RadioListTile<OrbitQuality>(
                      key: Key('quality-${quality.name}'),
                      value: quality,
                      title: Text(switch (quality) {
                        OrbitQuality.auto => 'Auto',
                        OrbitQuality.eco => 'Eco',
                        OrbitQuality.balanced => 'Balanced',
                        OrbitQuality.ultra => 'Ultra',
                      }),
                      subtitle: Text(switch (quality) {
                        OrbitQuality.auto =>
                          context.l10n.qualityAutoDescription,
                        OrbitQuality.eco => context.l10n.qualityEcoDescription,
                        OrbitQuality.balanced =>
                          context.l10n.qualityBalancedDescription,
                        OrbitQuality.ultra =>
                          context.l10n.qualityUltraDescription,
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.theme),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in ThemeMode.values)
                  ChoiceChip(
                    key: Key('theme-${mode.name}'),
                    selected: settings.themeMode == mode,
                    onSelected: (_) => env.style.setThemeMode(mode),
                    label: Text(switch (mode) {
                      ThemeMode.system => context.l10n.themeSystem,
                      ThemeMode.light => context.l10n.themeLight,
                      ThemeMode.dark => context.l10n.themeDark,
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.interfaceAndMotion),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('motion-switch'),
                  title: Text(context.l10n.uiAnimations),
                  subtitle: Text(context.l10n.animationsDisableNotice),
                  value: settings.motionEnabled,
                  onChanged: env.style.setMotionEnabled,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.gyroIntensity,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.gyroIntensityDesc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        key: const Key('gyro-switch'),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final intensity in GyroIntensity.values)
                            ChoiceChip(
                              key: Key('gyro-${intensity.name}'),
                              selected: settings.gyroIntensity == intensity,
                              onSelected: (_) =>
                                  env.style.setGyroIntensity(intensity),
                              label: Text(switch (intensity) {
                                GyroIntensity.off => context.l10n.gyroOff,
                                GyroIntensity.subtle => context.l10n.gyroSubtle,
                                GyroIntensity.enhanced =>
                                  context.l10n.gyroEnhanced,
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.density,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final density in OrbitDensity.values)
                            ChoiceChip(
                              key: Key('density-${density.name}'),
                              selected: settings.density == density,
                              onSelected: (_) => env.style.setDensity(density),
                              label: Text(
                                density == OrbitDensity.comfortable
                                    ? context.l10n.comfortable
                                    : context.l10n.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.textSize,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (index, scale) in const [
                            (0, 1.0),
                            (1, 1.15),
                            (2, 1.3),
                          ])
                            ChoiceChip(
                              key: Key('text-scale-$index'),
                              selected: settings.textScale == scale,
                              onSelected: (_) => env.style.setTextScale(scale),
                              label: Text(switch (index) {
                                0 => context.l10n.textSizeStandard,
                                1 => context.l10n.textSizeLarge,
                                _ => context.l10n.textSizeExtraLarge,
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OrbitSectionTitle(context.l10n.lightingAndAtmosphere),
          const SizedBox(height: 10),
          GlassPanel(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.lightingAndAtmosphereDesc,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in AtmosphereMode.values)
                      ChoiceChip(
                        key: Key('atmo-${mode.name}'),
                        selected: settings.atmosphereMode == mode,
                        onSelected: (_) => env.style.setAtmosphereMode(mode),
                        label: Text(switch (mode) {
                          AtmosphereMode.automatic =>
                            context.l10n.atmosphereAuto,
                          AtmosphereMode.dawn => context.l10n.atmosphereDawn,
                          AtmosphereMode.day => context.l10n.atmosphereDay,
                          AtmosphereMode.sunset =>
                            context.l10n.atmosphereSunset,
                          AtmosphereMode.night => context.l10n.atmosphereNight,
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.systemLimits(
              env.quality.powerSaveMode
                  ? context.l10n.enabled
                  : context.l10n.notDetected,
              env.quality.lowMemory
                  ? context.l10n.present
                  : context.l10n.absent,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

final class InterfaceGalleryScreen extends StatefulWidget {
  const InterfaceGalleryScreen({super.key});

  @override
  State<InterfaceGalleryScreen> createState() => _InterfaceGalleryScreenState();
}

final class _InterfaceGalleryScreenState extends State<InterfaceGalleryScreen> {
  int _selectedTab = 0;
  bool _searchActive = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final settings = env.style.settings;

    return OrbitPage(
      title: context.l10n.interface,
      subtitle: context.l10n.interfaceBreadcrumb,
      leading: OrbitBackButton(onTap: () => context.pop()),
      actions: [
        OrbitIconButton(
          key: const Key('gallery-search-button'),
          palette: palette,
          icon: _searchActive ? Icons.close_rounded : Icons.search_rounded,
          tooltip: _searchActive ? 'Закрыть поиск' : 'Поиск',
          onTap: () {
            setState(() {
              _searchActive = !_searchActive;
              if (!_searchActive) _searchQuery = '';
            });
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchActive) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                key: const Key('gallery-search-input'),
                autofocus: true,
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim().toLowerCase()),
                style: TextStyle(color: palette.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Поиск профилей (One, Atelier, Flow, Zen)...',
                  hintStyle: TextStyle(color: palette.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: palette.surface.withValues(alpha: 0.8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: palette.textSecondary.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Top capsule tabs: Интерфейс / Тема / Система
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (index, label) in [
                  (0, context.l10n.interface),
                  (1, context.l10n.theme),
                  (2, context.l10n.system),
                ]) ...[
                  if (index > 0) const SizedBox(width: 8),
                  OrbitPressable(
                    semanticLabel: label,
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedTab == index
                            ? palette.accent
                            : palette.surface.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedTab == index
                              ? palette.accent
                              : palette.textPrimary.withValues(alpha: 0.08),
                        ),
                        boxShadow: _selectedTab == index
                            ? [
                                BoxShadow(
                                  color: palette.accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: _selectedTab == index
                              ? Colors.white
                              : palette.textSecondary,
                          fontWeight: _selectedTab == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedTab == 0) ...[
            OrbitSectionTitle(context.l10n.interfaceGallery),
            const SizedBox(height: 10),
            Column(
              key: const Key('interface-gallery'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final profile in OrbitProfile.values.where(
                  (p) =>
                      _searchQuery.isEmpty ||
                      p.name.toLowerCase().contains(_searchQuery),
                ))
                  _ProfilePreviewCard(
                    profile: profile,
                    selected: settings.profile == profile,
                    quality: env.resolvedQuality,
                    motionEnabled: settings.motionEnabled,
                    onTap: () => env.style.setProfile(profile),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            OrbitSectionTitle(context.l10n.accentColor),
            const SizedBox(height: 10),
            GlassPanel(
              palette: palette,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in const [
                    Color(0xFF9B8CFF),
                    Color(0xFF78D9FF),
                    Color(0xFF77D9C2),
                    Color(0xFF8EE085),
                    Color(0xFFFFD166),
                    Color(0xFFFFB68C),
                    Color(0xFFFF9EBD),
                  ])
                    OrbitPressable(
                      semanticLabel: context.l10n.accentColorValue(
                        color.toARGB32().toRadixString(16),
                      ),
                      onTap: () => env.style.setAccentColor(color),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                settings.accentColor.toARGB32() ==
                                    color.toARGB32()
                                ? palette.textPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow:
                              settings.accentColor.toARGB32() ==
                                  color.toARGB32()
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child:
                            settings.accentColor.toARGB32() == color.toARGB32()
                            ? Icon(
                                Icons.check_rounded,
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ] else if (_selectedTab == 1) ...[
            OrbitSectionTitle(context.l10n.theme),
            const SizedBox(height: 10),
            GlassPanel(
              palette: palette,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in ThemeMode.values)
                    ChoiceChip(
                      key: Key('theme-${mode.name}'),
                      selected: settings.themeMode == mode,
                      onSelected: (_) => env.style.setThemeMode(mode),
                      label: Text(switch (mode) {
                        ThemeMode.system => context.l10n.themeSystem,
                        ThemeMode.light => context.l10n.themeLight,
                        ThemeMode.dark => context.l10n.themeDark,
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OrbitSectionTitle(context.l10n.lightingAndAtmosphere),
            const SizedBox(height: 10),
            GlassPanel(
              palette: palette,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in AtmosphereMode.values)
                    ChoiceChip(
                      key: Key('atmo-${mode.name}'),
                      selected: settings.atmosphereMode == mode,
                      onSelected: (_) => env.style.setAtmosphereMode(mode),
                      label: Text(switch (mode) {
                        AtmosphereMode.automatic => context.l10n.atmosphereAuto,
                        AtmosphereMode.dawn => context.l10n.atmosphereDawn,
                        AtmosphereMode.day => context.l10n.atmosphereDay,
                        AtmosphereMode.sunset => context.l10n.atmosphereSunset,
                        AtmosphereMode.night => context.l10n.atmosphereNight,
                      }),
                    ),
                ],
              ),
            ),
          ] else ...[
            OrbitSectionTitle(context.l10n.graphicsQuality),
            const SizedBox(height: 10),
            GlassPanel(
              palette: palette,
              padding: const EdgeInsets.all(10),
              child: RadioGroup<OrbitQuality>(
                groupValue: settings.quality,
                onChanged: (value) {
                  if (value != null) env.style.setQuality(value);
                },
                child: Column(
                  children: [
                    for (final quality in OrbitQuality.values)
                      RadioListTile<OrbitQuality>(
                        key: Key('quality-${quality.name}'),
                        value: quality,
                        title: Text(switch (quality) {
                          OrbitQuality.auto => 'Auto',
                          OrbitQuality.eco => 'Eco',
                          OrbitQuality.balanced => 'Balanced',
                          OrbitQuality.ultra => 'Ultra',
                        }),
                        subtitle: Text(switch (quality) {
                          OrbitQuality.auto =>
                            context.l10n.qualityAutoDescription,
                          OrbitQuality.eco =>
                            context.l10n.qualityEcoDescription,
                          OrbitQuality.balanced =>
                            context.l10n.qualityBalancedDescription,
                          OrbitQuality.ultra =>
                            context.l10n.qualityUltraDescription,
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            OrbitSectionTitle(context.l10n.interfaceAndMotion),
            const SizedBox(height: 10),
            GlassPanel(
              palette: palette,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('motion-switch'),
                    title: Text(context.l10n.uiAnimations),
                    subtitle: Text(context.l10n.animationsDisableNotice),
                    value: settings.motionEnabled,
                    onChanged: env.style.setMotionEnabled,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.density,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final density in OrbitDensity.values)
                              ChoiceChip(
                                key: Key('density-${density.name}'),
                                selected: settings.density == density,
                                onSelected: (_) =>
                                    env.style.setDensity(density),
                                label: Text(
                                  density == OrbitDensity.comfortable
                                      ? context.l10n.comfortable
                                      : context.l10n.compact,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({
    required this.profile,
    required this.selected,
    required this.quality,
    required this.motionEnabled,
    required this.onTap,
  });

  final OrbitProfile profile;
  final bool selected;
  final ResolvedQuality quality;
  final bool motionEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrbitPalette.of(profile);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OrbitPressable(
        semanticLabel: context.l10n.selectProfile(palette.name),
        onTap: onTap,
        child: Container(
          key: Key('profile-${profile.name}'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? palette.accent.withValues(alpha: 0.16)
                : palette.surface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : palette.accent.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 80,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      OrbitPhotorealScene(
                        palette: palette,
                        quality: ResolvedQuality.static,
                        motionEnabled: false,
                        settings: OrbitEnvironment.of(context).style.settings,
                        active: true,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              palette.skyTop.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      palette.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                        fontFamily: palette.serif ? 'OrbitSerif' : 'OrbitSans',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      palette.localizedSubtitle(context),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? palette.accent : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? palette.accent
                        : palette.textPrimary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: Key('settings-$title'),
        onTap: onTap,
        contentPadding: largeText
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : null,
        leading: Icon(icon),
        title: Text(
          title,
          maxLines: largeText ? 3 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: largeText ? 4 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: largeText,
        trailing: largeText ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
