import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/nutrition_catalog.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/nutrition_model.dart';
import 'custom_button.dart';

/// Resultado de la hoja: el alimento y la comida elegida.
typedef FoodFormResult = ({MealType meal, FoodItem food});

/// Abre la hoja "Agregar alimento" (o "Editar alimento" si hay [initial]).
///
/// Con [chooseMeal] se muestra el selector de comida (para registrar el
/// consumo del día). Devuelve `null` si se cancela.
Future<FoodFormResult?> showFoodFormSheet(
  BuildContext context, {
  FoodItem? initial,
  MealType meal = MealType.breakfast,
  bool chooseMeal = false,
  String? title,
  String? submitLabel,
}) {
  return showModalBottomSheet<FoodFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FoodForm(
      initial: initial,
      meal: meal,
      chooseMeal: chooseMeal,
      title:
          title ?? (initial == null ? 'Agregar alimento' : 'Editar alimento'),
      submitLabel:
          submitLabel ?? (initial == null ? 'Agregar alimento' : 'Guardar'),
    ),
  );
}

class _FoodForm extends StatefulWidget {
  const _FoodForm({
    required this.initial,
    required this.meal,
    required this.chooseMeal,
    required this.title,
    required this.submitLabel,
  });

  final FoodItem? initial;
  final MealType meal;
  final bool chooseMeal;
  final String title;
  final String submitLabel;

  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  late MealType _meal = widget.meal;
  FoodUnit _unit = FoodUnit.grams;

  /// Alimento de referencia: al cambiar la cantidad, los valores se
  /// recalculan en proporción mientras el usuario no los edite a mano.
  FoodItem? _base;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _base = initial;
      _unit = initial.unit;
      _name.text = initial.name;
      _fill(initial, includeQuantity: true);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _quantity, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _num(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}'
        : '$rounded';
  }

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _fill(FoodItem food, {bool includeQuantity = false}) {
    if (includeQuantity) _quantity.text = _num(food.quantity);
    _kcal.text = _num(food.kcal);
    _protein.text = _num(food.protein);
    _carbs.text = _num(food.carbs);
    _fat.text = _num(food.fat);
  }

  void _pickCatalog(CatalogFood food) {
    final item = food.toFood();
    setState(() {
      _base = item;
      _manual = false;
      _unit = food.unit;
      _name.text = food.name;
      _fill(item, includeQuantity: true);
    });
  }

  void _onQuantityChanged(String text) {
    final quantity = _parse(text);
    final base = _base;
    if (quantity == null || base == null || _manual) return;
    setState(() => _fill(base.withQuantity(quantity)));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final food = FoodItem(
      id: widget.initial?.id,
      name: _name.text.trim(),
      quantity: _parse(_quantity.text)!,
      unit: _unit,
      kcal: _parse(_kcal.text) ?? 0,
      protein: _parse(_protein.text) ?? 0,
      carbs: _parse(_carbs.text) ?? 0,
      fat: _parse(_fat.text) ?? 0,
    );
    Navigator.of(context).pop((meal: _meal, food: food));
  }

  String? _required(String? v) {
    final value = _parse(v ?? '');
    if (value == null) return 'Ingresa un número.';
    if (value < 0) return 'No puede ser negativo.';
    return null;
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged:
          onChanged ??
          (_) {
            // Si el usuario cambia un valor nutricional, ya no se recalcula.
            _manual = true;
          },
      validator: validator ?? _required,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (widget.chooseMeal) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Comida',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in MealType.values)
                          ChoiceChip(
                            label: Text(type.label),
                            selected: _meal == type,
                            onSelected: (_) => setState(() => _meal = type),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Elige un alimento común o escribe el tuyo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: NutritionCatalog.foods.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final food = NutritionCatalog.foods[index];
                        return ActionChip(
                          avatar: Icon(
                            food.icon,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          label: Text(food.name),
                          onPressed: () => _pickCatalog(food),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa el nombre del alimento.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del alimento',
                      prefixIcon: Icon(Icons.restaurant_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          _quantity,
                          'Cantidad',
                          onChanged: _onQuantityChanged,
                          validator: (v) {
                            final value = _parse(v ?? '');
                            if (value == null || value <= 0) {
                              return 'Mayor que 0.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<FoodUnit>(
                          initialValue: _unit,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                            isDense: true,
                          ),
                          items: [
                            for (final unit in FoodUnit.values)
                              DropdownMenuItem(
                                value: unit,
                                child: Text(unit.label),
                              ),
                          ],
                          onChanged: (u) =>
                              setState(() => _unit = u ?? FoodUnit.grams),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _numberField(_kcal, 'Calorías')),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField(_protein, 'Proteínas (g)')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(_carbs, 'Carbohidratos (g)'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField(_fat, 'Grasas (g)')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Valores orientativos. Puedes ajustarlos según la '
                    'etiqueta de tu producto.',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    label: widget.submitLabel,
                    icon: Icons.check_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de un alimento: icono, nombre, cantidad y calorías.
class FoodRow extends StatelessWidget {
  const FoodRow({
    super.key,
    required this.food,
    this.onEdit,
    this.onDelete,
    this.leading,
  });

  final FoodItem food;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            leading ??
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    NutritionCatalog.iconFor(food.name),
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    '${Formatters.formatNumber(food.quantity)} '
                    '${food.unit.short} · '
                    'P ${Formatters.formatNumber(food.protein.round())} · '
                    'C ${Formatters.formatNumber(food.carbs.round())} · '
                    'G ${Formatters.formatNumber(food.fat.round())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${Formatters.formatNumber(food.kcal.round())} kcal',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Eliminar alimento',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: palette.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
