import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/constants/achievement_catalog.dart';
import '../models/achievement_model.dart';
import '../services/achievement_service.dart';
import '../services/app_firebase.dart';
import 'progress_provider.dart';

/// Logros del usuario: cuáles consiguió y cuándo, y el avance de los demás.
///
/// No lee el historial por su cuenta: `bindAchievements` le pasa las
/// métricas ([updateStats]) cada vez que cambian el progreso, el calendario
/// o la alimentación. Al detectar un logro nuevo lo guarda en Firestore y lo
/// deja en [takeAnnouncements] para avisar al usuario.
class AchievementProvider extends ChangeNotifier {
  AchievementProvider({AchievementService? service, this._currentUid})
    : _serviceOverride = service;

  final AchievementService? _serviceOverride;
  final String? Function()? _currentUid;
  AchievementService? _lazyService;
  AchievementService get _service =>
      _serviceOverride ?? (_lazyService ??= AchievementService());

  final Map<String, UnlockedAchievement> _unlocked = {};
  AchievementStats _stats = AchievementStats.empty;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _generation = 0;

  /// Fuentes ya evaluadas al menos una vez. Lo que se consigue en la
  /// primera evaluación de una fuente (por ejemplo, un usuario que ya tenía
  /// 20 entrenamientos antes de existir los logros) se guarda sin anunciar;
  /// solo se anuncian los logros conseguidos a partir de entonces.
  final Set<AchievementSource> _evaluatedSources = {};

  /// Logros nuevos pendientes de mostrar.
  final List<AchievementDefinition> _announcements = [];

  /// Logros anunciados en esta sesión de la app, con su fecha.
  final Map<String, DateTime> _announced = {};

  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Métricas más recientes (para mostrar el avance).
  AchievementStats get stats => _stats;

  String? get _uid =>
      _currentUid != null ? _currentUid() : AppFirebase.auth.currentUser?.uid;

  bool isUnlocked(String id) => _unlocked.containsKey(id);

  DateTime? unlockedAt(String id) => _unlocked[id]?.unlockedAt;

  int get unlockedCount =>
      _unlocked.keys.where((id) => AchievementCatalog.byId(id) != null).length;

  int get total => AchievementCatalog.all.length;

  /// Logros conseguidos, del más reciente al más antiguo.
  List<AchievementDefinition> get unlockedDefinitions {
    final items = [
      for (final entry in _unlocked.values)
        if (AchievementCatalog.byId(entry.id) case final definition?)
          (definition, entry.unlockedAt),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (definition, _) in items) definition];
  }

  /// Logros anunciados desde [since] (p. ej., durante un entrenamiento).
  List<AchievementDefinition> announcedSince(DateTime since) => [
    for (final definition in AchievementCatalog.all)
      if (_announced[definition.id] case final date?)
        if (!date.isBefore(since)) definition,
  ];

  /// Devuelve los logros nuevos aún no mostrados y vacía la lista.
  List<AchievementDefinition> takeAnnouncements() {
    final pending = List<AchievementDefinition>.of(_announcements);
    _announcements.clear();
    return pending;
  }

  // -------------------------------------------------------------- carga

  /// Carga los logros guardados solo si no se cargaron (ni fallaron).
  Future<void> ensureLoaded() async {
    if (!_loaded && !_loading && _error == null) await load();
  }

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    final generation = _generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final unlocked = await _service.getUnlocked(uid);
      if (generation != _generation) return;
      _unlocked
        ..clear()
        ..addEntries(unlocked.map((u) => MapEntry(u.id, u)));
      _loaded = true;
      _evaluate();
    } catch (error) {
      if (generation != _generation) return;
      _error = ProgressProvider.describeError(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Borra los datos en memoria al cerrar sesión.
  void reset() {
    _generation++;
    _unlocked.clear();
    _stats = AchievementStats.empty;
    _evaluatedSources.clear();
    _announcements.clear();
    _announced.clear();
    _loading = false;
    _loaded = false;
    _error = null;
    _notify();
  }

  // ---------------------------------------------------------- evaluación

  /// Recibe las métricas actuales y desbloquea los logros alcanzados.
  void updateStats(AchievementStats stats) {
    _stats = stats;
    if (_loaded) _evaluate();
    _notify();
  }

  void _evaluate() {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();
    final newly = <UnlockedAchievement>[];
    for (final definition in AchievementCatalog.all) {
      if (_unlocked.containsKey(definition.id)) continue;
      if (!definition.isReachedBy(_stats)) continue;
      final unlocked = UnlockedAchievement(id: definition.id, unlockedAt: now);
      _unlocked[definition.id] = unlocked;
      newly.add(unlocked);
      if (_evaluatedSources.contains(definition.metric.source)) {
        _announcements.add(definition);
        _announced[definition.id] = now;
      }
    }
    _evaluatedSources.addAll(_stats.sources);
    if (newly.isEmpty) return;
    // Si la escritura falla, el logro sigue conseguido en memoria y se
    // vuelve a guardar (sin anunciar) en la próxima carga.
    unawaited(
      _service.saveUnlocked(uid, newly).catchError((Object error) {
        debugPrint('No se pudieron guardar los logros: $error');
      }),
    );
  }

  /// `updateStats` llega desde los listeners de otros providers, que pueden
  /// avisar durante la construcción de un widget: en ese caso se avisa al
  /// terminar el frame para no reconstruir en mitad de otro build.
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}
