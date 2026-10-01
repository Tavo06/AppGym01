import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class CustomDropdown extends StatelessWidget {
  const CustomDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.label,
    this.icon,
    this.validator,
  });

  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? label;
  final IconData? icon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final effective = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      // `initialValue` solo se lee al crear el campo: la clave lo recrea
      // cuando el valor cambia desde fuera, para que siempre muestre el
      // valor actual y nunca uno que ya no está en `items`.
      key: ValueKey('${label ?? ''}:$effective'),
      initialValue: effective,
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(),
      onChanged: onChanged,
      validator:
          validator ??
          (v) {
            if (v == null) return 'Selecciona una opción.';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        hintText: null,
      ),
      style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
      borderRadius: BorderRadius.circular(16),
      icon: const Icon(Icons.arrow_drop_down_circle_outlined),
    );
  }
}
