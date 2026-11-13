// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'ORBIT Visual Lab';

  @override
  String get today => 'Сегодня';

  @override
  String get mail => 'Почта';

  @override
  String get calendar => 'Календарь';

  @override
  String get tasks => 'Задачи';

  @override
  String get more => 'Ещё';

  @override
  String get back => 'Назад';

  @override
  String get settings => 'Настройки';

  @override
  String get inbox => 'Входящие';

  @override
  String get newEmail => 'Новое письмо';

  @override
  String get search => 'Поиск';

  @override
  String get all => 'Все';

  @override
  String get important => 'Важные';

  @override
  String get importantSingle => 'Важное';

  @override
  String get emptyHere => 'Здесь пока пусто';

  @override
  String unreadSummary(int count) {
    return '$count непрочитанных · демонстрационная почта';
  }

  @override
  String get mailDemoNotice =>
      'Свайп и серверные действия отключены: данные существуют только в этой демонстрации.';

  @override
  String toMe(String email) {
    return 'Кому: мне · $email';
  }

  @override
  String get attachments => 'Вложения';

  @override
  String get demoAttachment => 'Демонстрационное вложение';

  @override
  String get demoAttachmentNotice =>
      'Файл является демонстрационной записью и не загружается.';

  @override
  String get reply => 'Ответить';

  @override
  String get replyAll => 'Всем';

  @override
  String get forward => 'Переслать';

  @override
  String get draftSubtitle => 'Автономный черновик · отправка отключена';

  @override
  String get saveDraft => 'Сохранить черновик';

  @override
  String get draftSaved => 'Черновик сохранён локально. Письмо не отправлено.';

  @override
  String get draftUnsavedChanges => 'есть несохранённые изменения';

  @override
  String get draftSavedState => 'все изменения сохранены';

  @override
  String get to => 'Кому';

  @override
  String get subject => 'Тема';

  @override
  String get subjectHint => 'О чём письмо';

  @override
  String get bodyHint => 'Текст письма…';

  @override
  String get formatting => 'Форматирование недоступно в DEMO';

  @override
  String get attachmentsDisabled => 'Вложения отключены';

  @override
  String get localFilesDisabled =>
      'В Visual Lab нельзя прикреплять локальные файлы.';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get add => 'Добавить';

  @override
  String get understood => 'Понятно';

  @override
  String get demoLabel => 'ДЕМО · ЛОКАЛЬНЫЕ ДАННЫЕ';

  @override
  String get notifications => 'Уведомления';

  @override
  String get notificationsDemo =>
      'Серверные уведомления не подключены в Visual Lab.';

  @override
  String get goodMorning => 'Доброе утро,\nАлексей!';

  @override
  String dateFocus(String date) {
    return '$date · спокойный фокус';
  }

  @override
  String get newMetric => 'новых';

  @override
  String get eventsMetric => 'события';

  @override
  String get tasksMetric => 'задачи';

  @override
  String get upcoming => 'Ближайшее';

  @override
  String get actionCenter => 'Центр действий';

  @override
  String get dayRhythm => 'ритм дня';

  @override
  String get yourSpace => 'Ваше пространство';

  @override
  String completedSummary(int completed, int total) {
    return '$completed из $total задач завершено. Следующий спокойный интервал — после 13:30.';
  }

  @override
  String get flow => 'Поток';

  @override
  String get focus => 'Фокус';

  @override
  String get emailAction => 'Письмо';

  @override
  String get taskAction => 'Задача';

  @override
  String get eventAction => 'Событие';

  @override
  String get experimentRive => 'EXPERIMENT B · RIVE';

  @override
  String get experimentFilament => 'EXPERIMENT C · FILAMENT';

  @override
  String get liveBrandScene => 'Интерактивная атмосфера';

  @override
  String get pbrScene => 'Настоящая PBR-сцена';

  @override
  String get compareRenderers => 'Сравнить рендеры →';

  @override
  String graphicsUnavailable(String reason) {
    return 'Графический рендер недоступен. Включён Static/Eco; интерфейс продолжает работать.\n$reason';
  }

  @override
  String get filamentUnsupported =>
      'Filament доступен в Android-сборке. На этой платформе включён статический/процедурный резервный рендер.';

  @override
  String get riveAtmosphereSemantics =>
      'Интерактивная Rive-сцена ORBIT. Коснитесь, чтобы запустить импульс.';

  @override
  String get riveMarkSemantics =>
      'Анимированный логотип ORBIT. Коснитесь, чтобы запустить импульс.';

  @override
  String get activeRenderer => 'Активный рендер';

  @override
  String get rendererDescription =>
      'Выбор применяется сразу и сохраняется. Маршрут и демонстрационные данные не сбрасываются.';

  @override
  String get staticRendererTitle => 'A · Static / Eco';

  @override
  String get staticRendererSubtitle =>
      'Детализированная статическая Flutter/Impeller-сцена без непрерывного кадрового цикла.';

  @override
  String get riveRendererTitle => 'B · Flutter + Impeller + Rive';

  @override
  String get riveRendererSubtitle =>
      'Атмосферный ландшафт, орбитальная анимация и Rive trigger Pulse по касанию.';

  @override
  String get filamentRendererTitle => 'C · Flutter + native Google Filament';

  @override
  String get filamentRendererSubtitle =>
      'Нативный Android SurfaceView, PBR-рельеф, солнце, облака и камера.';

  @override
  String get visualLabSubtitle =>
      'Сравнение рендеров на одном экране «Сегодня»';

  @override
  String get openToday => 'Открыть «Сегодня»';

  @override
  String get measurementStatus => 'Состояние измерений';

  @override
  String get frameMetrics => 'FPS / P95 frame time';

  @override
  String get resourceMetrics => 'RAM / GPU / энергия / нагрев';

  @override
  String get physicalRun => 'Запуск на реальном устройстве';

  @override
  String get performanceMethod =>
      'Для честного сравнения нужны profile/release-сборки на одном физическом Android-устройстве. Методика и команды находятся в docs/PERFORMANCE.md.';

  @override
  String get graphicsLog => 'Журнал графического fallback';

  @override
  String get nativePbr => 'NATIVE · PBR';

  @override
  String get androidFallback => 'ANDROID ONLY · FALLBACK';

  @override
  String get day => 'День';

  @override
  String get week => 'Неделя';

  @override
  String get month => 'Месяц';

  @override
  String get agenda => 'Повестка';

  @override
  String get allUpcoming => 'Все ближайшие события';

  @override
  String get freeTomorrow =>
      'Завтра свободно после 16:00 — хорошее время для спокойной работы.';

  @override
  String get morning => 'утро';

  @override
  String get events => 'события';

  @override
  String get focusHours => 'часа фокуса';

  @override
  String get progressDay => 'Прогресс дня';

  @override
  String get active => 'Активные';

  @override
  String get projects => 'Проекты';

  @override
  String get addTask => 'Добавить задачу';

  @override
  String get quickAdd => 'Быстрое добавление';

  @override
  String get newTask => 'Новая задача';

  @override
  String get taskHint => 'Что нужно сделать?';

  @override
  String completedOf(int completed, int total) {
    return '$completed из $total завершено · локальная логика';
  }

  @override
  String get localList => 'Локальный список';

  @override
  String get settingsSubtitle => 'Персональное пространство · Visual Lab';

  @override
  String get personalization => 'Персонализация';

  @override
  String get interface => 'Интерфейс';

  @override
  String get graphicsQuality => 'Качество графики';

  @override
  String get visualLabExperiments => 'Static · Rive · Filament · режимы A/B/C';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get language => 'Язык';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get density => 'Плотность';

  @override
  String get motion => 'Движение';

  @override
  String get routeNotFound => 'Маршрут не найден';

  @override
  String get routeStateSaved =>
      'Состояние оболочки сохранено. Вернитесь на главный экран.';

  @override
  String get yesterday => 'Вчера';

  @override
  String get mondayShort => 'Пн';

  @override
  String get done => 'Выполнено';

  @override
  String get tomorrow => 'Завтра';

  @override
  String todayTime(String time) {
    return 'Сегодня, $time';
  }

  @override
  String get dateNovember5 => '5 ноября';

  @override
  String get system => 'Система';

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
      'Демонстрация будущего помощника · локальные сценарии';

  @override
  String get brainGreeting => 'Чем помочь сегодня?';

  @override
  String get brainNotice =>
      'Никаких сетевых запросов: выберите один из заранее подготовленных сценариев.';

  @override
  String get brainPromptInbox => 'Разобрать входящие';

  @override
  String get brainPromptPlan => 'Сформировать план дня';

  @override
  String get brainPromptReport => 'Подготовить отчёт';

  @override
  String get brainResponseInbox =>
      'Локальный демо-сценарий: сначала два непрочитанных письма, затем план на неделю. Это не анализ реальной почты.';

  @override
  String get brainResponsePlan =>
      'Локальный демо-сценарий: 10:00 — встреча, 13:30 — аудит, после 14:30 — спокойный фокус. Данные взяты из демонстрационного календаря.';

  @override
  String get brainResponseReport =>
      'Локальный демо-сценарий: структура отчёта — цель, результат, риски, следующий шаг. Текст не отправлялся в ИИ-сервис.';

  @override
  String get demoResponse => 'Демонстрационный ответ';

  @override
  String get createTask => 'Создать задачу';

  @override
  String get localDraft => 'Локальный черновик';

  @override
  String get toLocalList => 'В локальный список';

  @override
  String get openCalendar => 'Открыть календарь';

  @override
  String get demoAssistant => 'Демонстрационный помощник';

  @override
  String get quickActions => 'Быстрые действия';

  @override
  String get quickActionsSubtitle => 'Главное — одним касанием';

  @override
  String get close => 'Закрыть';

  @override
  String get noServerData => 'Никакие данные не отправляются на сервер';

  @override
  String get aboutVisualLab => 'О Visual Lab';

  @override
  String get versionLabel =>
      'Версия 0.5.30+36 · персональная цифровая экосистема';

  @override
  String get aboutLegalese =>
      'ORBIT 0.5. Почта, события, задачи и Brain используют явно маркированные локальные демонстрационные данные.';

  @override
  String get aboutTech =>
      'Flutter + Impeller + Rive + нативный Google Filament для Android.';

  @override
  String get settingsSaved => 'Настройки сохраняются сразу';

  @override
  String get interfaceGallery => 'Галерея интерфейсов';

  @override
  String get livePreview => 'живой предпросмотр';

  @override
  String get qualityAutoSummary => 'Auto · адаптивно';

  @override
  String get qualityEcoSummary => 'Eco · статика';

  @override
  String get qualityBalancedSummary => 'Balanced · умеренная глубина';

  @override
  String get qualityUltraSummary => 'Ultra · максимум деталей';

  @override
  String get qualityAutoDescription =>
      'Учитывает устройство и системные ограничения';

  @override
  String get qualityEcoDescription => 'Статическая сцена, минимум эффектов';

  @override
  String get qualityBalancedDescription => 'Фон до 30 FPS, умеренная глубина';

  @override
  String get qualityUltraDescription => 'Динамический свет и максимум деталей';

  @override
  String get interfaceAndMotion => 'Интерфейс и движение';

  @override
  String get uiAnimations => 'Анимации интерфейса';

  @override
  String get animationsDisableNotice =>
      'Отключение также останавливает фоновые сцены';

  @override
  String get comfortable => 'Комфортная';

  @override
  String get compact => 'Компактная';

  @override
  String systemLimits(String power, String memory) {
    return 'Системные ограничения: энергосбережение $power, давление памяти $memory.';
  }

  @override
  String get enabled => 'включено';

  @override
  String get notDetected => 'не обнаружено';

  @override
  String get present => 'есть';

  @override
  String get absent => 'нет';

  @override
  String accentColorValue(String value) {
    return 'Акцентный цвет $value';
  }

  @override
  String selectProfile(String profile) {
    return 'Выбрать $profile';
  }

  @override
  String get interfaceBreadcrumb => 'Настройки → Персонализация → Интерфейс';

  @override
  String get goodMorningShort => 'Доброе утро!';

  @override
  String get greetingMorning => 'Доброе утро,\nАлексей!';

  @override
  String get greetingMorningShort => 'Доброе утро!';

  @override
  String get greetingDay => 'Добрый день,\nАлексей!';

  @override
  String get greetingDayShort => 'Добрый день!';

  @override
  String get greetingEvening => 'Добрый вечер,\nАлексей!';

  @override
  String get greetingEveningShort => 'Добрый вечер!';

  @override
  String get greetingNight => 'Доброй ночи,\nАлексей!';

  @override
  String get greetingNightShort => 'Доброй ночи!';

  @override
  String get profileOneSubtitle => 'Универсальный · глубокий фокус';

  @override
  String get profileAtelierSubtitle => 'Атмосферный · утончённая точность';

  @override
  String get profileFlowSubtitle => 'Динамичный · живой цифровой поток';

  @override
  String get profileZenSubtitle => 'Светлый · воздух и концентрация';

  @override
  String get emailWeeklySender => 'Мария Соколова';

  @override
  String get emailDesignSender => 'Илья Волков';

  @override
  String get emailProjectSender => 'Команда ORBIT';

  @override
  String get emailResearchSender => 'Анна Ремизова';

  @override
  String get emailWeeklySubject => 'План на неделю';

  @override
  String get emailWeeklyPreview =>
      'Привет! Прикрепляю обновлённый план на следующую неделю…';

  @override
  String get emailWeeklyBody =>
      'Привет, Алексей!\n\nПрикрепляю обновлённый план на следующую неделю. Давай обсудим на встрече во вторник.\n\nЯ выделила ключевые этапы, добавила время на спокойную проверку и оставила пространство для незапланированных задач.\n\nХорошего дня!';

  @override
  String get emailDesignSubject => 'Обсуждение дизайна';

  @override
  String get emailDesignPreview =>
      'Прикладываю актуальные варианты и короткие комментарии…';

  @override
  String get emailDesignBody =>
      'Привет!\n\nПрикладываю актуальные варианты и короткие комментарии. Особенно интересно твоё мнение о плотности списка и поведении нижней навигации.';

  @override
  String get emailProjectSubject => 'Обновление по проекту';

  @override
  String get emailProjectPreview =>
      'Статус, следующие шаги и спокойный фокус на главном…';

  @override
  String get emailProjectBody =>
      'Коллеги, привет!\n\nОсновной этап завершён. Следующие шаги: визуальная проверка, тестирование на устройствах и подготовка передачи в основной продукт.';

  @override
  String get emailResearchSubject => 'Встреча: подготовка';

  @override
  String get emailResearchPreview =>
      'Материалы и повестка внутри. Встреча займёт около часа…';

  @override
  String get emailResearchBody =>
      'Добрый день!\n\nМатериалы и повестка внутри. Предлагаю сначала обсудить пользовательские сценарии, затем визуальные ограничения.';

  @override
  String get emailFocusSubject => 'Три мысли для спокойного дня';

  @override
  String get emailFocusPreview =>
      'Начните с главного, оставьте место для паузы…';

  @override
  String get emailFocusBody =>
      'Начните с главного, оставьте место для паузы, завершите день коротким обзором.\n\nЭто демонстрационное письмо локальной оболочки ORBIT.';

  @override
  String get attachmentWeekPlan => 'План_недели.pdf · 2,4 МБ';

  @override
  String get attachmentSchedule => 'График.xlsx · 1,1 МБ';

  @override
  String get attachmentPresentation => 'Презентация.pdf · 7,8 МБ';

  @override
  String get eventReviewTitle => 'Совещание по ВП';

  @override
  String get eventReviewMeta => 'Команда · Онлайн · 1 ч';

  @override
  String get eventAuditTitle => 'Аудит СПД Тэнда';

  @override
  String get eventAuditMeta => 'Проект · Исследования · 1 ч';

  @override
  String get eventReportTitle => 'Подготовить отчёт';

  @override
  String get eventReportMeta => 'ВП / БАМ · Фокус · 1 ч';

  @override
  String get taskReportTitle => 'Подготовить отчёт по КПЭ';

  @override
  String get taskPlanTitle => 'Актуализировать план развития';

  @override
  String get taskMaterialsTitle => 'Согласовать материалы по ВП';

  @override
  String get taskDataTitle => 'Отправить данные в ЦА';

  @override
  String get projectStrategy => 'Стратегия';

  @override
  String get projectVp => 'ВП';

  @override
  String get projectVpBam => 'ВП / БАМ';

  @override
  String get demoUserInitials => 'АР';

  @override
  String get demoUserName => 'Алексей Романов';

  @override
  String get noDue => 'Без срока';

  @override
  String demoReplyBody(Object preview) {
    return '\n\n—\nОтвет на демонстрационное письмо: $preview';
  }

  @override
  String demoForwardBody(Object preview) {
    return '\n\n—\nПересланное демонстрационное письмо: $preview';
  }

  @override
  String get unread => 'Новые';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get textSize => 'Размер текста';

  @override
  String get textSizeStandard => 'Обычный';

  @override
  String get textSizeLarge => 'Крупный';

  @override
  String get textSizeExtraLarge => 'Очень крупный';

  @override
  String get newEvent => 'Новое событие';

  @override
  String get eventTitleHint => 'Название события';

  @override
  String get eventTime => 'Время';

  @override
  String get eventCreated => 'Событие сохранено локально';

  @override
  String get taskDetails => 'Карточка задачи';

  @override
  String get status => 'Статус';

  @override
  String get priority => 'Приоритет';

  @override
  String get priorityLow => 'Обычный';

  @override
  String get priorityMedium => 'Средний';

  @override
  String get priorityHigh => 'Высокий';

  @override
  String get markDone => 'Отметить выполненной';

  @override
  String get markActive => 'Вернуть в активные';

  @override
  String get localSaveFailed =>
      'Не удалось сохранить локальные изменения. Повторите попытку.';

  @override
  String get retry => 'Повторить';

  @override
  String get appearanceSaveFailed =>
      'Не удалось сохранить оформление. Повторите попытку.';

  @override
  String get appearanceLoadFailed =>
      'Не удалось загрузить оформление. Повторите попытку.';

  @override
  String get localLoadFailed =>
      'Не удалось загрузить локальные данные. Повторите попытку.';

  @override
  String get appearanceCorrupted =>
      'Оформление повреждено. Исходная запись сохранена в резервной копии.';

  @override
  String get localDataCorrupted =>
      'Локальные данные повреждены. Исходная запись сохранена в резервной копии.';

  @override
  String get exportBackup => 'Экспорт backup';

  @override
  String backupExported(Object path) {
    return 'Резервная копия экспортирована: $path';
  }

  @override
  String get backupExportFailed =>
      'Не удалось экспортировать резервную копию. Исходные данные не изменены.';

  @override
  String get resetCorruptData => 'Сбросить';

  @override
  String get resetCorruptConfirm =>
      'Сбросить повреждённые данные? Резервная копия исходной записи будет сохранена.';

  @override
  String get eventDetails => 'Детали события';

  @override
  String get eventDescription => 'Описание';

  @override
  String get eventLocation => 'Место встречи';

  @override
  String get eventOrganizer => 'Организатор';

  @override
  String get eventAttendees => 'Участники';

  @override
  String get eventConference => 'Онлайн-встреча';

  @override
  String get joinMeeting => 'Присоединиться к встрече';

  @override
  String get copyMeetingLink => 'Скопировать ссылку';

  @override
  String get linkCopied => 'Ссылка скопирована в буфер обмена';

  @override
  String get noDescription => 'Описание не указано';

  @override
  String get noLocation => 'Место не указано';

  @override
  String get noAttendees => 'Список участников пуст';

  @override
  String get noAttachments => 'Вложения отсутствуют';

  @override
  String get openAttachment => 'Открыть';

  @override
  String get statusAccepted => 'Принято';

  @override
  String get statusDeclined => 'Отклонено';

  @override
  String get statusTentative => 'Под вопросом';

  @override
  String get statusAwaiting => 'Ожидание ответа';

  @override
  String get gyroIntensity => '3D-параллакс от гироскопа';

  @override
  String get gyroIntensityDesc =>
      'Плавный отклик планов на физический наклон устройства';

  @override
  String get gyroOff => 'Выкл';

  @override
  String get gyroSubtle => 'Мягкий';

  @override
  String get gyroEnhanced => 'Выраженный';

  @override
  String get lightingAndAtmosphere => 'Освещение и атмосфера';

  @override
  String get lightingAndAtmosphereDesc =>
      'Суточный световой цикл и положение солнца';

  @override
  String get atmosphereAuto => 'Авто (время)';

  @override
  String get atmosphereDawn => 'Рассвет';

  @override
  String get atmosphereDay => 'День';

  @override
  String get atmosphereSunset => 'Закат';

  @override
  String get atmosphereNight => 'Ночь';
}
