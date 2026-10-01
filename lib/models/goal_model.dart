enum GoalStatus { reached, onTrack, pending }

/// Meta semanal (volumen, series o entrenamientos) comparada con lo que el
/// usuario lleva hecho en la semana actual.
class WeeklyGoal {
  WeeklyGoal({
    required this._title,
    required this._unit,
    required this._target,
    required this._current,
    double expectedFraction = 1,
  }) : _expectedFraction = expectedFraction.clamp(0, 1).toDouble();

  final String _title;
  final String _unit;
  final double _target;
  final double _current;

  /// Parte de la semana ya transcurrida (lunes = 1/7 … domingo = 7/7).
  final double _expectedFraction;

  String get title => _title;
  String get unit => _unit;

  /// Objetivo de la semana y lo que se lleva hecho.
  double get target => _target;
  double get current => _current;

  /// Avance entre 0 y 1 para la barra de progreso.
  double get ratio {
    if (target <= 0) return 0;
    final value = current / target;
    return value > 1 ? 1 : value;
  }

  /// Avance en porcentaje (puede superar el 100 %).
  int get percent => target <= 0 ? 0 : (current / target * 100).round();

  /// Lo que falta para cumplir la meta (0 si ya se cumplió).
  double get remaining => current >= target ? 0 : target - current;

  /// Alcanzada si se llegó al objetivo. Si no, "a buen ritmo" cuando el
  /// avance va al día con la parte de la semana que ya pasó; si no,
  /// pendiente.
  GoalStatus get status {
    if (current >= target) {
      return GoalStatus.reached;
    } else if (current >= target * _expectedFraction) {
      return GoalStatus.onTrack;
    } else {
      return GoalStatus.pending;
    }
  }

  bool get isReached => status == GoalStatus.reached;

  String get statusLabel => switch (status) {
    GoalStatus.reached => 'Meta alcanzada',
    GoalStatus.onTrack => 'A buen ritmo',
    GoalStatus.pending => 'Meta pendiente',
  };
}
