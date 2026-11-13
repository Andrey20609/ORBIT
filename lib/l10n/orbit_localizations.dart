import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_day_period.dart';
import '../visual_engine/orbit_palette.dart';
import 'app_localizations.dart';
import 'app_localizations_ru.dart';

extension OrbitLocalizationContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsRu();
}

extension DemoEmailLocalization on DemoEmail {
  String localizedSender(BuildContext context) => switch (id) {
    'weekly-plan' => context.l10n.emailWeeklySender,
    'design-review' => context.l10n.emailDesignSender,
    'project-update' => context.l10n.emailProjectSender,
    'research-notes' => context.l10n.emailResearchSender,
    _ => sender,
  };

  String localizedSubject(BuildContext context) => switch (id) {
    'weekly-plan' => context.l10n.emailWeeklySubject,
    'design-review' => context.l10n.emailDesignSubject,
    'project-update' => context.l10n.emailProjectSubject,
    'research-notes' => context.l10n.emailResearchSubject,
    'focus-notes' => context.l10n.emailFocusSubject,
    _ => subject,
  };

  String localizedPreview(BuildContext context) => switch (id) {
    'weekly-plan' => context.l10n.emailWeeklyPreview,
    'design-review' => context.l10n.emailDesignPreview,
    'project-update' => context.l10n.emailProjectPreview,
    'research-notes' => context.l10n.emailResearchPreview,
    'focus-notes' => context.l10n.emailFocusPreview,
    _ => preview,
  };

  String localizedBody(BuildContext context) => switch (id) {
    'weekly-plan' => context.l10n.emailWeeklyBody,
    'design-review' => context.l10n.emailDesignBody,
    'project-update' => context.l10n.emailProjectBody,
    'research-notes' => context.l10n.emailResearchBody,
    'focus-notes' => context.l10n.emailFocusBody,
    _ => body,
  };

  String localizedTime(BuildContext context) => switch (time) {
    'Вчера' => context.l10n.yesterday,
    'Пн' => context.l10n.mondayShort,
    _ => time,
  };

  String localizedAttachment(BuildContext context, int index) {
    if (id == 'weekly-plan') {
      return index == 0
          ? context.l10n.attachmentWeekPlan
          : context.l10n.attachmentSchedule;
    }
    if (id == 'project-update') return context.l10n.attachmentPresentation;
    return attachments[index];
  }
}

extension DemoEventLocalization on DemoEvent {
  String localizedTitle(BuildContext context) => switch (id) {
    'review' => context.l10n.eventReviewTitle,
    'audit' => context.l10n.eventAuditTitle,
    'report' => context.l10n.eventReportTitle,
    _ => title,
  };

  String localizedMeta(BuildContext context) => switch (id) {
    'review' => context.l10n.eventReviewMeta,
    'audit' => context.l10n.eventAuditMeta,
    'report' => context.l10n.eventReportMeta,
    _ => meta,
  };
}

extension DemoTaskLocalization on DemoTask {
  String localizedTitle(BuildContext context) => switch (id) {
    'report' => context.l10n.taskReportTitle,
    'plan' => context.l10n.taskPlanTitle,
    'materials' => context.l10n.taskMaterialsTitle,
    'data' => context.l10n.taskDataTitle,
    _ => title,
  };

  String localizedProject(BuildContext context) => switch (project) {
    'Стратегия' => context.l10n.projectStrategy,
    'ВП' => context.l10n.projectVp,
    'ВП / БАМ' => context.l10n.projectVpBam,
    'local-list' => context.l10n.localList,
    'Локальный список' => context.l10n.localList,
    _ => project,
  };

  String localizedDue(BuildContext context) {
    if (due == 'no-due') return context.l10n.noDue;
    if (due == 'Выполнено') return context.l10n.done;
    if (due == 'Завтра') return context.l10n.tomorrow;
    if (due == '5 ноября') return context.l10n.dateNovember5;
    if (due.startsWith('Сегодня, ')) {
      return context.l10n.todayTime(due.substring('Сегодня, '.length));
    }
    return due;
  }
}

extension OrbitPaletteLocalization on OrbitPalette {
  String localizedSubtitle(BuildContext context) => switch (profile) {
    OrbitProfile.one => context.l10n.profileOneSubtitle,
    OrbitProfile.atelier => context.l10n.profileAtelierSubtitle,
    OrbitProfile.flow => context.l10n.profileFlowSubtitle,
    OrbitProfile.zen => context.l10n.profileZenSubtitle,
  };
}

extension OrbitQualityLocalization on OrbitQuality {
  String localizedSummary(BuildContext context) => switch (this) {
    OrbitQuality.auto => context.l10n.qualityAutoSummary,
    OrbitQuality.eco => context.l10n.qualityEcoSummary,
    OrbitQuality.balanced => context.l10n.qualityBalancedSummary,
    OrbitQuality.ultra => context.l10n.qualityUltraSummary,
  };

  String localizedDescription(BuildContext context) => switch (this) {
    OrbitQuality.auto => context.l10n.qualityAutoDescription,
    OrbitQuality.eco => context.l10n.qualityEcoDescription,
    OrbitQuality.balanced => context.l10n.qualityBalancedDescription,
    OrbitQuality.ultra => context.l10n.qualityUltraDescription,
  };
}

String localizedLanguageName(BuildContext context, String code) =>
    switch (code) {
      'ru' => context.l10n.languageRussian,
      'en' => context.l10n.languageEnglish,
      'de' => context.l10n.languageGerman,
      'fr' => context.l10n.languageFrench,
      'es' => context.l10n.languageSpanish,
      _ => code,
    };

extension OrbitDayPeriodLocalization on OrbitDayPeriod {
  String localizedGreeting(BuildContext context, {bool short = true}) {
    final l10n = context.l10n;
    if (short) {
      return switch (this) {
        OrbitDayPeriod.morning => l10n.greetingMorningShort,
        OrbitDayPeriod.day => l10n.greetingDayShort,
        OrbitDayPeriod.evening => l10n.greetingEveningShort,
        OrbitDayPeriod.night => l10n.greetingNightShort,
      };
    } else {
      return switch (this) {
        OrbitDayPeriod.morning => l10n.greetingMorning,
        OrbitDayPeriod.day => l10n.greetingDay,
        OrbitDayPeriod.evening => l10n.greetingEvening,
        OrbitDayPeriod.night => l10n.greetingNight,
      };
    }
  }
}

