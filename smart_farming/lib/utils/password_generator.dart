import 'dart:math';

class PasswordGenerator {
  static const String _chars =
      'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate({int length = 10}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _chars[random.nextInt(_chars.length)],
    ).join();
  }
}
