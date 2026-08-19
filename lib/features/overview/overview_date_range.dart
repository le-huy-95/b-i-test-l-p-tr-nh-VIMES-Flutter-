import 'package:intl/intl.dart';

const overviewDefaultRangeDays = 30;

(DateTime from, DateTime to) overviewDefaultRange(DateTime now) {
  return (now.subtract(const Duration(days: overviewDefaultRangeDays)), now);
}

(DateTime from, DateTime to) normalizeOverviewPickerRange({
  required DateTime start,
  required DateTime end,
}) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  return (from, to);
}

String formatOverviewDateRange(DateTime from, DateTime to) {
  final fmt = DateFormat('dd/MM/yyyy');
  return '${fmt.format(from.toLocal())} – ${fmt.format(to.toLocal())}';
}
