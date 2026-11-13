import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'ORBIT Visual Lab'**
  String get appName;

  /// No description provided for @today.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get today;

  /// No description provided for @mail.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get mail;

  /// No description provided for @calendar.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get calendar;

  /// No description provided for @tasks.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get tasks;

  /// No description provided for @more.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @inbox.
  ///
  /// In ru, this message translates to:
  /// **'Входящие'**
  String get inbox;

  /// No description provided for @newEmail.
  ///
  /// In ru, this message translates to:
  /// **'Новое письмо'**
  String get newEmail;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @all.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get all;

  /// No description provided for @important.
  ///
  /// In ru, this message translates to:
  /// **'Важные'**
  String get important;

  /// No description provided for @importantSingle.
  ///
  /// In ru, this message translates to:
  /// **'Важное'**
  String get importantSingle;

  /// No description provided for @emptyHere.
  ///
  /// In ru, this message translates to:
  /// **'Здесь пока пусто'**
  String get emptyHere;

  /// No description provided for @unreadSummary.
  ///
  /// In ru, this message translates to:
  /// **'{count} непрочитанных · демонстрационная почта'**
  String unreadSummary(int count);

  /// No description provided for @mailDemoNotice.
  ///
  /// In ru, this message translates to:
  /// **'Свайп и серверные действия отключены: данные существуют только в этой демонстрации.'**
  String get mailDemoNotice;

  /// No description provided for @toMe.
  ///
  /// In ru, this message translates to:
  /// **'Кому: мне · {email}'**
  String toMe(String email);

  /// No description provided for @attachments.
  ///
  /// In ru, this message translates to:
  /// **'Вложения'**
  String get attachments;

  /// No description provided for @demoAttachment.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационное вложение'**
  String get demoAttachment;

  /// No description provided for @demoAttachmentNotice.
  ///
  /// In ru, this message translates to:
  /// **'Файл является демонстрационной записью и не загружается.'**
  String get demoAttachmentNotice;

  /// No description provided for @reply.
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get reply;

  /// No description provided for @replyAll.
  ///
  /// In ru, this message translates to:
  /// **'Всем'**
  String get replyAll;

  /// No description provided for @forward.
  ///
  /// In ru, this message translates to:
  /// **'Переслать'**
  String get forward;

  /// No description provided for @draftSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Автономный черновик · отправка отключена'**
  String get draftSubtitle;

  /// No description provided for @saveDraft.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить черновик'**
  String get saveDraft;

  /// No description provided for @draftSaved.
  ///
  /// In ru, this message translates to:
  /// **'Черновик сохранён локально. Письмо не отправлено.'**
  String get draftSaved;

  /// No description provided for @draftUnsavedChanges.
  ///
  /// In ru, this message translates to:
  /// **'есть несохранённые изменения'**
  String get draftUnsavedChanges;

  /// No description provided for @draftSavedState.
  ///
  /// In ru, this message translates to:
  /// **'все изменения сохранены'**
  String get draftSavedState;

  /// No description provided for @to.
  ///
  /// In ru, this message translates to:
  /// **'Кому'**
  String get to;

  /// No description provided for @subject.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get subject;

  /// No description provided for @subjectHint.
  ///
  /// In ru, this message translates to:
  /// **'О чём письмо'**
  String get subjectHint;

  /// No description provided for @bodyHint.
  ///
  /// In ru, this message translates to:
  /// **'Текст письма…'**
  String get bodyHint;

  /// No description provided for @formatting.
  ///
  /// In ru, this message translates to:
  /// **'Форматирование недоступно в DEMO'**
  String get formatting;

  /// No description provided for @attachmentsDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Вложения отключены'**
  String get attachmentsDisabled;

  /// No description provided for @localFilesDisabled.
  ///
  /// In ru, this message translates to:
  /// **'В Visual Lab нельзя прикреплять локальные файлы.'**
  String get localFilesDisabled;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get add;

  /// No description provided for @understood.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get understood;

  /// No description provided for @demoLabel.
  ///
  /// In ru, this message translates to:
  /// **'ДЕМО · ЛОКАЛЬНЫЕ ДАННЫЕ'**
  String get demoLabel;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @notificationsDemo.
  ///
  /// In ru, this message translates to:
  /// **'Серверные уведомления не подключены в Visual Lab.'**
  String get notificationsDemo;

  /// No description provided for @goodMorning.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро,\nАлексей!'**
  String get goodMorning;

  /// No description provided for @dateFocus.
  ///
  /// In ru, this message translates to:
  /// **'{date} · спокойный фокус'**
  String dateFocus(String date);

  /// No description provided for @newMetric.
  ///
  /// In ru, this message translates to:
  /// **'новых'**
  String get newMetric;

  /// No description provided for @eventsMetric.
  ///
  /// In ru, this message translates to:
  /// **'события'**
  String get eventsMetric;

  /// No description provided for @tasksMetric.
  ///
  /// In ru, this message translates to:
  /// **'задачи'**
  String get tasksMetric;

  /// No description provided for @upcoming.
  ///
  /// In ru, this message translates to:
  /// **'Ближайшее'**
  String get upcoming;

  /// No description provided for @actionCenter.
  ///
  /// In ru, this message translates to:
  /// **'Центр действий'**
  String get actionCenter;

  /// No description provided for @dayRhythm.
  ///
  /// In ru, this message translates to:
  /// **'ритм дня'**
  String get dayRhythm;

  /// No description provided for @yourSpace.
  ///
  /// In ru, this message translates to:
  /// **'Ваше пространство'**
  String get yourSpace;

  /// No description provided for @completedSummary.
  ///
  /// In ru, this message translates to:
  /// **'{completed} из {total} задач завершено. Следующий спокойный интервал — после 13:30.'**
  String completedSummary(int completed, int total);

  /// No description provided for @flow.
  ///
  /// In ru, this message translates to:
  /// **'Поток'**
  String get flow;

  /// No description provided for @focus.
  ///
  /// In ru, this message translates to:
  /// **'Фокус'**
  String get focus;

  /// No description provided for @emailAction.
  ///
  /// In ru, this message translates to:
  /// **'Письмо'**
  String get emailAction;

  /// No description provided for @taskAction.
  ///
  /// In ru, this message translates to:
  /// **'Задача'**
  String get taskAction;

  /// No description provided for @eventAction.
  ///
  /// In ru, this message translates to:
  /// **'Событие'**
  String get eventAction;

  /// No description provided for @experimentRive.
  ///
  /// In ru, this message translates to:
  /// **'EXPERIMENT B · RIVE'**
  String get experimentRive;

  /// No description provided for @experimentFilament.
  ///
  /// In ru, this message translates to:
  /// **'EXPERIMENT C · FILAMENT'**
  String get experimentFilament;

  /// No description provided for @liveBrandScene.
  ///
  /// In ru, this message translates to:
  /// **'Интерактивная атмосфера'**
  String get liveBrandScene;

  /// No description provided for @pbrScene.
  ///
  /// In ru, this message translates to:
  /// **'Настоящая PBR-сцена'**
  String get pbrScene;

  /// No description provided for @compareRenderers.
  ///
  /// In ru, this message translates to:
  /// **'Сравнить рендеры →'**
  String get compareRenderers;

  /// No description provided for @graphicsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Графический рендер недоступен. Включён Static/Eco; интерфейс продолжает работать.\n{reason}'**
  String graphicsUnavailable(String reason);

  /// No description provided for @filamentUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Filament доступен в Android-сборке. На этой платформе включён статический/процедурный резервный рендер.'**
  String get filamentUnsupported;

  /// No description provided for @riveAtmosphereSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Интерактивная Rive-сцена ORBIT. Коснитесь, чтобы запустить импульс.'**
  String get riveAtmosphereSemantics;

  /// No description provided for @riveMarkSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Анимированный логотип ORBIT. Коснитесь, чтобы запустить импульс.'**
  String get riveMarkSemantics;

  /// No description provided for @activeRenderer.
  ///
  /// In ru, this message translates to:
  /// **'Активный рендер'**
  String get activeRenderer;

  /// No description provided for @rendererDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выбор применяется сразу и сохраняется. Маршрут и демонстрационные данные не сбрасываются.'**
  String get rendererDescription;

  /// No description provided for @staticRendererTitle.
  ///
  /// In ru, this message translates to:
  /// **'A · Static / Eco'**
  String get staticRendererTitle;

  /// No description provided for @staticRendererSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Детализированная статическая Flutter/Impeller-сцена без непрерывного кадрового цикла.'**
  String get staticRendererSubtitle;

  /// No description provided for @riveRendererTitle.
  ///
  /// In ru, this message translates to:
  /// **'B · Flutter + Impeller + Rive'**
  String get riveRendererTitle;

  /// No description provided for @riveRendererSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Атмосферный ландшафт, орбитальная анимация и Rive trigger Pulse по касанию.'**
  String get riveRendererSubtitle;

  /// No description provided for @filamentRendererTitle.
  ///
  /// In ru, this message translates to:
  /// **'C · Flutter + native Google Filament'**
  String get filamentRendererTitle;

  /// No description provided for @filamentRendererSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Нативный Android SurfaceView, PBR-рельеф, солнце, облака и камера.'**
  String get filamentRendererSubtitle;

  /// No description provided for @visualLabSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сравнение рендеров на одном экране «Сегодня»'**
  String get visualLabSubtitle;

  /// No description provided for @openToday.
  ///
  /// In ru, this message translates to:
  /// **'Открыть «Сегодня»'**
  String get openToday;

  /// No description provided for @measurementStatus.
  ///
  /// In ru, this message translates to:
  /// **'Состояние измерений'**
  String get measurementStatus;

  /// No description provided for @frameMetrics.
  ///
  /// In ru, this message translates to:
  /// **'FPS / P95 frame time'**
  String get frameMetrics;

  /// No description provided for @resourceMetrics.
  ///
  /// In ru, this message translates to:
  /// **'RAM / GPU / энергия / нагрев'**
  String get resourceMetrics;

  /// No description provided for @physicalRun.
  ///
  /// In ru, this message translates to:
  /// **'Запуск на реальном устройстве'**
  String get physicalRun;

  /// No description provided for @performanceMethod.
  ///
  /// In ru, this message translates to:
  /// **'Для честного сравнения нужны profile/release-сборки на одном физическом Android-устройстве. Методика и команды находятся в docs/PERFORMANCE.md.'**
  String get performanceMethod;

  /// No description provided for @graphicsLog.
  ///
  /// In ru, this message translates to:
  /// **'Журнал графического fallback'**
  String get graphicsLog;

  /// No description provided for @nativePbr.
  ///
  /// In ru, this message translates to:
  /// **'NATIVE · PBR'**
  String get nativePbr;

  /// No description provided for @androidFallback.
  ///
  /// In ru, this message translates to:
  /// **'ANDROID ONLY · FALLBACK'**
  String get androidFallback;

  /// No description provided for @day.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get day;

  /// No description provided for @week.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get week;

  /// No description provided for @month.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get month;

  /// No description provided for @agenda.
  ///
  /// In ru, this message translates to:
  /// **'Повестка'**
  String get agenda;

  /// No description provided for @allUpcoming.
  ///
  /// In ru, this message translates to:
  /// **'Все ближайшие события'**
  String get allUpcoming;

  /// No description provided for @freeTomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра свободно после 16:00 — хорошее время для спокойной работы.'**
  String get freeTomorrow;

  /// No description provided for @morning.
  ///
  /// In ru, this message translates to:
  /// **'утро'**
  String get morning;

  /// No description provided for @events.
  ///
  /// In ru, this message translates to:
  /// **'события'**
  String get events;

  /// No description provided for @focusHours.
  ///
  /// In ru, this message translates to:
  /// **'часа фокуса'**
  String get focusHours;

  /// No description provided for @progressDay.
  ///
  /// In ru, this message translates to:
  /// **'Прогресс дня'**
  String get progressDay;

  /// No description provided for @active.
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get active;

  /// No description provided for @projects.
  ///
  /// In ru, this message translates to:
  /// **'Проекты'**
  String get projects;

  /// No description provided for @addTask.
  ///
  /// In ru, this message translates to:
  /// **'Добавить задачу'**
  String get addTask;

  /// No description provided for @quickAdd.
  ///
  /// In ru, this message translates to:
  /// **'Быстрое добавление'**
  String get quickAdd;

  /// No description provided for @newTask.
  ///
  /// In ru, this message translates to:
  /// **'Новая задача'**
  String get newTask;

  /// No description provided for @taskHint.
  ///
  /// In ru, this message translates to:
  /// **'Что нужно сделать?'**
  String get taskHint;

  /// No description provided for @completedOf.
  ///
  /// In ru, this message translates to:
  /// **'{completed} из {total} завершено · локальная логика'**
  String completedOf(int completed, int total);

  /// No description provided for @localList.
  ///
  /// In ru, this message translates to:
  /// **'Локальный список'**
  String get localList;

  /// No description provided for @settingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Персональное пространство · Visual Lab'**
  String get settingsSubtitle;

  /// No description provided for @personalization.
  ///
  /// In ru, this message translates to:
  /// **'Персонализация'**
  String get personalization;

  /// No description provided for @interface.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс'**
  String get interface;

  /// No description provided for @graphicsQuality.
  ///
  /// In ru, this message translates to:
  /// **'Качество графики'**
  String get graphicsQuality;

  /// No description provided for @visualLabExperiments.
  ///
  /// In ru, this message translates to:
  /// **'Static · Rive · Filament · режимы A/B/C'**
  String get visualLabExperiments;

  /// No description provided for @accentColor.
  ///
  /// In ru, this message translates to:
  /// **'Акцентный цвет'**
  String get accentColor;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @density.
  ///
  /// In ru, this message translates to:
  /// **'Плотность'**
  String get density;

  /// No description provided for @motion.
  ///
  /// In ru, this message translates to:
  /// **'Движение'**
  String get motion;

  /// No description provided for @routeNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут не найден'**
  String get routeNotFound;

  /// No description provided for @routeStateSaved.
  ///
  /// In ru, this message translates to:
  /// **'Состояние оболочки сохранено. Вернитесь на главный экран.'**
  String get routeStateSaved;

  /// No description provided for @yesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterday;

  /// No description provided for @mondayShort.
  ///
  /// In ru, this message translates to:
  /// **'Пн'**
  String get mondayShort;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено'**
  String get done;

  /// No description provided for @tomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get tomorrow;

  /// No description provided for @todayTime.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня, {time}'**
  String todayTime(String time);

  /// No description provided for @dateNovember5.
  ///
  /// In ru, this message translates to:
  /// **'5 ноября'**
  String get dateNovember5;

  /// No description provided for @system.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get system;

  /// No description provided for @languageRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageEnglish.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In ru, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageFrench.
  ///
  /// In ru, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageSpanish.
  ///
  /// In ru, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @brainDemoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрация будущего помощника · локальные сценарии'**
  String get brainDemoSubtitle;

  /// No description provided for @brainGreeting.
  ///
  /// In ru, this message translates to:
  /// **'Чем помочь сегодня?'**
  String get brainGreeting;

  /// No description provided for @brainNotice.
  ///
  /// In ru, this message translates to:
  /// **'Никаких сетевых запросов: выберите один из заранее подготовленных сценариев.'**
  String get brainNotice;

  /// No description provided for @brainPromptInbox.
  ///
  /// In ru, this message translates to:
  /// **'Разобрать входящие'**
  String get brainPromptInbox;

  /// No description provided for @brainPromptPlan.
  ///
  /// In ru, this message translates to:
  /// **'Сформировать план дня'**
  String get brainPromptPlan;

  /// No description provided for @brainPromptReport.
  ///
  /// In ru, this message translates to:
  /// **'Подготовить отчёт'**
  String get brainPromptReport;

  /// No description provided for @brainResponseInbox.
  ///
  /// In ru, this message translates to:
  /// **'Локальный демо-сценарий: сначала два непрочитанных письма, затем план на неделю. Это не анализ реальной почты.'**
  String get brainResponseInbox;

  /// No description provided for @brainResponsePlan.
  ///
  /// In ru, this message translates to:
  /// **'Локальный демо-сценарий: 10:00 — встреча, 13:30 — аудит, после 14:30 — спокойный фокус. Данные взяты из демонстрационного календаря.'**
  String get brainResponsePlan;

  /// No description provided for @brainResponseReport.
  ///
  /// In ru, this message translates to:
  /// **'Локальный демо-сценарий: структура отчёта — цель, результат, риски, следующий шаг. Текст не отправлялся в ИИ-сервис.'**
  String get brainResponseReport;

  /// No description provided for @demoResponse.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационный ответ'**
  String get demoResponse;

  /// No description provided for @createTask.
  ///
  /// In ru, this message translates to:
  /// **'Создать задачу'**
  String get createTask;

  /// No description provided for @localDraft.
  ///
  /// In ru, this message translates to:
  /// **'Локальный черновик'**
  String get localDraft;

  /// No description provided for @toLocalList.
  ///
  /// In ru, this message translates to:
  /// **'В локальный список'**
  String get toLocalList;

  /// No description provided for @openCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Открыть календарь'**
  String get openCalendar;

  /// No description provided for @demoAssistant.
  ///
  /// In ru, this message translates to:
  /// **'Демонстрационный помощник'**
  String get demoAssistant;

  /// No description provided for @quickActions.
  ///
  /// In ru, this message translates to:
  /// **'Быстрые действия'**
  String get quickActions;

  /// No description provided for @quickActionsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Главное — одним касанием'**
  String get quickActionsSubtitle;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @noServerData.
  ///
  /// In ru, this message translates to:
  /// **'Никакие данные не отправляются на сервер'**
  String get noServerData;

  /// No description provided for @aboutVisualLab.
  ///
  /// In ru, this message translates to:
  /// **'О Visual Lab'**
  String get aboutVisualLab;

  /// No description provided for @versionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Версия 0.5.30+36 · персональная цифровая экосистема'**
  String get versionLabel;

  /// No description provided for @aboutLegalese.
  ///
  /// In ru, this message translates to:
  /// **'ORBIT 0.5. Почта, события, задачи и Brain используют явно маркированные локальные демонстрационные данные.'**
  String get aboutLegalese;

  /// No description provided for @aboutTech.
  ///
  /// In ru, this message translates to:
  /// **'Flutter + Impeller + Rive + нативный Google Filament для Android.'**
  String get aboutTech;

  /// No description provided for @settingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сохраняются сразу'**
  String get settingsSaved;

  /// No description provided for @interfaceGallery.
  ///
  /// In ru, this message translates to:
  /// **'Галерея интерфейсов'**
  String get interfaceGallery;

  /// No description provided for @livePreview.
  ///
  /// In ru, this message translates to:
  /// **'живой предпросмотр'**
  String get livePreview;

  /// No description provided for @qualityAutoSummary.
  ///
  /// In ru, this message translates to:
  /// **'Auto · адаптивно'**
  String get qualityAutoSummary;

  /// No description provided for @qualityEcoSummary.
  ///
  /// In ru, this message translates to:
  /// **'Eco · статика'**
  String get qualityEcoSummary;

  /// No description provided for @qualityBalancedSummary.
  ///
  /// In ru, this message translates to:
  /// **'Balanced · умеренная глубина'**
  String get qualityBalancedSummary;

  /// No description provided for @qualityUltraSummary.
  ///
  /// In ru, this message translates to:
  /// **'Ultra · максимум деталей'**
  String get qualityUltraSummary;

  /// No description provided for @qualityAutoDescription.
  ///
  /// In ru, this message translates to:
  /// **'Учитывает устройство и системные ограничения'**
  String get qualityAutoDescription;

  /// No description provided for @qualityEcoDescription.
  ///
  /// In ru, this message translates to:
  /// **'Статическая сцена, минимум эффектов'**
  String get qualityEcoDescription;

  /// No description provided for @qualityBalancedDescription.
  ///
  /// In ru, this message translates to:
  /// **'Фон до 30 FPS, умеренная глубина'**
  String get qualityBalancedDescription;

  /// No description provided for @qualityUltraDescription.
  ///
  /// In ru, this message translates to:
  /// **'Динамический свет и максимум деталей'**
  String get qualityUltraDescription;

  /// No description provided for @interfaceAndMotion.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс и движение'**
  String get interfaceAndMotion;

  /// No description provided for @uiAnimations.
  ///
  /// In ru, this message translates to:
  /// **'Анимации интерфейса'**
  String get uiAnimations;

  /// No description provided for @animationsDisableNotice.
  ///
  /// In ru, this message translates to:
  /// **'Отключение также останавливает фоновые сцены'**
  String get animationsDisableNotice;

  /// No description provided for @comfortable.
  ///
  /// In ru, this message translates to:
  /// **'Комфортная'**
  String get comfortable;

  /// No description provided for @compact.
  ///
  /// In ru, this message translates to:
  /// **'Компактная'**
  String get compact;

  /// No description provided for @systemLimits.
  ///
  /// In ru, this message translates to:
  /// **'Системные ограничения: энергосбережение {power}, давление памяти {memory}.'**
  String systemLimits(String power, String memory);

  /// No description provided for @enabled.
  ///
  /// In ru, this message translates to:
  /// **'включено'**
  String get enabled;

  /// No description provided for @notDetected.
  ///
  /// In ru, this message translates to:
  /// **'не обнаружено'**
  String get notDetected;

  /// No description provided for @present.
  ///
  /// In ru, this message translates to:
  /// **'есть'**
  String get present;

  /// No description provided for @absent.
  ///
  /// In ru, this message translates to:
  /// **'нет'**
  String get absent;

  /// No description provided for @accentColorValue.
  ///
  /// In ru, this message translates to:
  /// **'Акцентный цвет {value}'**
  String accentColorValue(String value);

  /// No description provided for @selectProfile.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать {profile}'**
  String selectProfile(String profile);

  /// No description provided for @interfaceBreadcrumb.
  ///
  /// In ru, this message translates to:
  /// **'Настройки → Персонализация → Интерфейс'**
  String get interfaceBreadcrumb;

  /// No description provided for @goodMorningShort.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро!'**
  String get goodMorningShort;

  /// No description provided for @greetingMorning.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро,\nАлексей!'**
  String get greetingMorning;

  /// No description provided for @greetingMorningShort.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро!'**
  String get greetingMorningShort;

  /// No description provided for @greetingDay.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день,\nАлексей!'**
  String get greetingDay;

  /// No description provided for @greetingDayShort.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день!'**
  String get greetingDayShort;

  /// No description provided for @greetingEvening.
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер,\nАлексей!'**
  String get greetingEvening;

  /// No description provided for @greetingEveningShort.
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер!'**
  String get greetingEveningShort;

  /// No description provided for @greetingNight.
  ///
  /// In ru, this message translates to:
  /// **'Доброй ночи,\nАлексей!'**
  String get greetingNight;

  /// No description provided for @greetingNightShort.
  ///
  /// In ru, this message translates to:
  /// **'Доброй ночи!'**
  String get greetingNightShort;

  /// No description provided for @profileOneSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Универсальный · глубокий фокус'**
  String get profileOneSubtitle;

  /// No description provided for @profileAtelierSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Атмосферный · утончённая точность'**
  String get profileAtelierSubtitle;

  /// No description provided for @profileFlowSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Динамичный · живой цифровой поток'**
  String get profileFlowSubtitle;

  /// No description provided for @profileZenSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Светлый · воздух и концентрация'**
  String get profileZenSubtitle;

  /// No description provided for @emailWeeklySender.
  ///
  /// In ru, this message translates to:
  /// **'Мария Соколова'**
  String get emailWeeklySender;

  /// No description provided for @emailDesignSender.
  ///
  /// In ru, this message translates to:
  /// **'Илья Волков'**
  String get emailDesignSender;

  /// No description provided for @emailProjectSender.
  ///
  /// In ru, this message translates to:
  /// **'Команда ORBIT'**
  String get emailProjectSender;

  /// No description provided for @emailResearchSender.
  ///
  /// In ru, this message translates to:
  /// **'Анна Ремизова'**
  String get emailResearchSender;

  /// No description provided for @emailWeeklySubject.
  ///
  /// In ru, this message translates to:
  /// **'План на неделю'**
  String get emailWeeklySubject;

  /// No description provided for @emailWeeklyPreview.
  ///
  /// In ru, this message translates to:
  /// **'Привет! Прикрепляю обновлённый план на следующую неделю…'**
  String get emailWeeklyPreview;

  /// No description provided for @emailWeeklyBody.
  ///
  /// In ru, this message translates to:
  /// **'Привет, Алексей!\n\nПрикрепляю обновлённый план на следующую неделю. Давай обсудим на встрече во вторник.\n\nЯ выделила ключевые этапы, добавила время на спокойную проверку и оставила пространство для незапланированных задач.\n\nХорошего дня!'**
  String get emailWeeklyBody;

  /// No description provided for @emailDesignSubject.
  ///
  /// In ru, this message translates to:
  /// **'Обсуждение дизайна'**
  String get emailDesignSubject;

  /// No description provided for @emailDesignPreview.
  ///
  /// In ru, this message translates to:
  /// **'Прикладываю актуальные варианты и короткие комментарии…'**
  String get emailDesignPreview;

  /// No description provided for @emailDesignBody.
  ///
  /// In ru, this message translates to:
  /// **'Привет!\n\nПрикладываю актуальные варианты и короткие комментарии. Особенно интересно твоё мнение о плотности списка и поведении нижней навигации.'**
  String get emailDesignBody;

  /// No description provided for @emailProjectSubject.
  ///
  /// In ru, this message translates to:
  /// **'Обновление по проекту'**
  String get emailProjectSubject;

  /// No description provided for @emailProjectPreview.
  ///
  /// In ru, this message translates to:
  /// **'Статус, следующие шаги и спокойный фокус на главном…'**
  String get emailProjectPreview;

  /// No description provided for @emailProjectBody.
  ///
  /// In ru, this message translates to:
  /// **'Коллеги, привет!\n\nОсновной этап завершён. Следующие шаги: визуальная проверка, тестирование на устройствах и подготовка передачи в основной продукт.'**
  String get emailProjectBody;

  /// No description provided for @emailResearchSubject.
  ///
  /// In ru, this message translates to:
  /// **'Встреча: подготовка'**
  String get emailResearchSubject;

  /// No description provided for @emailResearchPreview.
  ///
  /// In ru, this message translates to:
  /// **'Материалы и повестка внутри. Встреча займёт около часа…'**
  String get emailResearchPreview;

  /// No description provided for @emailResearchBody.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день!\n\nМатериалы и повестка внутри. Предлагаю сначала обсудить пользовательские сценарии, затем визуальные ограничения.'**
  String get emailResearchBody;

  /// No description provided for @emailFocusSubject.
  ///
  /// In ru, this message translates to:
  /// **'Три мысли для спокойного дня'**
  String get emailFocusSubject;

  /// No description provided for @emailFocusPreview.
  ///
  /// In ru, this message translates to:
  /// **'Начните с главного, оставьте место для паузы…'**
  String get emailFocusPreview;

  /// No description provided for @emailFocusBody.
  ///
  /// In ru, this message translates to:
  /// **'Начните с главного, оставьте место для паузы, завершите день коротким обзором.\n\nЭто демонстрационное письмо локальной оболочки ORBIT.'**
  String get emailFocusBody;

  /// No description provided for @attachmentWeekPlan.
  ///
  /// In ru, this message translates to:
  /// **'План_недели.pdf · 2,4 МБ'**
  String get attachmentWeekPlan;

  /// No description provided for @attachmentSchedule.
  ///
  /// In ru, this message translates to:
  /// **'График.xlsx · 1,1 МБ'**
  String get attachmentSchedule;

  /// No description provided for @attachmentPresentation.
  ///
  /// In ru, this message translates to:
  /// **'Презентация.pdf · 7,8 МБ'**
  String get attachmentPresentation;

  /// No description provided for @eventReviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Совещание по ВП'**
  String get eventReviewTitle;

  /// No description provided for @eventReviewMeta.
  ///
  /// In ru, this message translates to:
  /// **'Команда · Онлайн · 1 ч'**
  String get eventReviewMeta;

  /// No description provided for @eventAuditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аудит СПД Тэнда'**
  String get eventAuditTitle;

  /// No description provided for @eventAuditMeta.
  ///
  /// In ru, this message translates to:
  /// **'Проект · Исследования · 1 ч'**
  String get eventAuditMeta;

  /// No description provided for @eventReportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подготовить отчёт'**
  String get eventReportTitle;

  /// No description provided for @eventReportMeta.
  ///
  /// In ru, this message translates to:
  /// **'ВП / БАМ · Фокус · 1 ч'**
  String get eventReportMeta;

  /// No description provided for @taskReportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подготовить отчёт по КПЭ'**
  String get taskReportTitle;

  /// No description provided for @taskPlanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Актуализировать план развития'**
  String get taskPlanTitle;

  /// No description provided for @taskMaterialsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Согласовать материалы по ВП'**
  String get taskMaterialsTitle;

  /// No description provided for @taskDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отправить данные в ЦА'**
  String get taskDataTitle;

  /// No description provided for @projectStrategy.
  ///
  /// In ru, this message translates to:
  /// **'Стратегия'**
  String get projectStrategy;

  /// No description provided for @projectVp.
  ///
  /// In ru, this message translates to:
  /// **'ВП'**
  String get projectVp;

  /// No description provided for @projectVpBam.
  ///
  /// In ru, this message translates to:
  /// **'ВП / БАМ'**
  String get projectVpBam;

  /// No description provided for @demoUserInitials.
  ///
  /// In ru, this message translates to:
  /// **'АР'**
  String get demoUserInitials;

  /// No description provided for @demoUserName.
  ///
  /// In ru, this message translates to:
  /// **'Алексей Романов'**
  String get demoUserName;

  /// No description provided for @noDue.
  ///
  /// In ru, this message translates to:
  /// **'Без срока'**
  String get noDue;

  /// No description provided for @demoReplyBody.
  ///
  /// In ru, this message translates to:
  /// **'\n\n—\nОтвет на демонстрационное письмо: {preview}'**
  String demoReplyBody(Object preview);

  /// No description provided for @demoForwardBody.
  ///
  /// In ru, this message translates to:
  /// **'\n\n—\nПересланное демонстрационное письмо: {preview}'**
  String demoForwardBody(Object preview);

  /// No description provided for @unread.
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get unread;

  /// No description provided for @diagnostics.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get diagnostics;

  /// No description provided for @textSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер текста'**
  String get textSize;

  /// No description provided for @textSizeStandard.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get textSizeStandard;

  /// No description provided for @textSizeLarge.
  ///
  /// In ru, this message translates to:
  /// **'Крупный'**
  String get textSizeLarge;

  /// No description provided for @textSizeExtraLarge.
  ///
  /// In ru, this message translates to:
  /// **'Очень крупный'**
  String get textSizeExtraLarge;

  /// No description provided for @newEvent.
  ///
  /// In ru, this message translates to:
  /// **'Новое событие'**
  String get newEvent;

  /// No description provided for @eventTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Название события'**
  String get eventTitleHint;

  /// No description provided for @eventTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get eventTime;

  /// No description provided for @eventCreated.
  ///
  /// In ru, this message translates to:
  /// **'Событие сохранено локально'**
  String get eventCreated;

  /// No description provided for @taskDetails.
  ///
  /// In ru, this message translates to:
  /// **'Карточка задачи'**
  String get taskDetails;

  /// No description provided for @status.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get status;

  /// No description provided for @priority.
  ///
  /// In ru, this message translates to:
  /// **'Приоритет'**
  String get priority;

  /// No description provided for @priorityLow.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In ru, this message translates to:
  /// **'Средний'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In ru, this message translates to:
  /// **'Высокий'**
  String get priorityHigh;

  /// No description provided for @markDone.
  ///
  /// In ru, this message translates to:
  /// **'Отметить выполненной'**
  String get markDone;

  /// No description provided for @markActive.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть в активные'**
  String get markActive;

  /// No description provided for @localSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить локальные изменения. Повторите попытку.'**
  String get localSaveFailed;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @appearanceSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить оформление. Повторите попытку.'**
  String get appearanceSaveFailed;

  /// No description provided for @appearanceLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить оформление. Повторите попытку.'**
  String get appearanceLoadFailed;

  /// No description provided for @localLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить локальные данные. Повторите попытку.'**
  String get localLoadFailed;

  /// No description provided for @appearanceCorrupted.
  ///
  /// In ru, this message translates to:
  /// **'Оформление повреждено. Исходная запись сохранена в резервной копии.'**
  String get appearanceCorrupted;

  /// No description provided for @localDataCorrupted.
  ///
  /// In ru, this message translates to:
  /// **'Локальные данные повреждены. Исходная запись сохранена в резервной копии.'**
  String get localDataCorrupted;

  /// No description provided for @exportBackup.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт backup'**
  String get exportBackup;

  /// No description provided for @backupExported.
  ///
  /// In ru, this message translates to:
  /// **'Резервная копия экспортирована: {path}'**
  String backupExported(Object path);

  /// No description provided for @backupExportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось экспортировать резервную копию. Исходные данные не изменены.'**
  String get backupExportFailed;

  /// No description provided for @resetCorruptData.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get resetCorruptData;

  /// No description provided for @resetCorruptConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить повреждённые данные? Резервная копия исходной записи будет сохранена.'**
  String get resetCorruptConfirm;

  /// No description provided for @eventDetails.
  ///
  /// In ru, this message translates to:
  /// **'Детали события'**
  String get eventDetails;

  /// No description provided for @eventDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get eventDescription;

  /// No description provided for @eventLocation.
  ///
  /// In ru, this message translates to:
  /// **'Место встречи'**
  String get eventLocation;

  /// No description provided for @eventOrganizer.
  ///
  /// In ru, this message translates to:
  /// **'Организатор'**
  String get eventOrganizer;

  /// No description provided for @eventAttendees.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get eventAttendees;

  /// No description provided for @eventConference.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн-встреча'**
  String get eventConference;

  /// No description provided for @joinMeeting.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться к встрече'**
  String get joinMeeting;

  /// No description provided for @copyMeetingLink.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать ссылку'**
  String get copyMeetingLink;

  /// No description provided for @linkCopied.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована в буфер обмена'**
  String get linkCopied;

  /// No description provided for @noDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание не указано'**
  String get noDescription;

  /// No description provided for @noLocation.
  ///
  /// In ru, this message translates to:
  /// **'Место не указано'**
  String get noLocation;

  /// No description provided for @noAttendees.
  ///
  /// In ru, this message translates to:
  /// **'Список участников пуст'**
  String get noAttendees;

  /// No description provided for @noAttachments.
  ///
  /// In ru, this message translates to:
  /// **'Вложения отсутствуют'**
  String get noAttachments;

  /// No description provided for @openAttachment.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get openAttachment;

  /// No description provided for @statusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принято'**
  String get statusAccepted;

  /// No description provided for @statusDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get statusDeclined;

  /// No description provided for @statusTentative.
  ///
  /// In ru, this message translates to:
  /// **'Под вопросом'**
  String get statusTentative;

  /// No description provided for @statusAwaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание ответа'**
  String get statusAwaiting;

  /// No description provided for @gyroIntensity.
  ///
  /// In ru, this message translates to:
  /// **'3D-параллакс от гироскопа'**
  String get gyroIntensity;

  /// No description provided for @gyroIntensityDesc.
  ///
  /// In ru, this message translates to:
  /// **'Плавный отклик планов на физический наклон устройства'**
  String get gyroIntensityDesc;

  /// No description provided for @gyroOff.
  ///
  /// In ru, this message translates to:
  /// **'Выкл'**
  String get gyroOff;

  /// No description provided for @gyroSubtle.
  ///
  /// In ru, this message translates to:
  /// **'Мягкий'**
  String get gyroSubtle;

  /// No description provided for @gyroEnhanced.
  ///
  /// In ru, this message translates to:
  /// **'Выраженный'**
  String get gyroEnhanced;

  /// No description provided for @lightingAndAtmosphere.
  ///
  /// In ru, this message translates to:
  /// **'Освещение и атмосфера'**
  String get lightingAndAtmosphere;

  /// No description provided for @lightingAndAtmosphereDesc.
  ///
  /// In ru, this message translates to:
  /// **'Суточный световой цикл и положение солнца'**
  String get lightingAndAtmosphereDesc;

  /// No description provided for @atmosphereAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто (время)'**
  String get atmosphereAuto;

  /// No description provided for @atmosphereDawn.
  ///
  /// In ru, this message translates to:
  /// **'Рассвет'**
  String get atmosphereDawn;

  /// No description provided for @atmosphereDay.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get atmosphereDay;

  /// No description provided for @atmosphereSunset.
  ///
  /// In ru, this message translates to:
  /// **'Закат'**
  String get atmosphereSunset;

  /// No description provided for @atmosphereNight.
  ///
  /// In ru, this message translates to:
  /// **'Ночь'**
  String get atmosphereNight;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
