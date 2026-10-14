/// Indian digit grouping (1,00,000) for whole numbers.
String grp(int v) {
  final neg = v < 0;
  var s = v.abs().toString();
  if (s.length > 3) {
    final last = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last';
  }
  return neg ? '-$s' : s;
}

/// Quantity: whole numbers without decimals, otherwise two decimals.
String q(double v) {
  if (v == v.roundToDouble()) return grp(v.round());
  final p = v.toStringAsFixed(2).split('.');
  return '${grp(int.parse(p[0]))}.${p[1]}';
}

String rupees(double v) => '₹${grp(v.round())}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dateText(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  return dateText(d);
}
