// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'ORBIT Visual Lab';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get mail => 'Courrier';

  @override
  String get calendar => 'Calendrier';

  @override
  String get tasks => 'Tâches';

  @override
  String get more => 'Plus';

  @override
  String get back => 'Retour';

  @override
  String get settings => 'Réglages';

  @override
  String get inbox => 'Boîte de réception';

  @override
  String get newEmail => 'Nouvel e-mail';

  @override
  String get search => 'Rechercher';

  @override
  String get all => 'Tous';

  @override
  String get important => 'Importants';

  @override
  String get importantSingle => 'Important';

  @override
  String get emptyHere => 'Rien ici pour le moment';

  @override
  String unreadSummary(int count) {
    return '$count non lus · courrier de démonstration';
  }

  @override
  String get mailDemoNotice =>
      'Les gestes et actions serveur sont désactivés : les données existent uniquement dans cette démo.';

  @override
  String toMe(String email) {
    return 'À : moi · $email';
  }

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get demoAttachment => 'Pièce jointe de démonstration';

  @override
  String get demoAttachmentNotice =>
      'Ce fichier est une donnée de démonstration et ne peut pas être téléchargé.';

  @override
  String get reply => 'Répondre';

  @override
  String get replyAll => 'Répondre à tous';

  @override
  String get forward => 'Transférer';

  @override
  String get draftSubtitle => 'Brouillon local · envoi désactivé';

  @override
  String get saveDraft => 'Enregistrer le brouillon';

  @override
  String get draftSaved =>
      'Brouillon enregistré localement. E-mail non envoyé.';

  @override
  String get draftUnsavedChanges => 'modifications non enregistrées';

  @override
  String get draftSavedState => 'toutes les modifications sont enregistrées';

  @override
  String get to => 'À';

  @override
  String get subject => 'Objet';

  @override
  String get subjectHint => 'De quoi s’agit-il ?';

  @override
  String get bodyHint => 'Texte de l’e-mail…';

  @override
  String get formatting => 'Mise en forme indisponible en DEMO';

  @override
  String get attachmentsDisabled => 'Pièces jointes désactivées';

  @override
  String get localFilesDisabled =>
      'Impossible de joindre des fichiers locaux dans Visual Lab.';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get add => 'Ajouter';

  @override
  String get understood => 'Compris';

  @override
  String get demoLabel => 'DÉMO · DONNÉES LOCALES';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDemo =>
      'Les notifications serveur ne sont pas connectées dans Visual Lab.';

  @override
  String get goodMorning => 'Bonjour,\nAlexey !';

  @override
  String dateFocus(String date) {
    return '$date · concentration sereine';
  }

  @override
  String get newMetric => 'nouveaux';

  @override
  String get eventsMetric => 'événements';

  @override
  String get tasksMetric => 'tâches';

  @override
  String get upcoming => 'À venir';

  @override
  String get actionCenter => 'Centre d’actions';

  @override
  String get dayRhythm => 'rythme du jour';

  @override
  String get yourSpace => 'Votre espace';

  @override
  String completedSummary(int completed, int total) {
    return '$completed tâches sur $total terminées. Prochain moment calme après 13 h 30.';
  }

  @override
  String get flow => 'Flux';

  @override
  String get focus => 'Concentration';

  @override
  String get emailAction => 'E-mail';

  @override
  String get taskAction => 'Tâche';

  @override
  String get eventAction => 'Événement';

  @override
  String get experimentRive => 'EXPERIMENT B · RIVE';

  @override
  String get experimentFilament => 'EXPERIMENT C · FILAMENT';

  @override
  String get liveBrandScene => 'Atmosphère interactive';

  @override
  String get pbrScene => 'Véritable scène PBR';

  @override
  String get compareRenderers => 'Comparer les moteurs →';

  @override
  String graphicsUnavailable(String reason) {
    return 'Moteur graphique indisponible. Static/Eco est actif ; l’interface reste utilisable.\n$reason';
  }

  @override
  String get filamentUnsupported =>
      'Filament est disponible dans la version Android. Le rendu statique/procédural de secours est actif sur cette plateforme.';

  @override
  String get riveAtmosphereSemantics =>
      'Scène Rive ORBIT interactive. Touchez pour déclencher une impulsion.';

  @override
  String get riveMarkSemantics =>
      'Logo ORBIT animé. Touchez pour déclencher une impulsion.';

  @override
  String get activeRenderer => 'Moteur actif';

  @override
  String get rendererDescription =>
      'Le choix s’applique immédiatement et est enregistré. La navigation et les données de démo sont conservées.';

  @override
  String get staticRendererTitle => 'A · Static / Eco';

  @override
  String get staticRendererSubtitle =>
      'Scène Flutter/Impeller statique détaillée, sans boucle d’images continue.';

  @override
  String get riveRendererTitle => 'B · Flutter + Impeller + Rive';

  @override
  String get riveRendererSubtitle =>
      'Paysage atmosphérique, animation orbitale et déclencheur Rive Pulse au toucher.';

  @override
  String get filamentRendererTitle => 'C · Flutter + native Google Filament';

  @override
  String get filamentRendererSubtitle =>
      'SurfaceView Android native avec relief PBR, soleil, nuages et caméra.';

  @override
  String get visualLabSubtitle =>
      'Comparer les moteurs sur le même écran Aujourd’hui';

  @override
  String get openToday => 'Ouvrir Aujourd’hui';

  @override
  String get measurementStatus => 'État des mesures';

  @override
  String get frameMetrics => 'FPS / P95 frame time';

  @override
  String get resourceMetrics => 'RAM / GPU / énergie / température';

  @override
  String get physicalRun => 'Exécution sur appareil physique';

  @override
  String get performanceMethod =>
      'Une comparaison fiable exige des builds profile/release sur le même appareil Android physique. Méthode et commandes : docs/PERFORMANCE.md.';

  @override
  String get graphicsLog => 'Journal de repli graphique';

  @override
  String get nativePbr => 'NATIVE · PBR';

  @override
  String get androidFallback => 'ANDROID ONLY · FALLBACK';

  @override
  String get day => 'Jour';

  @override
  String get week => 'Semaine';

  @override
  String get month => 'Mois';

  @override
  String get agenda => 'Agenda';

  @override
  String get allUpcoming => 'Tous les événements à venir';

  @override
  String get freeTomorrow =>
      'Demain est libre après 16 h — un bon moment pour travailler calmement.';

  @override
  String get morning => 'matin';

  @override
  String get events => 'événements';

  @override
  String get focusHours => 'heures de concentration';

  @override
  String get progressDay => 'Progression du jour';

  @override
  String get active => 'Actives';

  @override
  String get projects => 'Projets';

  @override
  String get addTask => 'Ajouter une tâche';

  @override
  String get quickAdd => 'Ajout rapide';

  @override
  String get newTask => 'Nouvelle tâche';

  @override
  String get taskHint => 'Que faut-il faire ?';

  @override
  String completedOf(int completed, int total) {
    return '$completed sur $total terminées · logique locale';
  }

  @override
  String get localList => 'Liste locale';

  @override
  String get settingsSubtitle => 'Espace personnel · Visual Lab';

  @override
  String get personalization => 'Personnalisation';

  @override
  String get interface => 'Interface';

  @override
  String get graphicsQuality => 'Qualité graphique';

  @override
  String get visualLabExperiments => 'Static · Rive · Filament · modes A/B/C';

  @override
  String get accentColor => 'Couleur d’accent';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get density => 'Densité';

  @override
  String get motion => 'Mouvement';

  @override
  String get routeNotFound => 'Route introuvable';

  @override
  String get routeStateSaved =>
      'L’état de l’interface est conservé. Revenez à l’accueil.';

  @override
  String get yesterday => 'Hier';

  @override
  String get mondayShort => 'Lun';

  @override
  String get done => 'Terminé';

  @override
  String get tomorrow => 'Demain';

  @override
  String todayTime(String time) {
    return 'Aujourd’hui, $time';
  }

  @override
  String get dateNovember5 => '5 novembre';

  @override
  String get system => 'Système';

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
  String get brainDemoSubtitle => 'Démo du futur assistant · scénarios locaux';

  @override
  String get brainGreeting => 'Comment puis-je vous aider ?';

  @override
  String get brainNotice =>
      'Aucune requête réseau : choisissez l’un des scénarios préparés.';

  @override
  String get brainPromptInbox => 'Examiner la boîte de réception';

  @override
  String get brainPromptPlan => 'Planifier ma journée';

  @override
  String get brainPromptReport => 'Préparer le rapport';

  @override
  String get brainResponseInbox =>
      'Scénario local de démonstration : deux e-mails non lus, puis le plan hebdomadaire. Ceci n’est pas une analyse de vrais e-mails.';

  @override
  String get brainResponsePlan =>
      'Scénario local de démonstration : réunion à 10 h, audit à 13 h 30, concentration après 14 h 30. Données du calendrier de démonstration.';

  @override
  String get brainResponseReport =>
      'Scénario local de démonstration : structure du rapport — objectif, résultat, risques, prochaine étape. Aucun texte n’a été envoyé à un service d’IA.';

  @override
  String get demoResponse => 'Réponse de démonstration';

  @override
  String get createTask => 'Créer une tâche';

  @override
  String get localDraft => 'Brouillon local';

  @override
  String get toLocalList => 'Vers la liste locale';

  @override
  String get openCalendar => 'Ouvrir le calendrier';

  @override
  String get demoAssistant => 'Assistant de démonstration';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get quickActionsSubtitle => 'L’essentiel en un geste';

  @override
  String get close => 'Fermer';

  @override
  String get noServerData => 'Aucune donnée n’est envoyée à un serveur';

  @override
  String get aboutVisualLab => 'À propos de Visual Lab';

  @override
  String get versionLabel =>
      'Version 0.5.30+36 · écosystème numérique personnel';

  @override
  String get aboutLegalese =>
      'ORBIT 0.5. La messagerie, les événements, les tâches et Brain utilisent des données de démonstration locales explicitement identifiées.';

  @override
  String get aboutTech =>
      'Flutter + Impeller + Rive + Google Filament natif pour Android.';

  @override
  String get settingsSaved => 'Les réglages sont enregistrés immédiatement';

  @override
  String get interfaceGallery => 'Galerie d’interfaces';

  @override
  String get livePreview => 'aperçu en direct';

  @override
  String get qualityAutoSummary => 'Auto · adaptatif';

  @override
  String get qualityEcoSummary => 'Eco · statique';

  @override
  String get qualityBalancedSummary => 'Balanced · profondeur modérée';

  @override
  String get qualityUltraSummary => 'Ultra · détails maximaux';

  @override
  String get qualityAutoDescription =>
      'Tient compte de l’appareil et des limites système';

  @override
  String get qualityEcoDescription => 'Scène statique avec effets minimaux';

  @override
  String get qualityBalancedDescription =>
      'Arrière-plan jusqu’à 30 FPS, profondeur modérée';

  @override
  String get qualityUltraDescription => 'Lumière dynamique et détails maximaux';

  @override
  String get interfaceAndMotion => 'Interface et mouvement';

  @override
  String get uiAnimations => 'Animations de l’interface';

  @override
  String get animationsDisableNotice =>
      'La désactivation arrête aussi les scènes d’arrière-plan';

  @override
  String get comfortable => 'Confortable';

  @override
  String get compact => 'Compacte';

  @override
  String systemLimits(String power, String memory) {
    return 'Limites système : économie d’énergie $power, pression mémoire $memory.';
  }

  @override
  String get enabled => 'activée';

  @override
  String get notDetected => 'non détectée';

  @override
  String get present => 'présente';

  @override
  String get absent => 'absente';

  @override
  String accentColorValue(String value) {
    return 'Couleur d’accent $value';
  }

  @override
  String selectProfile(String profile) {
    return 'Choisir $profile';
  }

  @override
  String get interfaceBreadcrumb => 'Réglages → Personnalisation → Interface';

  @override
  String get goodMorningShort => 'Bonjour !';

  @override
  String get greetingMorning => 'Bonjour,\nAlexey !';

  @override
  String get greetingMorningShort => 'Bonjour !';

  @override
  String get greetingDay => 'Bon après-midi,\nAlexey !';

  @override
  String get greetingDayShort => 'Bon après-midi !';

  @override
  String get greetingEvening => 'Bonsoir,\nAlexey !';

  @override
  String get greetingEveningShort => 'Bonsoir !';

  @override
  String get greetingNight => 'Bonne nuit,\nAlexey !';

  @override
  String get greetingNightShort => 'Bonne nuit !';

  @override
  String get profileOneSubtitle => 'Polyvalent · concentration profonde';

  @override
  String get profileAtelierSubtitle => 'Atmosphérique · précision raffinée';

  @override
  String get profileFlowSubtitle => 'Dynamique · flux numérique vivant';

  @override
  String get profileZenSubtitle => 'Lumineux · espace et concentration';

  @override
  String get emailWeeklySender => 'Maria Sokolova';

  @override
  String get emailDesignSender => 'Ilya Volkov';

  @override
  String get emailProjectSender => 'Équipe ORBIT';

  @override
  String get emailResearchSender => 'Anna Remizova';

  @override
  String get emailWeeklySubject => 'Plan hebdomadaire';

  @override
  String get emailWeeklyPreview =>
      'Bonjour ! Voici le plan mis à jour pour la semaine prochaine…';

  @override
  String get emailWeeklyBody =>
      'Bonjour Alexey !\n\nVoici le plan mis à jour pour la semaine prochaine. Discutons-en lors de la réunion de mardi.\n\nJ’ai mis en évidence les étapes clés, prévu du temps pour une relecture sereine et laissé de la place aux imprévus.\n\nBonne journée !';

  @override
  String get emailDesignSubject => 'Revue de design';

  @override
  String get emailDesignPreview =>
      'Voici les dernières propositions et de brefs commentaires…';

  @override
  String get emailDesignBody =>
      'Bonjour !\n\nVoici les dernières propositions et de brefs commentaires. Ton avis sur la densité de la liste et le comportement de la navigation inférieure m’intéresse particulièrement.';

  @override
  String get emailProjectSubject => 'Mise à jour du projet';

  @override
  String get emailProjectPreview =>
      'Statut, prochaines étapes et concentration sur l’essentiel…';

  @override
  String get emailProjectBody =>
      'Bonjour à tous !\n\nL’étape principale est terminée. Ensuite : revue visuelle, tests sur appareils et préparation du transfert vers le produit principal.';

  @override
  String get emailResearchSubject => 'Préparation de la réunion';

  @override
  String get emailResearchPreview =>
      'Documents et ordre du jour inclus. La réunion durera environ une heure…';

  @override
  String get emailResearchBody =>
      'Bonjour !\n\nLes documents et l’ordre du jour sont inclus. Je propose de discuter d’abord des scénarios utilisateurs, puis des contraintes visuelles.';

  @override
  String get emailFocusSubject => 'Trois idées pour une journée sereine';

  @override
  String get emailFocusPreview =>
      'Commencez par l’essentiel et laissez place à une pause…';

  @override
  String get emailFocusBody =>
      'Commencez par l’essentiel, laissez place à une pause et terminez la journée par un bref bilan.\n\nCeci est un e-mail de démonstration de l’interface ORBIT locale.';

  @override
  String get attachmentWeekPlan => 'Plan_hebdomadaire.pdf · 2,4 Mo';

  @override
  String get attachmentSchedule => 'Planning.xlsx · 1,1 Mo';

  @override
  String get attachmentPresentation => 'Présentation.pdf · 7,8 Mo';

  @override
  String get eventReviewTitle => 'Réunion de revue du projet';

  @override
  String get eventReviewMeta => 'Équipe · En ligne · 1 h';

  @override
  String get eventAuditTitle => 'Audit des processus Tenda';

  @override
  String get eventAuditMeta => 'Projet · Recherche · 1 h';

  @override
  String get eventReportTitle => 'Préparer le rapport';

  @override
  String get eventReportMeta => 'Projet / BAM · Concentration · 1 h';

  @override
  String get taskReportTitle => 'Préparer le rapport KPI';

  @override
  String get taskPlanTitle => 'Actualiser le plan de développement';

  @override
  String get taskMaterialsTitle => 'Valider les documents du projet';

  @override
  String get taskDataTitle => 'Envoyer les données au centre d’analyse';

  @override
  String get projectStrategy => 'Stratégie';

  @override
  String get projectVp => 'Projet';

  @override
  String get projectVpBam => 'Projet / BAM';

  @override
  String get demoUserInitials => 'AR';

  @override
  String get demoUserName => 'Alexey Romanov';

  @override
  String get noDue => 'Sans échéance';

  @override
  String demoReplyBody(Object preview) {
    return '\n\n—\nRéponse à un e-mail de démonstration : $preview';
  }

  @override
  String demoForwardBody(Object preview) {
    return '\n\n—\nE-mail de démonstration transféré : $preview';
  }

  @override
  String get unread => 'Non lus';

  @override
  String get diagnostics => 'Diagnostic';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get textSizeStandard => 'Standard';

  @override
  String get textSizeLarge => 'Grand';

  @override
  String get textSizeExtraLarge => 'Très grand';

  @override
  String get newEvent => 'Nouvel événement';

  @override
  String get eventTitleHint => 'Titre de l’événement';

  @override
  String get eventTime => 'Heure';

  @override
  String get eventCreated => 'Événement enregistré localement';

  @override
  String get taskDetails => 'Détails de la tâche';

  @override
  String get status => 'Statut';

  @override
  String get priority => 'Priorité';

  @override
  String get priorityLow => 'Normale';

  @override
  String get priorityMedium => 'Moyenne';

  @override
  String get priorityHigh => 'Haute';

  @override
  String get markDone => 'Marquer comme terminée';

  @override
  String get markActive => 'Marquer comme active';

  @override
  String get localSaveFailed =>
      'Impossible d’enregistrer les modifications locales. Réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get appearanceSaveFailed =>
      'Impossible d’enregistrer l’apparence. Réessayez.';

  @override
  String get appearanceLoadFailed =>
      'Impossible de charger l’apparence. Réessayez.';

  @override
  String get localLoadFailed =>
      'Impossible de charger les données locales. Réessayez.';

  @override
  String get appearanceCorrupted =>
      'Les données d’apparence sont corrompues. La charge originale est conservée dans une sauvegarde.';

  @override
  String get localDataCorrupted =>
      'Les données locales sont corrompues. La charge originale est conservée dans une sauvegarde.';

  @override
  String get exportBackup => 'Exporter la sauvegarde';

  @override
  String backupExported(Object path) {
    return 'Sauvegarde exportée : $path';
  }

  @override
  String get backupExportFailed =>
      'Échec de l’export. Les données originales sont inchangées.';

  @override
  String get resetCorruptData => 'Réinitialiser';

  @override
  String get resetCorruptConfirm =>
      'Réinitialiser les données corrompues ? La charge originale restera dans la sauvegarde.';

  @override
  String get eventDetails => 'Détails de l\'événement';

  @override
  String get eventDescription => 'Description';

  @override
  String get eventLocation => 'Lieu';

  @override
  String get eventOrganizer => 'Organisateur';

  @override
  String get eventAttendees => 'Participants';

  @override
  String get eventConference => 'Réunion en ligne';

  @override
  String get joinMeeting => 'Rejoindre la réunion';

  @override
  String get copyMeetingLink => 'Copier le lien';

  @override
  String get linkCopied => 'Lien copié dans le presse-papiers';

  @override
  String get noDescription => 'Aucune description fournie';

  @override
  String get noLocation => 'Aucun lieu spécifié';

  @override
  String get noAttendees => 'Aucun participant répertorié';

  @override
  String get noAttachments => 'Aucune pièce jointe';

  @override
  String get openAttachment => 'Ouvrir';

  @override
  String get statusAccepted => 'Accepté';

  @override
  String get statusDeclined => 'Refusé';

  @override
  String get statusTentative => 'Provisoire';

  @override
  String get statusAwaiting => 'En attente de réponse';

  @override
  String get gyroIntensity => 'Parallaxe 3D gyroscopique';

  @override
  String get gyroIntensityDesc =>
      'Réponse physique à l\'inclinaison sur les plans de profondeur';

  @override
  String get gyroOff => 'Désactivé';

  @override
  String get gyroSubtle => 'Subtil';

  @override
  String get gyroEnhanced => 'Accentué';

  @override
  String get lightingAndAtmosphere => 'Éclairage et atmosphère';

  @override
  String get lightingAndAtmosphereDesc =>
      'Cycle d\'éclairage diurne et position du soleil';

  @override
  String get atmosphereAuto => 'Auto (heure)';

  @override
  String get atmosphereDawn => 'Aurore';

  @override
  String get atmosphereDay => 'Jour';

  @override
  String get atmosphereSunset => 'Coucher';

  @override
  String get atmosphereNight => 'Nuit';
}
