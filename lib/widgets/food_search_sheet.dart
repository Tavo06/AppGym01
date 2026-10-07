import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../services/open_food_facts_service.dart';
import '../services/rest_client.dart';

/// Hoja "Buscar en Open Food Facts" (API REST pública): por nombre o por
/// código de barras. Devuelve el producto elegido (valores por 100 g).
Future<OffProduct?> showFoodSearchSheet(
  BuildContext context, {
  OpenFoodFactsService? service,
}) {
  return showModalBottomSheet<OffProduct>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _FoodSearch(service: service ?? OpenFoodFactsService()),
  );
}

class _FoodSearch extends StatefulWidget {
  const _FoodSearch({required this.service});

  final OpenFoodFactsService service;

  @override
  State<_FoodSearch> createState() => _FoodSearchState();
}

class _FoodSearchState extends State<_FoodSearch> {
  final TextEditingController _query = TextEditingController();
  List<OffProduct>? _results;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Escribe al menos 2 letras o un código.');
      return;
    }
    FocusScope.of(context).unfocus();
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Un código de barras (8 a 14 dígitos) se consulta directamente.
      final results = OpenFoodFactsService.isBarcode(query)
          ? [?await widget.service.byBarcode(query)]
          : await widget.service.search(query);
      if (!mounted || request != _request) return;
      setState(() => _results = results);
    } on ApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final results = _results;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Buscar en Open Food Facts',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Base de datos abierta de alimentos. Escribe un nombre o el '
            'código de barras del envase. Valores por 100 g.',
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Alimento o código de barras',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _loading ? null : _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13.5,
                      ),
                    ),
                  )
                : results == null
                ? const SizedBox.shrink()
                : results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin resultados con información de calorías.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: palette.border),
                    itemBuilder: (context, index) {
                      final product = results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        title: Text(
                          product.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${Formatters.formatNumber(product.kcal.round())} kcal'
                          ' · P ${Formatters.formatNumber(product.protein)} g'
                          ' · C ${Formatters.formatNumber(product.carbs)} g'
                          ' · G ${Formatters.formatNumber(product.fat)} g',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.textSecondary,
                          ),
                        ),
                        trailing: const Icon(Icons.add_circle_outline_rounded),
                        onTap: () => Navigator.of(context).pop(product),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Datos de Open Food Facts (licencia ODbL).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
