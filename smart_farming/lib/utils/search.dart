bool matchesSearch(String query, Iterable<dynamic> fields) {
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty);

  if (tokens.isEmpty) return true;

  final haystack = fields
      .where((field) => field != null)
      .map((field) => field.toString().toLowerCase())
      .join(' ');

  return tokens.every(haystack.contains);
}
