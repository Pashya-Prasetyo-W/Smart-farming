class Rupiah {
  static String grouped(num value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String format(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '') ?? 0;
    return 'Rp ${grouped(number)}';
  }

  static int? parse(String text) {
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }
}
