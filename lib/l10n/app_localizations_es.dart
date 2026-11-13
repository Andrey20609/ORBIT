// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'ORBIT Visual Lab';

  @override
  String get today => 'Hoy';

  @override
  String get mail => 'Correo';

  @override
  String get calendar => 'Calendario';

  @override
  String get tasks => 'Tareas';

  @override
  String get more => 'Más';

  @override
  String get back => 'Atrás';

  @override
  String get settings => 'Ajustes';

  @override
  String get inbox => 'Bandeja de entrada';

  @override
  String get newEmail => 'Nuevo correo';

  @override
  String get search => 'Buscar';

  @override
  String get all => 'Todos';

  @override
  String get important => 'Importantes';

  @override
  String get importantSingle => 'Importante';

  @override
  String get emptyHere => 'Aún no hay nada aquí';

  @override
  String unreadSummary(int count) {
    return '$count sin leer · correo de demostración';
  }

  @override
  String get mailDemoNotice =>
      'Los gestos y las acciones del servidor están desactivados: los datos solo existen en esta demostración.';

  @override
  String toMe(String email) {
    return 'Para: mí · $email';
  }

  @override
  String get attachments => 'Adjuntos';

  @override
  String get demoAttachment => 'Adjunto de demostración';

  @override
  String get demoAttachmentNotice =>
      'Este archivo es un registro de demostración y no se puede descargar.';

  @override
  String get reply => 'Responder';

  @override
  String get replyAll => 'Responder a todos';

  @override
  String get forward => 'Reenviar';

  @override
  String get draftSubtitle => 'Borrador local · envío desactivado';

  @override
  String get saveDraft => 'Guardar borrador';

  @override
  String get draftSaved => 'Borrador guardado localmente. Correo no enviado.';

  @override
  String get draftUnsavedChanges => 'cambios sin guardar';

  @override
  String get draftSavedState => 'todos los cambios guardados';

  @override
  String get to => 'Para';

  @override
  String get subject => 'Asunto';

  @override
  String get subjectHint => '¿De qué trata?';

  @override
  String get bodyHint => 'Texto del correo…';

  @override
  String get formatting => 'Formato no disponible en DEMO';

  @override
  String get attachmentsDisabled => 'Adjuntos desactivados';

  @override
  String get localFilesDisabled =>
      'No se pueden adjuntar archivos locales en Visual Lab.';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get add => 'Añadir';

  @override
  String get understood => 'Entendido';

  @override
  String get demoLabel => 'DEMO · DATOS LOCALES';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notificationsDemo =>
      'Las notificaciones del servidor no están conectadas en Visual Lab.';

  @override
  String get goodMorning => 'Buenos días,\n¡Alexey!';

  @override
  String dateFocus(String date) {
    return '$date · concentración tranquila';
  }

  @override
  String get newMetric => 'nuevos';

  @override
  String get eventsMetric => 'eventos';

  @override
  String get tasksMetric => 'tareas';

  @override
  String get upcoming => 'Próximo';

  @override
  String get actionCenter => 'Centro de acciones';

  @override
  String get dayRhythm => 'ritmo del día';

  @override
  String get yourSpace => 'Tu espacio';

  @override
  String completedSummary(int completed, int total) {
    return '$completed de $total tareas completadas. El próximo intervalo tranquilo empieza después de las 13:30.';
  }

  @override
  String get flow => 'Flujo';

  @override
  String get focus => 'Concentración';

  @override
  String get emailAction => 'Correo';

  @override
  String get taskAction => 'Tarea';

  @override
  String get eventAction => 'Evento';

  @override
  String get experimentRive => 'EXPERIMENT B · RIVE';

  @override
  String get experimentFilament => 'EXPERIMENT C · FILAMENT';

  @override
  String get liveBrandScene => 'Atmósfera interactiva';

  @override
  String get pbrScene => 'Escena PBR real';

  @override
  String get compareRenderers => 'Comparar renderizadores →';

  @override
  String graphicsUnavailable(String reason) {
    return 'Renderizador gráfico no disponible. Static/Eco está activo; la interfaz sigue funcionando.\n$reason';
  }

  @override
  String get filamentUnsupported =>
      'Filament está disponible en la compilación de Android. El renderizado estático/procedural de reserva está activo en esta plataforma.';

  @override
  String get riveAtmosphereSemantics =>
      'Escena Rive ORBIT interactiva. Toca para activar un impulso.';

  @override
  String get riveMarkSemantics =>
      'Logotipo ORBIT animado. Toca para activar un impulso.';

  @override
  String get activeRenderer => 'Renderizador activo';

  @override
  String get rendererDescription =>
      'La selección se aplica de inmediato y se guarda. La navegación y los datos de demostración se conservan.';

  @override
  String get staticRendererTitle => 'A · Static / Eco';

  @override
  String get staticRendererSubtitle =>
      'Escena Flutter/Impeller estática y detallada sin un bucle continuo de fotogramas.';

  @override
  String get riveRendererTitle => 'B · Flutter + Impeller + Rive';

  @override
  String get riveRendererSubtitle =>
      'Paisaje atmosférico, animación orbital y activador Rive Pulse al tocar.';

  @override
  String get filamentRendererTitle => 'C · Flutter + native Google Filament';

  @override
  String get filamentRendererSubtitle =>
      'SurfaceView nativo de Android con terreno PBR, sol, nubes y cámara.';

  @override
  String get visualLabSubtitle =>
      'Compara renderizadores en la misma pantalla Hoy';

  @override
  String get openToday => 'Abrir Hoy';

  @override
  String get measurementStatus => 'Estado de las mediciones';

  @override
  String get frameMetrics => 'FPS / P95 frame time';

  @override
  String get resourceMetrics => 'RAM / GPU / energía / temperatura';

  @override
  String get physicalRun => 'Ejecución en dispositivo físico';

  @override
  String get performanceMethod =>
      'Una comparación justa requiere compilaciones profile/release en el mismo dispositivo Android físico. Consulta docs/PERFORMANCE.md para ver el método y los comandos.';

  @override
  String get graphicsLog => 'Registro de reserva gráfica';

  @override
  String get nativePbr => 'NATIVE · PBR';

  @override
  String get androidFallback => 'ANDROID ONLY · FALLBACK';

  @override
  String get day => 'Día';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mes';

  @override
  String get agenda => 'Agenda';

  @override
  String get allUpcoming => 'Todos los próximos eventos';

  @override
  String get freeTomorrow =>
      'Mañana está libre después de las 16:00: un buen momento para trabajar con calma.';

  @override
  String get morning => 'mañana';

  @override
  String get events => 'eventos';

  @override
  String get focusHours => 'horas de concentración';

  @override
  String get progressDay => 'Progreso del día';

  @override
  String get active => 'Activas';

  @override
  String get projects => 'Proyectos';

  @override
  String get addTask => 'Añadir tarea';

  @override
  String get quickAdd => 'Añadir rápido';

  @override
  String get newTask => 'Nueva tarea';

  @override
  String get taskHint => '¿Qué hay que hacer?';

  @override
  String completedOf(int completed, int total) {
    return '$completed de $total completadas · lógica local';
  }

  @override
  String get localList => 'Lista local';

  @override
  String get settingsSubtitle => 'Espacio personal · Visual Lab';

  @override
  String get personalization => 'Personalización';

  @override
  String get interface => 'Interfaz';

  @override
  String get graphicsQuality => 'Calidad gráfica';

  @override
  String get visualLabExperiments => 'Static · Rive · Filament · modos A/B/C';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get density => 'Densidad';

  @override
  String get motion => 'Movimiento';

  @override
  String get routeNotFound => 'Ruta no encontrada';

  @override
  String get routeStateSaved =>
      'El estado de la interfaz se conserva. Vuelve a la pantalla principal.';

  @override
  String get yesterday => 'Ayer';

  @override
  String get mondayShort => 'Lun';

  @override
  String get done => 'Completado';

  @override
  String get tomorrow => 'Mañana';

  @override
  String todayTime(String time) {
    return 'Hoy, $time';
  }

  @override
  String get dateNovember5 => '5 de noviembre';

  @override
  String get system => 'Sistema';

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
      'Demostración del futuro asistente · escenarios locales';

  @override
  String get brainGreeting => '¿En qué puedo ayudarte hoy?';

  @override
  String get brainNotice =>
      'Sin solicitudes de red: elige uno de los escenarios preparados.';

  @override
  String get brainPromptInbox => 'Revisar bandeja de entrada';

  @override
  String get brainPromptPlan => 'Planificar mi día';

  @override
  String get brainPromptReport => 'Preparar informe';

  @override
  String get brainResponseInbox =>
      'Escenario local de demostración: primero dos correos sin leer y después el plan semanal. No es un análisis de correo real.';

  @override
  String get brainResponsePlan =>
      'Escenario local de demostración: reunión a las 10:00, auditoría a las 13:30 y concentración tranquila después de las 14:30. Datos del calendario de demostración.';

  @override
  String get brainResponseReport =>
      'Escenario local de demostración: estructura del informe — objetivo, resultado, riesgos y siguiente paso. No se envió texto a ningún servicio de IA.';

  @override
  String get demoResponse => 'Respuesta de demostración';

  @override
  String get createTask => 'Crear tarea';

  @override
  String get localDraft => 'Borrador local';

  @override
  String get toLocalList => 'A la lista local';

  @override
  String get openCalendar => 'Abrir calendario';

  @override
  String get demoAssistant => 'Asistente de demostración';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get quickActionsSubtitle => 'Lo esencial con un toque';

  @override
  String get close => 'Cerrar';

  @override
  String get noServerData => 'No se envían datos a ningún servidor';

  @override
  String get aboutVisualLab => 'Acerca de Visual Lab';

  @override
  String get versionLabel => 'Versión 0.5.30+36 · ecosistema digital personal';

  @override
  String get aboutLegalese =>
      'ORBIT 0.5. El correo, los eventos, las tareas y Brain utilizan datos de demostración locales claramente identificados.';

  @override
  String get aboutTech =>
      'Flutter + Impeller + Rive + Google Filament nativo para Android.';

  @override
  String get settingsSaved => 'Los ajustes se guardan de inmediato';

  @override
  String get interfaceGallery => 'Galería de interfaces';

  @override
  String get livePreview => 'vista previa en vivo';

  @override
  String get qualityAutoSummary => 'Auto · adaptativo';

  @override
  String get qualityEcoSummary => 'Eco · estático';

  @override
  String get qualityBalancedSummary => 'Balanced · profundidad moderada';

  @override
  String get qualityUltraSummary => 'Ultra · máximo detalle';

  @override
  String get qualityAutoDescription =>
      'Tiene en cuenta el dispositivo y los límites del sistema';

  @override
  String get qualityEcoDescription => 'Escena estática con efectos mínimos';

  @override
  String get qualityBalancedDescription =>
      'Fondo de hasta 30 FPS y profundidad moderada';

  @override
  String get qualityUltraDescription => 'Luz dinámica y máximo detalle';

  @override
  String get interfaceAndMotion => 'Interfaz y movimiento';

  @override
  String get uiAnimations => 'Animaciones de la interfaz';

  @override
  String get animationsDisableNotice =>
      'Desactivarlas también detiene las escenas de fondo';

  @override
  String get comfortable => 'Cómoda';

  @override
  String get compact => 'Compacta';

  @override
  String systemLimits(String power, String memory) {
    return 'Límites del sistema: ahorro de energía $power, presión de memoria $memory.';
  }

  @override
  String get enabled => 'activado';

  @override
  String get notDetected => 'no detectado';

  @override
  String get present => 'presente';

  @override
  String get absent => 'ausente';

  @override
  String accentColorValue(String value) {
    return 'Color de acento $value';
  }

  @override
  String selectProfile(String profile) {
    return 'Seleccionar $profile';
  }

  @override
  String get interfaceBreadcrumb => 'Ajustes → Personalización → Interfaz';

  @override
  String get goodMorningShort => '¡Buenos días!';

  @override
  String get greetingMorning => 'Buenos días,\n¡Alexey!';

  @override
  String get greetingMorningShort => '¡Buenos días!';

  @override
  String get greetingDay => 'Buenas tardes,\n¡Alexey!';

  @override
  String get greetingDayShort => '¡Buenas tardes!';

  @override
  String get greetingEvening => 'Buenas noches,\n¡Alexey!';

  @override
  String get greetingEveningShort => '¡Buenas noches!';

  @override
  String get greetingNight => 'Buenas noches,\n¡Alexey!';

  @override
  String get greetingNightShort => '¡Buenas noches!';

  @override
  String get profileOneSubtitle => 'Versátil · concentración profunda';

  @override
  String get profileAtelierSubtitle => 'Atmosférico · precisión refinada';

  @override
  String get profileFlowSubtitle => 'Dinámico · flujo digital vivo';

  @override
  String get profileZenSubtitle => 'Luminoso · aire y concentración';

  @override
  String get emailWeeklySender => 'Maria Sokolova';

  @override
  String get emailDesignSender => 'Ilya Volkov';

  @override
  String get emailProjectSender => 'Equipo ORBIT';

  @override
  String get emailResearchSender => 'Anna Remizova';

  @override
  String get emailWeeklySubject => 'Plan semanal';

  @override
  String get emailWeeklyPreview =>
      '¡Hola! Adjunto el plan actualizado para la próxima semana…';

  @override
  String get emailWeeklyBody =>
      '¡Hola, Alexey!\n\nAdjunto el plan actualizado para la próxima semana. Hablemos de él en la reunión del martes.\n\nDestaqué las etapas clave, reservé tiempo para una revisión tranquila y dejé espacio para tareas imprevistas.\n\n¡Que tengas un buen día!';

  @override
  String get emailDesignSubject => 'Revisión de diseño';

  @override
  String get emailDesignPreview =>
      'Aquí están las últimas propuestas y breves comentarios…';

  @override
  String get emailDesignBody =>
      '¡Hola!\n\nAquí están las últimas propuestas y breves comentarios. Me interesa especialmente tu opinión sobre la densidad de la lista y el comportamiento de la navegación inferior.';

  @override
  String get emailProjectSubject => 'Actualización del proyecto';

  @override
  String get emailProjectPreview =>
      'Estado, próximos pasos y concentración en lo importante…';

  @override
  String get emailProjectBody =>
      '¡Hola a todos!\n\nLa etapa principal está terminada. A continuación: revisión visual, pruebas en dispositivos y preparación de la entrega al producto principal.';

  @override
  String get emailResearchSubject => 'Preparación de la reunión';

  @override
  String get emailResearchPreview =>
      'Materiales y agenda incluidos. La reunión durará aproximadamente una hora…';

  @override
  String get emailResearchBody =>
      '¡Buenas tardes!\n\nLos materiales y la agenda están incluidos. Propongo hablar primero de los escenarios de usuario y después de las limitaciones visuales.';

  @override
  String get emailFocusSubject => 'Tres ideas para un día tranquilo';

  @override
  String get emailFocusPreview =>
      'Empieza por lo importante y deja espacio para una pausa…';

  @override
  String get emailFocusBody =>
      'Empieza por lo importante, deja espacio para una pausa y termina el día con una breve revisión.\n\nEste es un correo de demostración de la interfaz ORBIT local.';

  @override
  String get attachmentWeekPlan => 'Plan_semanal.pdf · 2,4 MB';

  @override
  String get attachmentSchedule => 'Calendario.xlsx · 1,1 MB';

  @override
  String get attachmentPresentation => 'Presentación.pdf · 7,8 MB';

  @override
  String get eventReviewTitle => 'Reunión de revisión del proyecto';

  @override
  String get eventReviewMeta => 'Equipo · En línea · 1 h';

  @override
  String get eventAuditTitle => 'Auditoría de procesos de Tenda';

  @override
  String get eventAuditMeta => 'Proyecto · Investigación · 1 h';

  @override
  String get eventReportTitle => 'Preparar informe';

  @override
  String get eventReportMeta => 'Proyecto / BAM · Concentración · 1 h';

  @override
  String get taskReportTitle => 'Preparar informe de KPI';

  @override
  String get taskPlanTitle => 'Actualizar plan de desarrollo';

  @override
  String get taskMaterialsTitle => 'Aprobar materiales del proyecto';

  @override
  String get taskDataTitle => 'Enviar datos al centro de análisis';

  @override
  String get projectStrategy => 'Estrategia';

  @override
  String get projectVp => 'Proyecto';

  @override
  String get projectVpBam => 'Proyecto / BAM';

  @override
  String get demoUserInitials => 'AR';

  @override
  String get demoUserName => 'Alexey Romanov';

  @override
  String get noDue => 'Sin fecha límite';

  @override
  String demoReplyBody(Object preview) {
    return '\n\n—\nRespuesta a un correo de demostración: $preview';
  }

  @override
  String demoForwardBody(Object preview) {
    return '\n\n—\nCorreo de demostración reenviado: $preview';
  }

  @override
  String get unread => 'No leídos';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get textSizeStandard => 'Estándar';

  @override
  String get textSizeLarge => 'Grande';

  @override
  String get textSizeExtraLarge => 'Muy grande';

  @override
  String get newEvent => 'Nuevo evento';

  @override
  String get eventTitleHint => 'Título del evento';

  @override
  String get eventTime => 'Hora';

  @override
  String get eventCreated => 'Evento guardado localmente';

  @override
  String get taskDetails => 'Detalles de la tarea';

  @override
  String get status => 'Estado';

  @override
  String get priority => 'Prioridad';

  @override
  String get priorityLow => 'Normal';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get markDone => 'Marcar como completada';

  @override
  String get markActive => 'Marcar como activa';

  @override
  String get localSaveFailed =>
      'No se pudieron guardar los cambios locales. Inténtalo de nuevo.';

  @override
  String get retry => 'Reintentar';

  @override
  String get appearanceSaveFailed =>
      'No se pudo guardar la apariencia. Inténtalo de nuevo.';

  @override
  String get appearanceLoadFailed =>
      'No se pudo cargar la apariencia. Inténtalo de nuevo.';

  @override
  String get localLoadFailed =>
      'No se pudieron cargar los datos locales. Inténtalo de nuevo.';

  @override
  String get appearanceCorrupted =>
      'Los datos de apariencia están dañados. El contenido original se conserva en una copia de seguridad.';

  @override
  String get localDataCorrupted =>
      'Los datos locales están dañados. El contenido original se conserva en una copia de seguridad.';

  @override
  String get exportBackup => 'Exportar copia';

  @override
  String backupExported(Object path) {
    return 'Copia exportada: $path';
  }

  @override
  String get backupExportFailed =>
      'Error al exportar. Los datos originales no cambian.';

  @override
  String get resetCorruptData => 'Restablecer';

  @override
  String get resetCorruptConfirm =>
      '¿Restablecer los datos dañados? El contenido original permanecerá en la copia de seguridad.';

  @override
  String get eventDetails => 'Detalles del evento';

  @override
  String get eventDescription => 'Descripción';

  @override
  String get eventLocation => 'Ubicación';

  @override
  String get eventOrganizer => 'Organizador';

  @override
  String get eventAttendees => 'Asistentes';

  @override
  String get eventConference => 'Reunión en línea';

  @override
  String get joinMeeting => 'Unirse a la reunión';

  @override
  String get copyMeetingLink => 'Copiar enlace';

  @override
  String get linkCopied => 'Enlace copiado al portapapeles';

  @override
  String get noDescription => 'Sin descripción';

  @override
  String get noLocation => 'Ubicación no especificada';

  @override
  String get noAttendees => 'Sin asistentes';

  @override
  String get noAttachments => 'Sin archivos adjuntos';

  @override
  String get openAttachment => 'Abrir';

  @override
  String get statusAccepted => 'Aceptado';

  @override
  String get statusDeclined => 'Rechazado';

  @override
  String get statusTentative => 'Tentativo';

  @override
  String get statusAwaiting => 'Esperando respuesta';

  @override
  String get gyroIntensity => 'Paralaje 3D de giroscopio';

  @override
  String get gyroIntensityDesc =>
      'Respuesta física a la inclinación en las capas de profundidad';

  @override
  String get gyroOff => 'Desactivado';

  @override
  String get gyroSubtle => 'Sutil';

  @override
  String get gyroEnhanced => 'Acentuado';

  @override
  String get lightingAndAtmosphere => 'Iluminación y atmósfera';

  @override
  String get lightingAndAtmosphereDesc =>
      'Ciclo de luz diurno y posición del sol';

  @override
  String get atmosphereAuto => 'Auto (hora)';

  @override
  String get atmosphereDawn => 'Amanecer';

  @override
  String get atmosphereDay => 'Día';

  @override
  String get atmosphereSunset => 'Atardecer';

  @override
  String get atmosphereNight => 'Noche';
}
