import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _date = DateFormat("d 'de' MMMM 'de' y", 'es_CO');
  static final _dateShort = DateFormat('dd/MM/yyyy', 'es_CO');
  static final _dateTime = DateFormat("d MMM y, h:mm a", 'es_CO');

  static String date(DateTime d) => _date.format(d.toLocal());
  static String dateShort(DateTime d) => _dateShort.format(d.toLocal());
  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());

  /// "hace 3 h", "hace 2 días"...
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 30) return 'hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    return dateShort(d);
  }

  static String coords(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  static String distance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}
