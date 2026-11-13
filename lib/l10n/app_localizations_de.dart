// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'ORBIT Visual Lab';

  @override
  String get today => 'Heute';

  @override
  String get mail => 'Post';

  @override
  String get calendar => 'Kalender';

  @override
  String get tasks => 'Aufgaben';

  @override
  String get more => 'Mehr';

  @override
  String get back => 'Zurück';

  @override
  String get settings => 'Einstellungen';

  @override
  String get inbox => 'Posteingang';

  @override
  String get newEmail => 'Neue E-Mail';

  @override
  String get search => 'Suchen';

  @override
  String get all => 'Alle';

  @override
  String get important => 'Wichtig';

  @override
  String get importantSingle => 'Wichtig';

  @override
  String get emptyHere => 'Hier ist noch nichts';

  @override
  String unreadSummary(int count) {
    return '$count ungelesen · Demo-Post';
  }

  @override
  String get mailDemoNotice =>
      'Wischen und Serveraktionen sind deaktiviert: Die Daten existieren nur in dieser Demo.';

  @override
  String toMe(String email) {
    return 'An: mich · $email';
  }

  @override
  String get attachments => 'Anhänge';

  @override
  String get demoAttachment => 'Demo-Anhang';

  @override
  String get demoAttachmentNotice =>
      'Diese Datei ist ein Demo-Eintrag und kann nicht geladen werden.';

  @override
  String get reply => 'Antworten';

  @override
  String get replyAll => 'Allen antworten';

  @override
  String get forward => 'Weiterleiten';

  @override
  String get draftSubtitle => 'Lokaler Entwurf · Senden deaktiviert';

  @override
  String get saveDraft => 'Entwurf speichern';

  @override
  String get draftSaved => 'Entwurf lokal gespeichert. E-Mail nicht gesendet.';

  @override
  String get draftUnsavedChanges => 'ungespeicherte Änderungen';

  @override
  String get draftSavedState => 'alle Änderungen gespeichert';

  @override
  String get to => 'An';

  @override
  String get subject => 'Betreff';

  @override
  String get subjectHint => 'Worum geht es?';

  @override
  String get bodyHint => 'E-Mail-Text…';

  @override
  String get formatting => 'Formatierung in DEMO nicht verfügbar';

  @override
  String get attachmentsDisabled => 'Anhänge deaktiviert';

  @override
  String get localFilesDisabled =>
      'Lokale Dateien können in Visual Lab nicht angehängt werden.';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get understood => 'Verstanden';

  @override
  String get demoLabel => 'DEMO · LOKALE DATEN';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsDemo =>
      'Server-Benachrichtigungen sind in Visual Lab nicht verbunden.';

  @override
  String get goodMorning => 'Guten Morgen,\nAlexey!';

  @override
  String dateFocus(String date) {
    return '$date · ruhiger Fokus';
  }

  @override
  String get newMetric => 'neu';

  @override
  String get eventsMetric => 'Termine';

  @override
  String get tasksMetric => 'Aufgaben';

  @override
  String get upcoming => 'Demnächst';

  @override
  String get actionCenter => 'Aktionszentrum';

  @override
  String get dayRhythm => 'Tagesrhythmus';

  @override
  String get yourSpace => 'Ihr Bereich';

  @override
  String completedSummary(int completed, int total) {
    return '$completed von $total Aufgaben erledigt. Die nächste ruhige Phase beginnt nach 13:30.';
  }

  @override
  String get flow => 'Flow';

  @override
  String get focus => 'Fokus';

  @override
  String get emailAction => 'E-Mail';

  @override
  String get taskAction => 'Aufgabe';

  @override
  String get eventAction => 'Termin';

  @override
  String get experimentRive => 'EXPERIMENT B · RIVE';

  @override
  String get experimentFilament => 'EXPERIMENT C · FILAMENT';

  @override
  String get liveBrandScene => 'Interaktive Atmosphäre';

  @override
  String get pbrScene => 'Echte PBR-Szene';

  @override
  String get compareRenderers => 'Renderer vergleichen →';

  @override
  String graphicsUnavailable(String reason) {
    return 'Grafik-Renderer nicht verfügbar. Static/Eco ist aktiv; die Oberfläche bleibt nutzbar.\n$reason';
  }

  @override
  String get filamentUnsupported =>
      'Filament ist im Android-Build verfügbar. Auf dieser Plattform ist der statische/prozedurale Fallback aktiv.';

  @override
  String get riveAtmosphereSemantics =>
      'Interaktive ORBIT-Rive-Szene. Zum Auslösen eines Impulses tippen.';

  @override
  String get riveMarkSemantics =>
      'Animiertes ORBIT-Logo. Zum Auslösen eines Impulses tippen.';

  @override
  String get activeRenderer => 'Aktiver Renderer';

  @override
  String get rendererDescription =>
      'Die Auswahl gilt sofort und wird gespeichert. Navigation und Demo-Daten bleiben erhalten.';

  @override
  String get staticRendererTitle => 'A · Static / Eco';

  @override
  String get staticRendererSubtitle =>
      'Detaillierte statische Flutter/Impeller-Szene ohne kontinuierliche Frameschleife.';

  @override
  String get riveRendererTitle => 'B · Flutter + Impeller + Rive';

  @override
  String get riveRendererSubtitle =>
      'Atmosphärische Landschaft, Orbitalanimation und Rive-Pulse-Trigger per Tipp.';

  @override
  String get filamentRendererTitle => 'C · Flutter + native Google Filament';

  @override
  String get filamentRendererSubtitle =>
      'Natives Android-SurfaceView mit PBR-Gelände, Sonne, Wolken und Kamera.';

  @override
  String get visualLabSubtitle =>
      'Renderer auf demselben Heute-Bildschirm vergleichen';

  @override
  String get openToday => 'Heute öffnen';

  @override
  String get measurementStatus => 'Messstatus';

  @override
  String get frameMetrics => 'FPS / P95 frame time';

  @override
  String get resourceMetrics => 'RAM / GPU / Energie / Temperatur';

  @override
  String get physicalRun => 'Lauf auf physischem Gerät';

  @override
  String get performanceMethod =>
      'Für einen fairen Vergleich sind Profile/Release-Builds auf demselben physischen Android-Gerät nötig. Methode und Befehle: docs/PERFORMANCE.md.';

  @override
  String get graphicsLog => 'Grafik-Fallback-Protokoll';

  @override
  String get nativePbr => 'NATIVE · PBR';

  @override
  String get androidFallback => 'ANDROID ONLY · FALLBACK';

  @override
  String get day => 'Tag';

  @override
  String get week => 'Woche';

  @override
  String get month => 'Monat';

  @override
  String get agenda => 'Agenda';

  @override
  String get allUpcoming => 'Alle bevorstehenden Termine';

  @override
  String get freeTomorrow =>
      'Morgen ist nach 16:00 frei — eine gute Zeit für konzentrierte Arbeit.';

  @override
  String get morning => 'Morgen';

  @override
  String get events => 'Termine';

  @override
  String get focusHours => 'Fokusstunden';

  @override
  String get progressDay => 'Tagesfortschritt';

  @override
  String get active => 'Aktiv';

  @override
  String get projects => 'Projekte';

  @override
  String get addTask => 'Aufgabe hinzufügen';

  @override
  String get quickAdd => 'Schnell hinzufügen';

  @override
  String get newTask => 'Neue Aufgabe';

  @override
  String get taskHint => 'Was ist zu tun?';

  @override
  String completedOf(int completed, int total) {
    return '$completed von $total erledigt · lokale Logik';
  }

  @override
  String get localList => 'Lokale Liste';

  @override
  String get settingsSubtitle => 'Persönlicher Bereich · Visual Lab';

  @override
  String get personalization => 'Personalisierung';

  @override
  String get interface => 'Oberfläche';

  @override
  String get graphicsQuality => 'Grafikqualität';

  @override
  String get visualLabExperiments => 'Static · Rive · Filament · A/B/C-Modi';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get language => 'Sprache';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get density => 'Dichte';

  @override
  String get motion => 'Bewegung';

  @override
  String get routeNotFound => 'Route nicht gefunden';

  @override
  String get routeStateSaved =>
      'Der Shell-Zustand bleibt erhalten. Zur Startseite zurückkehren.';

  @override
  String get yesterday => 'Gestern';

  @override
  String get mondayShort => 'Mo';

  @override
  String get done => 'Erledigt';

  @override
  String get tomorrow => 'Morgen';

  @override
  String todayTime(String time) {
    return 'Heute, $time';
  }

  @override
  String get dateNovember5 => '5. November';

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
  String get brainDemoSubtitle =>
      'Demo des künftigen Assistenten · lokale Szenarien';

  @override
  String get brainGreeting => 'Wie kann ich heute helfen?';

  @override
  String get brainNotice =>
      'Keine Netzwerkanfragen: Wählen Sie ein vorbereitetes Szenario.';

  @override
  String get brainPromptInbox => 'Posteingang prüfen';

  @override
  String get brainPromptPlan => 'Tag planen';

  @override
  String get brainPromptReport => 'Bericht vorbereiten';

  @override
  String get brainResponseInbox =>
      'Lokales Demo-Szenario: zuerst zwei ungelesene E-Mails, dann der Wochenplan. Dies ist keine Analyse echter Post.';

  @override
  String get brainResponsePlan =>
      'Lokales Demo-Szenario: Meeting um 10:00, Audit um 13:30, ruhiger Fokus nach 14:30. Daten aus dem Demo-Kalender.';

  @override
  String get brainResponseReport =>
      'Lokales Demo-Szenario: Berichtsstruktur — Ziel, Ergebnis, Risiken, nächster Schritt. Kein Text wurde an einen KI-Dienst gesendet.';

  @override
  String get demoResponse => 'Demo-Antwort';

  @override
  String get createTask => 'Aufgabe erstellen';

  @override
  String get localDraft => 'Lokaler Entwurf';

  @override
  String get toLocalList => 'Zur lokalen Liste';

  @override
  String get openCalendar => 'Kalender öffnen';

  @override
  String get demoAssistant => 'Demo-Assistent';

  @override
  String get quickActions => 'Schnellaktionen';

  @override
  String get quickActionsSubtitle => 'Das Wichtigste mit einem Tipp';

  @override
  String get close => 'Schließen';

  @override
  String get noServerData => 'Es werden keine Daten an einen Server gesendet';

  @override
  String get aboutVisualLab => 'Über Visual Lab';

  @override
  String get versionLabel =>
      'Version 0.5.30+36 · persönliches digitales Ökosystem';

  @override
  String get aboutLegalese =>
      'ORBIT 0.5. E-Mail, Termine, Aufgaben und Brain verwenden ausdrücklich gekennzeichnete lokale Demodaten.';

  @override
  String get aboutTech =>
      'Flutter + Impeller + Rive + natives Google Filament für Android.';

  @override
  String get settingsSaved => 'Einstellungen werden sofort gespeichert';

  @override
  String get interfaceGallery => 'Oberflächen-Galerie';

  @override
  String get livePreview => 'Live-Vorschau';

  @override
  String get qualityAutoSummary => 'Auto · adaptiv';

  @override
  String get qualityEcoSummary => 'Eco · statisch';

  @override
  String get qualityBalancedSummary => 'Balanced · moderate Tiefe';

  @override
  String get qualityUltraSummary => 'Ultra · maximale Details';

  @override
  String get qualityAutoDescription => 'Berücksichtigt Gerät und Systemgrenzen';

  @override
  String get qualityEcoDescription => 'Statische Szene mit minimalen Effekten';

  @override
  String get qualityBalancedDescription =>
      'Hintergrund bis 30 FPS, moderate Tiefe';

  @override
  String get qualityUltraDescription =>
      'Dynamisches Licht und maximale Details';

  @override
  String get interfaceAndMotion => 'Oberfläche und Bewegung';

  @override
  String get uiAnimations => 'Oberflächenanimationen';

  @override
  String get animationsDisableNotice =>
      'Das Deaktivieren stoppt auch Hintergrundszenen';

  @override
  String get comfortable => 'Komfortabel';

  @override
  String get compact => 'Kompakt';

  @override
  String systemLimits(String power, String memory) {
    return 'Systemgrenzen: Energiesparen $power, Speicherdruck $memory.';
  }

  @override
  String get enabled => 'aktiv';

  @override
  String get notDetected => 'nicht erkannt';

  @override
  String get present => 'vorhanden';

  @override
  String get absent => 'keiner';

  @override
  String accentColorValue(String value) {
    return 'Akzentfarbe $value';
  }

  @override
  String selectProfile(String profile) {
    return '$profile auswählen';
  }

  @override
  String get interfaceBreadcrumb =>
      'Einstellungen → Personalisierung → Oberfläche';

  @override
  String get goodMorningShort => 'Guten Morgen!';

  @override
  String get greetingMorning => 'Guten Morgen,\nAlexey!';

  @override
  String get greetingMorningShort => 'Guten Morgen!';

  @override
  String get greetingDay => 'Guten Tag,\nAlexey!';

  @override
  String get greetingDayShort => 'Guten Tag!';

  @override
  String get greetingEvening => 'Guten Abend,\nAlexey!';

  @override
  String get greetingEveningShort => 'Guten Abend!';

  @override
  String get greetingNight => 'Gute Nacht,\nAlexey!';

  @override
  String get greetingNightShort => 'Gute Nacht!';

  @override
  String get profileOneSubtitle => 'Vielseitig · tiefer Fokus';

  @override
  String get profileAtelierSubtitle => 'Atmosphärisch · präzise Eleganz';

  @override
  String get profileFlowSubtitle => 'Dynamisch · lebendiger digitaler Fluss';

  @override
  String get profileZenSubtitle => 'Hell · Luft und Konzentration';

  @override
  String get emailWeeklySender => 'Maria Sokolova';

  @override
  String get emailDesignSender => 'Ilya Volkov';

  @override
  String get emailProjectSender => 'ORBIT-Team';

  @override
  String get emailResearchSender => 'Anna Remizova';

  @override
  String get emailWeeklySubject => 'Wochenplan';

  @override
  String get emailWeeklyPreview =>
      'Hallo! Anbei der aktualisierte Plan für nächste Woche…';

  @override
  String get emailWeeklyBody =>
      'Hallo Alexey!\n\nAnbei ist der aktualisierte Plan für nächste Woche. Besprechen wir ihn im Meeting am Dienstag.\n\nIch habe die wichtigsten Etappen markiert, Zeit für eine ruhige Prüfung eingeplant und Raum für ungeplante Aufgaben gelassen.\n\nEinen schönen Tag!';

  @override
  String get emailDesignSubject => 'Designbesprechung';

  @override
  String get emailDesignPreview =>
      'Hier sind die aktuellen Varianten und kurze Kommentare…';

  @override
  String get emailDesignBody =>
      'Hallo!\n\nHier sind die aktuellen Varianten und kurze Kommentare. Mich interessiert besonders deine Meinung zur Listendichte und zum Verhalten der unteren Navigation.';

  @override
  String get emailProjectSubject => 'Projektaktualisierung';

  @override
  String get emailProjectPreview =>
      'Status, nächste Schritte und ruhiger Fokus auf das Wesentliche…';

  @override
  String get emailProjectBody =>
      'Hallo zusammen!\n\nDie Hauptphase ist abgeschlossen. Als Nächstes folgen Sichtprüfung, Gerätetests und die Übergabe an das Hauptprodukt.';

  @override
  String get emailResearchSubject => 'Meeting-Vorbereitung';

  @override
  String get emailResearchPreview =>
      'Materialien und Agenda im Inneren. Das Meeting dauert etwa eine Stunde…';

  @override
  String get emailResearchBody =>
      'Guten Tag!\n\nMaterialien und Agenda sind beigefügt. Ich schlage vor, zuerst Nutzerszenarien und dann visuelle Grenzen zu besprechen.';

  @override
  String get emailFocusSubject => 'Drei Gedanken für einen ruhigen Tag';

  @override
  String get emailFocusPreview =>
      'Beginnen Sie mit dem Wichtigsten und lassen Sie Raum für eine Pause…';

  @override
  String get emailFocusBody =>
      'Beginnen Sie mit dem Wichtigsten, lassen Sie Raum für eine Pause und schließen Sie den Tag mit einem kurzen Rückblick.\n\nDies ist eine Demo-E-Mail der lokalen ORBIT-Shell.';

  @override
  String get attachmentWeekPlan => 'Wochenplan.pdf · 2,4 MB';

  @override
  String get attachmentSchedule => 'Zeitplan.xlsx · 1,1 MB';

  @override
  String get attachmentPresentation => 'Präsentation.pdf · 7,8 MB';

  @override
  String get eventReviewTitle => 'Projektbesprechung';

  @override
  String get eventReviewMeta => 'Team · Online · 1 Std.';

  @override
  String get eventAuditTitle => 'Tenda-Prozessaudit';

  @override
  String get eventAuditMeta => 'Projekt · Recherche · 1 Std.';

  @override
  String get eventReportTitle => 'Bericht vorbereiten';

  @override
  String get eventReportMeta => 'Projekt / BAM · Fokus · 1 Std.';

  @override
  String get taskReportTitle => 'KPI-Bericht vorbereiten';

  @override
  String get taskPlanTitle => 'Entwicklungsplan aktualisieren';

  @override
  String get taskMaterialsTitle => 'Projektmaterialien freigeben';

  @override
  String get taskDataTitle => 'Daten an das Analysezentrum senden';

  @override
  String get projectStrategy => 'Strategie';

  @override
  String get projectVp => 'Projekt';

  @override
  String get projectVpBam => 'Projekt / BAM';

  @override
  String get demoUserInitials => 'AR';

  @override
  String get demoUserName => 'Alexey Romanov';

  @override
  String get noDue => 'Kein Fälligkeitsdatum';

  @override
  String demoReplyBody(Object preview) {
    return '\n\n—\nAntwort auf eine Demo-E-Mail: $preview';
  }

  @override
  String demoForwardBody(Object preview) {
    return '\n\n—\nWeitergeleitete Demo-E-Mail: $preview';
  }

  @override
  String get unread => 'Neu';

  @override
  String get diagnostics => 'Diagnose';

  @override
  String get textSize => 'Textgröße';

  @override
  String get textSizeStandard => 'Standard';

  @override
  String get textSizeLarge => 'Groß';

  @override
  String get textSizeExtraLarge => 'Sehr groß';

  @override
  String get newEvent => 'Neuer Termin';

  @override
  String get eventTitleHint => 'Titel des Termins';

  @override
  String get eventTime => 'Uhrzeit';

  @override
  String get eventCreated => 'Termin lokal gespeichert';

  @override
  String get taskDetails => 'Aufgabendetails';

  @override
  String get status => 'Status';

  @override
  String get priority => 'Priorität';

  @override
  String get priorityLow => 'Normal';

  @override
  String get priorityMedium => 'Mittel';

  @override
  String get priorityHigh => 'Hoch';

  @override
  String get markDone => 'Als erledigt markieren';

  @override
  String get markActive => 'Als aktiv markieren';

  @override
  String get localSaveFailed =>
      'Lokale Änderungen konnten nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get appearanceSaveFailed =>
      'Darstellung konnte nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get appearanceLoadFailed =>
      'Darstellung konnte nicht geladen werden. Bitte erneut versuchen.';

  @override
  String get localLoadFailed =>
      'Lokale Daten konnten nicht geladen werden. Bitte erneut versuchen.';

  @override
  String get appearanceCorrupted =>
      'Die Erscheinungsdaten sind beschädigt. Die Originaldaten wurden gesichert.';

  @override
  String get localDataCorrupted =>
      'Die lokalen Daten sind beschädigt. Die Originaldaten wurden gesichert.';

  @override
  String get exportBackup => 'Backup exportieren';

  @override
  String backupExported(Object path) {
    return 'Backup exportiert: $path';
  }

  @override
  String get backupExportFailed =>
      'Backup-Export fehlgeschlagen. Originaldaten bleiben unverändert.';

  @override
  String get resetCorruptData => 'Zurücksetzen';

  @override
  String get resetCorruptConfirm =>
      'Beschädigte Daten zurücksetzen? Die Originaldaten bleiben im Backup erhalten.';

  @override
  String get eventDetails => 'Termindetails';

  @override
  String get eventDescription => 'Beschreibung';

  @override
  String get eventLocation => 'Ort';

  @override
  String get eventOrganizer => 'Organisator';

  @override
  String get eventAttendees => 'Teilnehmer';

  @override
  String get eventConference => 'Online-Besprechung';

  @override
  String get joinMeeting => 'Besprechung beitreten';

  @override
  String get copyMeetingLink => 'Link kopieren';

  @override
  String get linkCopied => 'Link in die Zwischenablage kopiert';

  @override
  String get noDescription => 'Keine Beschreibung vorhanden';

  @override
  String get noLocation => 'Kein Ort angegeben';

  @override
  String get noAttendees => 'Keine Teilnehmer aufgeführt';

  @override
  String get noAttachments => 'Keine Anhänge vorhanden';

  @override
  String get openAttachment => 'Öffnen';

  @override
  String get statusAccepted => 'Zugesagt';

  @override
  String get statusDeclined => 'Abgelehnt';

  @override
  String get statusTentative => 'Vorläufig';

  @override
  String get statusAwaiting => 'Antwort ausstehend';

  @override
  String get gyroIntensity => '3D-Gyroskop-Parallaxe';

  @override
  String get gyroIntensityDesc =>
      'Reaktion auf Geräteneigung über Tiefenebenen';

  @override
  String get gyroOff => 'Aus';

  @override
  String get gyroSubtle => 'Dezent';

  @override
  String get gyroEnhanced => 'Verstärkt';

  @override
  String get lightingAndAtmosphere => 'Beleuchtung und Atmosphäre';

  @override
  String get lightingAndAtmosphereDesc =>
      'Tageslichtzyklus und Sonnenstand im Tagesverlauf';

  @override
  String get atmosphereAuto => 'Auto (Uhrzeit)';

  @override
  String get atmosphereDawn => 'Morgendämmerung';

  @override
  String get atmosphereDay => 'Tag';

  @override
  String get atmosphereSunset => 'Sonnenuntergang';

  @override
  String get atmosphereNight => 'Nacht';
}
