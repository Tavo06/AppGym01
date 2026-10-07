import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_firebase.dart';
import '../../services/firestore_service.dart';
import '../../services/rest_client.dart';
import '../../services/wger_service.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive.dart';

/// Catálogo de ejercicios de wger (`/ejercicio/catalogo`), API REST pública:
/// categorías, páginas con "Cargar más", búsqueda entre lo cargado y
/// "Añadir" para copiar un ejercicio al catálogo propio del usuario.
class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({super.key, this.service});

  /// Servicio de wger (sustituible en las pruebas).
  final WgerService? service;

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  late final WgerService _wger = widget.service ?? WgerService();
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _search = TextEditingController();

  int? _category;
  final List<WgerExercise> _items = [];
  int _count = 0;
  Uri? _next;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Nombres (en minúsculas) de los ejercicios que el usuario ya tiene.
  final Set<String> _owned = {};
  final Set<int> _adding = {};

  /// Cada carga invalida las anteriores (cambiar de categoría rápido).
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadOwned();
    _loadFirst();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOwned() async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final exercises = await _firestore.getExercises(uid);
      if (!mounted) return;
      setState(() {
        _owned
          ..clear()
          ..addAll(exercises.map((e) => e.name.trim().toLowerCase()));
      });
    } catch (_) {
      // Sin la lista propia solo se pierde la marca "Añadido".
    }
  }

  Future<void> _loadFirst() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _next = null;
    });
    try {
      final page = await _wger.fetchExercises(categoryId: _category);
      if (!mounted || request != _request) return;
      setState(() {
        _items.addAll(page.items);
        _count = page.count;
        _next = page.next;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final next = _next;
    if (next == null || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final page = await _wger.fetchExercises(next: next);
      if (!mounted || request != _request) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.next;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectCategory(int? id) {
    if (id == _category) return;
    setState(() => _category = id);
    _loadFirst();
  }

  Future<void> _add(WgerExercise exercise) async {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _adding.add(exercise.id));
    try {
      await _firestore.saveExercise(
        uid,
        exercise.toExercise(_firestore.newDocId),
      );
      if (!mounted) return;
      setState(() => _owned.add(exercise.name.trim().toLowerCase()));
      showAppMessage(
        context,
        '"${exercise.name}" se añadió a tus ejercicios.',
        type: FeedbackType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, 'No se pudo añadir el ejercicio.');
    } finally {
      if (mounted) setState(() => _adding.remove(exercise.id));
    }
  }

  List<WgerExercise> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return [
      for (final e in _items)
        if (e.name.toLowerCase().contains(query) ||
            e.equipment.toLowerCase().contains(query))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de ejercicios')),
      body: MaxWidth(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                children: [
                  for (final option in [null, ...WgerCategory.all])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option?.label ?? 'Todos'),
                        selected: _category == option?.id,
                        showCheckmark: false,
                        onSelected: (_) => _selectCategory(option?.id),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar entre los cargados',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(child: _buildBody(palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppPalette palette) {
    if (_loading) {
      return const LoadingWidget(message: 'Consultando wger...');
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadFirst);
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        subtitle: _next != null
            ? 'Carga más ejercicios para seguir buscando.'
            : 'Prueba con otra categoría o búsqueda.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          'Mostrando ${_items.length} de $_count ejercicios',
          style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
        ),
        const SizedBox(height: 10),
        for (final exercise in visible) ...[
          _CatalogTile(
            exercise: exercise,
            owned: _owned.contains(exercise.name.trim().toLowerCase()),
            adding: _adding.contains(exercise.id),
            onAdd: () => _add(exercise),
          ),
          const SizedBox(height: 10),
        ],
        if (_next != null)
          OutlinedButton.icon(
            onPressed: _loadingMore ? null : _loadMore,
            icon: _loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: const Text('Cargar más'),
          ),
        const SizedBox(height: 14),
        Text(
          'Datos de wger.de (licencia CC-BY-SA).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.exercise,
    required this.owned,
    required this.adding,
    required this.onAdd,
  });

  final WgerExercise exercise;
  final bool owned;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final details = [
      exercise.muscleGroup,
      if (exercise.equipment.isNotEmpty) exercise.equipment,
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: ShapeDecoration(
                color: palette.primarySoft,
                shape: AppShapes.small,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                color: palette.primaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (owned)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Añadido',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              )
            else
              FilledButton.tonal(
                onPressed: adding ? null : onAdd,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: adding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Añadir'),
              ),
          ],
        ),
      ),
    );
  }
}
