/// Нормализует код мастера до цифр (9 цифр телефона или ID).
String normalizeMasterCodeDigits(String? raw) {
  if (raw == null) return '';
  return raw.replaceAll(RegExp(r'\D'), '');
}

bool isLegacyBarcodeImagePath(String? value) {
  if (value == null || value.isEmpty) return false;
  final v = value.toLowerCase();
  return v.contains('/') || v.endsWith('.png') || v.startsWith('static');
}

String masterCodeFromPhone(String phone) {
  final digits = normalizeMasterCodeDigits(phone);
  if (digits.length >= 9) return digits.substring(digits.length - 9);
  return digits;
}

/// Отображение: «ID: 986 505 650».
String formatMasterCodeDisplay(String code) {
  final digits = normalizeMasterCodeDigits(code);
  if (digits.isEmpty) return '';
  final buffer = StringBuffer('ID: ');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
