/// Антибот-поля для auth API (honeypot + время заполнения формы).
class AuthFormGuard {
  AuthFormGuard() : formStartedAt = DateTime.now().millisecondsSinceEpoch / 1000.0;

  /// Unix-секунды (дробные) — когда открыли экран/шаг формы.
  final double formStartedAt;

  /// Honeypot: всегда пустая строка. Боты часто заполняют скрытые поля.
  static const String honeypotEmpty = '';

  /// Поля для тела POST /auth/* (check-phone, login, register, …).
  Map<String, dynamic> payloadExtras() => {
        'website': honeypotEmpty,
        'form_started_at': formStartedAt,
      };

  /// Ограничение имени: без HTML/управляющих, макс. 80 символов.
  static String sanitizeName(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'<[^>]*>'), ' ');
    t = t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 80) t = t.substring(0, 80).trimRight();
    return t;
  }
}
