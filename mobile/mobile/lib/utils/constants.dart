String normalizePhone(String raw) {
  final lower = raw.toLowerCase().trim();
  var replaced = lower.replaceAll('+82', '82');
  replaced = replaced.replaceAll(RegExp(r'[^0-9]'), '');
  if (replaced.startsWith('82')) {
    replaced = '0${replaced.substring(2)}';
  }

  return replaced;
}
