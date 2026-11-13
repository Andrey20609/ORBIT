// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ORBIT Visual Lab';

  @override
  String get today => 'Today';

  @override
  String get mail => 'Mail';

  @override
  String get calendar => 'Calendar';

  @override
  String get tasks => 'Tasks';

  @override
  String get more => 'More';

  @override
  String get back => 'Back';

  @override
  String get settings => 'Settings';

  @override
  String get inbox => 'Inbox';

  @override
  String get newEmail => 'New email';

  @override
  String get search => 'Search';

  @override
  String get all => 'All';

  @override
  String get important => 'Starred';

  @override
  String get importantSingle => 'Starred';

  @override
  String get emptyHere => 'Nothing here yet';

  @override
  String unreadSummary(int count) {
    return '$count unread · demo mail';
  }

  @override
  String get mailDemoNotice =>
      'Swipe and server actions are disabled: data exists only in this demo.';

  @override
  String toMe(String email) {
    return 'To: me · $email';
  }

  @override
  String get attachments => 'Attachments';

  @override
  String get demoAttachment => 'Demo attachment';

  @override
  String get demoAttachmentNotice =>
      'This file is a demo record and cannot be downloaded.';

  @override
  String get reply => 'Reply';

  @override
  String get replyAll => 'Reply all';

  @override
  String get forward => 'Forward';

  @override
  String get draftSubtitle => 'Offline draft · sending disabled';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get draftSaved => 'Draft saved locally. Email not sent.';

  @override
  String get draftUnsavedChanges => 'unsaved changes';

  @override
  String get draftSavedState => 'all changes saved';

  @override
  String get to => 'To';

  @override
  String get subject => 'Subject';

  @override
  String get subjectHint => 'What is it about?';

  @override
  String get bodyHint => 'Email text…';

  @override
  String get formatting => 'Formatting unavailable in DEMO';

  @override
  String get attachmentsDisabled => 'Attachments disabled';

  @override
  String get localFilesDisabled =>
      'Local files cannot be attached in Visual Lab.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get understood => 'Got it';

  @override
  String get demoLabel => 'DEMO · LOCAL DATA';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDemo =>
      'Server notifications are not connected in Visual Lab.';

  @override
  String get goodMorning => 'Good morning,\nAlexey!';

  @override
  String dateFocus(String date) {
    return '$date · calm focus';
  }

  @override
  String get newMetric => 'new';

  @override
  String get eventsMetric => 'events';

  @override
  String get tasksMetric => 'tasks';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get actionCenter => 'Action center';

  @override
  String get dayRhythm => 'day rhythm';

  @override
  String get yourSpace => 'Your space';

  @override
  String completedSummary(int completed, int total) {
    return '$completed of $total tasks complete. Your next quiet interval is after 13:30.';
  }

  @override
  String get flow => 'Flow';

  @override
  String get focus => 'Focus';

  @override
  String get emailAction => 'Email';

  @override
  String get taskAction => 'Task';

  @override
  String get eventAction => 'Event';

  @override
  String get experimentRive => 'EXPERIMENT B · RIVE';

  @override
  String get experimentFilament => 'EXPERIMENT C · FILAMENT';

  @override
  String get liveBrandScene => 'Interactive atmosphere';

  @override
  String get pbrScene => 'True PBR scene';

  @override
  String get compareRenderers => 'Compare renderers →';

  @override
  String graphicsUnavailable(String reason) {
    return 'Graphics renderer unavailable. Static/Eco is active; the interface remains usable.\n$reason';
  }

  @override
  String get filamentUnsupported =>
      'Filament is available in the Android build. The static/procedural fallback is active on this platform.';

  @override
  String get riveAtmosphereSemantics =>
      'Interactive ORBIT Rive scene. Tap to trigger a pulse.';

  @override
  String get riveMarkSemantics =>
      'Animated ORBIT logo. Tap to trigger a pulse.';

  @override
  String get activeRenderer => 'Active renderer';

  @override
  String get rendererDescription =>
      'Your choice applies immediately and is saved. Navigation and demo data are preserved.';

  @override
  String get staticRendererTitle => 'A · Static / Eco';

  @override
  String get staticRendererSubtitle =>
      'Detailed static Flutter/Impeller scene without a continuous frame loop.';

  @override
  String get riveRendererTitle => 'B · Flutter + Impeller + Rive';

  @override
  String get riveRendererSubtitle =>
      'Atmospheric landscape, orbital animation, and a Rive Pulse trigger on tap.';

  @override
  String get filamentRendererTitle => 'C · Flutter + native Google Filament';

  @override
  String get filamentRendererSubtitle =>
      'Native Android SurfaceView with PBR terrain, sun, clouds, and camera.';

  @override
  String get visualLabSubtitle => 'Compare renderers on the same Today screen';

  @override
  String get openToday => 'Open Today';

  @override
  String get measurementStatus => 'Measurement status';

  @override
  String get frameMetrics => 'FPS / P95 frame time';

  @override
  String get resourceMetrics => 'RAM / GPU / energy / temperature';

  @override
  String get physicalRun => 'Physical device run';

  @override
  String get performanceMethod =>
      'A fair comparison requires profile/release builds on the same physical Android device. See docs/PERFORMANCE.md for the method and commands.';

  @override
  String get graphicsLog => 'Graphics fallback log';

  @override
  String get nativePbr => 'NATIVE · PBR';

  @override
  String get androidFallback => 'ANDROID ONLY · FALLBACK';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get agenda => 'Agenda';

  @override
  String get allUpcoming => 'All upcoming events';

  @override
  String get freeTomorrow =>
      'Tomorrow is free after 16:00 — a good time for focused work.';

  @override
  String get morning => 'morning';

  @override
  String get events => 'events';

  @override
  String get focusHours => 'focus hours';

  @override
  String get progressDay => 'Daily progress';

  @override
  String get active => 'Active';

  @override
  String get projects => 'Projects';

  @override
  String get addTask => 'Add task';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get newTask => 'New task';

  @override
  String get taskHint => 'What needs to be done?';

  @override
  String completedOf(int completed, int total) {
    return '$completed of $total complete · local logic';
  }

  @override
  String get localList => 'Local list';

  @override
  String get settingsSubtitle => 'Personal space · Visual Lab';

  @override
  String get personalization => 'Personalization';

  @override
  String get interface => 'Interface';

  @override
  String get graphicsQuality => 'Graphics quality';

  @override
  String get visualLabExperiments => 'Static · Rive · Filament · A/B/C modes';

  @override
  String get accentColor => 'Accent color';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get density => 'Density';

  @override
  String get motion => 'Motion';

  @override
  String get routeNotFound => 'Route not found';

  @override
  String get routeStateSaved =>
      'Shell state is preserved. Return to the home screen.';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get mondayShort => 'Mon';

  @override
  String get done => 'Done';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String todayTime(String time) {
    return 'Today, $time';
  }

  @override
  String get dateNovember5 => 'November 5';

  @override
  String get system => 'System';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSpanish => 'Español';

  @override
  String get brainDemoSubtitle => 'Future assistant demo · local scenarios';

  @override
  String get brainGreeting => 'How can I help today?';

  @override
  String get brainNotice =>
      'No network requests: choose one of the prepared scenarios.';

  @override
  String get brainPromptInbox => 'Review inbox';

  @override
  String get brainPromptPlan => 'Plan my day';

  @override
  String get brainPromptReport => 'Prepare report';

  @override
  String get brainResponseInbox =>
      'Local demo scenario: two unread emails first, then the weekly plan. This is not an analysis of real mail.';

  @override
  String get brainResponsePlan =>
      'Local demo scenario: meeting at 10:00, audit at 13:30, calm focus after 14:30. Data comes from the demo calendar.';

  @override
  String get brainResponseReport =>
      'Local demo scenario: report structure — goal, result, risks, next step. No text was sent to an AI service.';

  @override
  String get demoResponse => 'Demo response';

  @override
  String get createTask => 'Create task';

  @override
  String get localDraft => 'Local draft';

  @override
  String get toLocalList => 'To local list';

  @override
  String get openCalendar => 'Open calendar';

  @override
  String get demoAssistant => 'Demo assistant';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get quickActionsSubtitle => 'Essentials in one tap';

  @override
  String get close => 'Close';

  @override
  String get noServerData => 'No data is sent to a server';

  @override
  String get aboutVisualLab => 'About Visual Lab';

  @override
  String get versionLabel => 'Version 0.5.30+36 · personal digital ecosystem';

  @override
  String get aboutLegalese =>
      'ORBIT 0.5. Mail, events, tasks and Brain use explicitly marked local demo data.';

  @override
  String get aboutTech =>
      'Flutter + Impeller + Rive + native Google Filament for Android.';

  @override
  String get settingsSaved => 'Settings are saved immediately';

  @override
  String get interfaceGallery => 'Interface gallery';

  @override
  String get livePreview => 'live preview';

  @override
  String get qualityAutoSummary => 'Auto · adaptive';

  @override
  String get qualityEcoSummary => 'Eco · static';

  @override
  String get qualityBalancedSummary => 'Balanced · moderate depth';

  @override
  String get qualityUltraSummary => 'Ultra · maximum detail';

  @override
  String get qualityAutoDescription =>
      'Accounts for the device and system limits';

  @override
  String get qualityEcoDescription => 'Static scene with minimal effects';

  @override
  String get qualityBalancedDescription =>
      'Background up to 30 FPS, moderate depth';

  @override
  String get qualityUltraDescription => 'Dynamic light and maximum detail';

  @override
  String get interfaceAndMotion => 'Interface and motion';

  @override
  String get uiAnimations => 'Interface animations';

  @override
  String get animationsDisableNotice =>
      'Turning this off also stops background scenes';

  @override
  String get comfortable => 'Comfortable';

  @override
  String get compact => 'Compact';

  @override
  String systemLimits(String power, String memory) {
    return 'System limits: battery saver $power, memory pressure $memory.';
  }

  @override
  String get enabled => 'enabled';

  @override
  String get notDetected => 'not detected';

  @override
  String get present => 'present';

  @override
  String get absent => 'none';

  @override
  String accentColorValue(String value) {
    return 'Accent color $value';
  }

  @override
  String selectProfile(String profile) {
    return 'Select $profile';
  }

  @override
  String get interfaceBreadcrumb => 'Settings → Personalization → Interface';

  @override
  String get goodMorningShort => 'Good morning!';

  @override
  String get greetingMorning => 'Good morning,\nAlexey!';

  @override
  String get greetingMorningShort => 'Good morning!';

  @override
  String get greetingDay => 'Good afternoon,\nAlexey!';

  @override
  String get greetingDayShort => 'Good afternoon!';

  @override
  String get greetingEvening => 'Good evening,\nAlexey!';

  @override
  String get greetingEveningShort => 'Good evening!';

  @override
  String get greetingNight => 'Good night,\nAlexey!';

  @override
  String get greetingNightShort => 'Good night!';

  @override
  String get profileOneSubtitle => 'Versatile · deep focus';

  @override
  String get profileAtelierSubtitle => 'Atmospheric · refined precision';

  @override
  String get profileFlowSubtitle => 'Dynamic · living digital flow';

  @override
  String get profileZenSubtitle => 'Light · air and concentration';

  @override
  String get emailWeeklySender => 'Maria Sokolova';

  @override
  String get emailDesignSender => 'Ilya Volkov';

  @override
  String get emailProjectSender => 'ORBIT Team';

  @override
  String get emailResearchSender => 'Anna Remizova';

  @override
  String get emailWeeklySubject => 'Weekly plan';

  @override
  String get emailWeeklyPreview =>
      'Hi! Attached is the updated plan for next week…';

  @override
  String get emailWeeklyBody =>
      'Hi Alexey!\n\nAttached is the updated plan for next week. Let’s discuss it at Tuesday’s meeting.\n\nI highlighted the key stages, allowed time for a calm review, and left room for unplanned tasks.\n\nHave a great day!';

  @override
  String get emailDesignSubject => 'Design review';

  @override
  String get emailDesignPreview =>
      'Here are the latest options and brief comments…';

  @override
  String get emailDesignBody =>
      'Hi!\n\nHere are the latest options and brief comments. I’m especially interested in your thoughts on list density and bottom navigation behavior.';

  @override
  String get emailProjectSubject => 'Project update';

  @override
  String get emailProjectPreview =>
      'Status, next steps, and calm focus on what matters…';

  @override
  String get emailProjectBody =>
      'Hello everyone!\n\nThe main stage is complete. Next: visual review, device testing, and preparing handoff to the main product.';

  @override
  String get emailResearchSubject => 'Meeting preparation';

  @override
  String get emailResearchPreview =>
      'Materials and agenda inside. The meeting will take about an hour…';

  @override
  String get emailResearchBody =>
      'Good afternoon!\n\nMaterials and agenda are inside. I suggest discussing user scenarios first, then visual constraints.';

  @override
  String get emailFocusSubject => 'Three thoughts for a calm day';

  @override
  String get emailFocusPreview =>
      'Start with what matters, leave room for a pause…';

  @override
  String get emailFocusBody =>
      'Start with what matters, leave room for a pause, and end the day with a brief review.\n\nThis is a demo email in the local ORBIT shell.';

  @override
  String get attachmentWeekPlan => 'Weekly_plan.pdf · 2.4 MB';

  @override
  String get attachmentSchedule => 'Schedule.xlsx · 1.1 MB';

  @override
  String get attachmentPresentation => 'Presentation.pdf · 7.8 MB';

  @override
  String get eventReviewTitle => 'Project review meeting';

  @override
  String get eventReviewMeta => 'Team · Online · 1 h';

  @override
  String get eventAuditTitle => 'Tenda process audit';

  @override
  String get eventAuditMeta => 'Project · Research · 1 h';

  @override
  String get eventReportTitle => 'Prepare report';

  @override
  String get eventReportMeta => 'Project / BAM · Focus · 1 h';

  @override
  String get taskReportTitle => 'Prepare KPI report';

  @override
  String get taskPlanTitle => 'Update development plan';

  @override
  String get taskMaterialsTitle => 'Approve project materials';

  @override
  String get taskDataTitle => 'Send data to the analytics center';

  @override
  String get projectStrategy => 'Strategy';

  @override
  String get projectVp => 'Project';

  @override
  String get projectVpBam => 'Project / BAM';

  @override
  String get demoUserInitials => 'AR';

  @override
  String get demoUserName => 'Alexey Romanov';

  @override
  String get noDue => 'No due date';

  @override
  String demoReplyBody(Object preview) {
    return '\n\n—\nReply to demo email: $preview';
  }

  @override
  String demoForwardBody(Object preview) {
    return '\n\n—\nForwarded demo email: $preview';
  }

  @override
  String get unread => 'Unread';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeStandard => 'Standard';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeExtraLarge => 'Extra large';

  @override
  String get newEvent => 'New event';

  @override
  String get eventTitleHint => 'Event title';

  @override
  String get eventTime => 'Time';

  @override
  String get eventCreated => 'Event saved locally';

  @override
  String get taskDetails => 'Task details';

  @override
  String get status => 'Status';

  @override
  String get priority => 'Priority';

  @override
  String get priorityLow => 'Normal';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get markDone => 'Mark as done';

  @override
  String get markActive => 'Mark as active';

  @override
  String get localSaveFailed => 'Local changes could not be saved. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get appearanceSaveFailed =>
      'Appearance settings could not be saved. Try again.';

  @override
  String get appearanceLoadFailed =>
      'Appearance settings could not be loaded. Try again.';

  @override
  String get localLoadFailed => 'Local data could not be loaded. Try again.';

  @override
  String get appearanceCorrupted =>
      'Appearance data is corrupt. The original payload is preserved in a backup.';

  @override
  String get localDataCorrupted =>
      'Local data is corrupt. The original payload is preserved in a backup.';

  @override
  String get exportBackup => 'Export backup';

  @override
  String backupExported(Object path) {
    return 'Backup exported: $path';
  }

  @override
  String get backupExportFailed =>
      'Backup export failed. Original data is unchanged.';

  @override
  String get resetCorruptData => 'Reset';

  @override
  String get resetCorruptConfirm =>
      'Reset corrupt data? The original payload will remain in the backup.';

  @override
  String get eventDetails => 'Event details';

  @override
  String get eventDescription => 'Description';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventOrganizer => 'Organizer';

  @override
  String get eventAttendees => 'Attendees';

  @override
  String get eventConference => 'Online meeting';

  @override
  String get joinMeeting => 'Join meeting';

  @override
  String get copyMeetingLink => 'Copy link';

  @override
  String get linkCopied => 'Meeting link copied to clipboard';

  @override
  String get noDescription => 'No description provided';

  @override
  String get noLocation => 'No location specified';

  @override
  String get noAttendees => 'No attendees listed';

  @override
  String get noAttachments => 'No attachments';

  @override
  String get openAttachment => 'Open';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusDeclined => 'Declined';

  @override
  String get statusTentative => 'Tentative';

  @override
  String get statusAwaiting => 'Awaiting response';

  @override
  String get gyroIntensity => 'Gyroscope 3D parallax';

  @override
  String get gyroIntensityDesc =>
      'Physical tilt response across scene depth layers';

  @override
  String get gyroOff => 'Off';

  @override
  String get gyroSubtle => 'Subtle';

  @override
  String get gyroEnhanced => 'Enhanced';

  @override
  String get lightingAndAtmosphere => 'Lighting and atmosphere';

  @override
  String get lightingAndAtmosphereDesc =>
      'Diurnal lighting and solar position throughout the day';

  @override
  String get atmosphereAuto => 'Auto (time)';

  @override
  String get atmosphereDawn => 'Dawn';

  @override
  String get atmosphereDay => 'Day';

  @override
  String get atmosphereSunset => 'Sunset';

  @override
  String get atmosphereNight => 'Night';
}
