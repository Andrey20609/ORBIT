final class OrbitLocalStateCodec {
  const OrbitLocalStateCodec._();

  static void validate(Map<String, Object?> state) {
    if (state.isEmpty) return;
    final schemaVersion = state['schemaVersion'];
    if (schemaVersion != null && schemaVersion != 1) {
      throw const FormatException('Unsupported local state schemaVersion');
    }
    _stringList(state, 'readEmails');
    _stringList(state, 'deletedEmails');
    _stringList(state, 'starredEmails');
    _stringList(state, 'unstarredEmails');
    _string(state, 'currentMailFolder');
    _stringList(state, 'trashEmails');
    _stringList(state, 'spamEmails');
    _stringList(state, 'archiveEmails');
    _stringList(state, 'outboxEmails');
    _stringList(state, 'permanentlyDeletedEmails');
    _objects(state, 'sentEmails', _validateSentEmail);
    _objects(state, 'mailAccounts', _validateMailAccount);
    _objects(state, 'brainChatHistory', _validateBrainChatMessage);
    _string(state, 'draftTo');
    _string(state, 'draftSubject');
    _string(state, 'draftBody');
    _objects(state, 'tasks', _validateTask);
    _objects(state, 'events', _validateEvent);
  }

  static void _validateSentEmail(Map<String, Object?> entry, String path) {
    _requiredString(entry, 'id', path);
    _requiredString(entry, 'recipient', path);
    _requiredString(entry, 'subject', path);
    _requiredString(entry, 'body', path);
    _requiredString(entry, 'sentAtIso', path);
  }

  static void _validateMailAccount(Map<String, Object?> acc, String path) {
    _requiredString(acc, 'id', path);
    _requiredString(acc, 'name', path);
    _requiredString(acc, 'email', path);
  }

  static void _validateBrainChatMessage(Map<String, Object?> msg, String path) {
    _requiredString(msg, 'id', path);
    _requiredString(msg, 'text', path);
  }

  static void _string(Map<String, Object?> state, String key) {
    final value = state[key];
    if (value != null && value is! String) {
      throw FormatException('$key must be a string');
    }
  }

  static void _stringList(Map<String, Object?> state, String key) {
    final value = state[key];
    if (value == null) return;
    if (value is! List<Object?> || value.any((item) => item is! String)) {
      throw FormatException('$key must be a list of strings');
    }
  }

  static void _objects(
    Map<String, Object?> state,
    String key,
    void Function(Map<String, Object?>, String) validate,
  ) {
    final value = state[key];
    if (value == null) return;
    if (value is! List<Object?>) {
      throw FormatException('$key must be a list');
    }
    for (final (index, item) in value.indexed) {
      if (item is! Map<String, Object?>) {
        throw FormatException('$key[$index] must be an object');
      }
      validate(item, '$key[$index]');
    }
  }

  static void _validateTask(Map<String, Object?> task, String path) {
    _requiredString(task, 'id', path);
    _requiredString(task, 'title', path);
    _optionalString(task, 'project', path);
    _optionalString(task, 'due', path);
    if (task['done'] != null && task['done'] is! bool) {
      throw FormatException('$path.done must be a bool');
    }
    final priority = task['priority'];
    if (priority != null &&
        (priority is! num ||
            priority != priority.toInt() ||
            priority < 0 ||
            priority > 2)) {
      throw FormatException('$path.priority must be an integer from 0 to 2');
    }
  }

  static void _validateEvent(Map<String, Object?> event, String path) {
    _requiredString(event, 'id', path);
    _requiredString(event, 'time', path);
    _requiredString(event, 'title', path);
    _optionalString(event, 'meta', path);
    if (event['color'] is! int) {
      throw FormatException('$path.color must be an integer');
    }
    final date = event['date'];
    if (date != null && (date is! String || DateTime.tryParse(date) == null)) {
      throw FormatException('$path.date must be an ISO-8601 string or null');
    }
    _optionalString(event, 'endTime', path);
    _optionalString(event, 'description', path);
    _optionalString(event, 'location', path);
    _optionalString(event, 'conferenceUrl', path);
    final organizer = event['organizer'];
    if (organizer != null) {
      if (organizer is! Map<String, Object?>) {
        throw FormatException('$path.organizer must be an object');
      }
      _requiredString(organizer, 'name', '$path.organizer');
      _requiredString(organizer, 'email', '$path.organizer');
    }
    final attendees = event['attendees'];
    if (attendees != null) {
      if (attendees is! List<Object?>) {
        throw FormatException('$path.attendees must be a list');
      }
      for (final (i, a) in attendees.indexed) {
        if (a is! Map<String, Object?>) {
          throw FormatException('$path.attendees[$i] must be an object');
        }
        _requiredString(a, 'name', '$path.attendees[$i]');
        _requiredString(a, 'email', '$path.attendees[$i]');
      }
    }
    final attachments = event['attachments'];
    if (attachments != null) {
      if (attachments is! List<Object?>) {
        throw FormatException('$path.attachments must be a list');
      }
      for (final (i, a) in attachments.indexed) {
        if (a is! Map<String, Object?>) {
          throw FormatException('$path.attachments[$i] must be an object');
        }
        _requiredString(a, 'name', '$path.attachments[$i]');
      }
    }
  }

  static void _requiredString(
    Map<String, Object?> object,
    String key,
    String path,
  ) {
    if (object[key] is! String) {
      throw FormatException('$path.$key must be a string');
    }
  }

  static void _optionalString(
    Map<String, Object?> object,
    String key,
    String path,
  ) {
    if (object[key] != null && object[key] is! String) {
      throw FormatException('$path.$key must be a string');
    }
  }
}
