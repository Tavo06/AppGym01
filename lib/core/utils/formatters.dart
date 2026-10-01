import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _number = NumberFormat.decimalPattern('es');

  static String formatNumber(num value) {
    final rounded = value >= 100
        ? value.round()
        : double.parse(value.toStringAsFixed(1));
    return _number.format(rounded);
  }

  static String formatWeight(double weight) {
    return _number.format(
      weight == weight.roundToDouble()
          ? weight.toInt()
          : double.parse(weight.toStringAsFixed(1)),
    );
  }

  static String formatVolume(double volume) {
    return '${formatNumber(volume)} kg';
  }

  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, HH:mm', 'es').format(dateTime.toLocal());
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy', 'es').format(dateTime.toLocal());
  }

  /// Ej.: "martes, 30 de septiembre".
  static String formatLongDate(DateTime dateTime) {
    return DateFormat("EEEE, d 'de' MMMM", 'es').format(dateTime.toLocal());
  }

  /// Fecha relativa corta: "Hoy", "Ayer" o "12 sept 2026".
  static String formatRelativeDay(DateTime dateTime, {DateTime? now}) {
    final local = dateTime.toLocal();
    final today = now ?? DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final diff = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return formatDate(local);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm', 'es').format(dateTime.toLocal());
  }

  static String padClock(int value) => value.toString().padLeft(2, '0');
}
