import 'package:flutter/services.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final intValue = int.tryParse(
      newValue.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (intValue == null) return oldValue;

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

class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final regEx = RegExp(r'^\d*[\.,]?\d*$');
    if (newValue.text.isEmpty || regEx.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}
