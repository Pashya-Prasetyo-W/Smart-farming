import 'package:flutter/services.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus semua karakter selain angka
    final intValue = int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (intValue == null) return oldValue;

    // Format dengan titik setiap 3 digit
    final stringValue = intValue.toString();
    final buffer = StringBuffer();
    int offset = stringValue.length % 3;

    for (int i = 0; i < stringValue.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(stringValue[i]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}