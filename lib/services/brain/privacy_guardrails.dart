abstract final class PrivacyGuardrails {
  static final _cardRegex = RegExp(r'\b(?:\d[ -]*?){13,19}\b');
  static final _apiKeyRegex = RegExp(r'\b(sk-[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9_\-]{35})\b');
  static final _jwtRegex = RegExp(r'eyJ[a-zA-Z0-9_\-]{10,}\.eyJ[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]+');
  static final _credentialsInUriRegex = RegExp(r'://([^:]+):([^@]+)@');
  static final _secretsRegex = RegExp(
    r'(^|[\s,;:(])(password|passwd|pass|pwd|secret|token|api[_-]?key|pin|парол[ьяеи]|секрет(?:а|ы)?|токен(?:а|ы)?|код(?:а|ы)?|пин(?:-?код)?)\s*[:=\-]?\s*([^\s,;]+)',
    caseSensitive: false,
    unicode: true,
  );

  static String sanitizeText(String input) {
    var output = input;

    // Mask JWT tokens first (longest)
    output = output.replaceAll(_jwtRegex, '[JWT_MASKED]');

    // Mask API keys
    output = output.replaceAll(_apiKeyRegex, '[API_KEY_MASKED]');

    // Mask URI passwords
    output = output.replaceAllMapped(_credentialsInUriRegex, (match) {
      return '://${match.group(1)}:[PASSWORD_MASKED]@';
    });

    // Mask Russian and English passwords, tokens, secrets
    output = output.replaceAllMapped(_secretsRegex, (match) {
      final prefix = match.group(1) ?? '';
      final secret = match.group(3) ?? '';
      final original = match.group(0)!;
      final keywordAndSep = original.substring(prefix.length, original.length - secret.length);
      return '$prefix$keywordAndSep[SECRET_REDACTED]';
    });

    // Mask credit card numbers
    output = output.replaceAllMapped(_cardRegex, (match) {
      final digitsOnly = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 13 && digitsOnly.length <= 19) {
        return '•••• •••• •••• ${digitsOnly.substring(digitsOnly.length - 4)}';
      }
      return match.group(0)!;
    });

    return output;
  }
}
