import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Tendina standard dell'app: menu arrotondato sul colore delle card.
/// Un solo posto per lo stile di tutte le tendine dei form.
class AppDropdown<T> extends DropdownButtonFormField<T> {
  AppDropdown({
    super.key,
    required super.items,
    super.initialValue,
    required super.onChanged,
    super.decoration,
    super.validator,
    super.hint,
    super.isDense,
    super.isExpanded = true,
    super.menuMaxHeight = 400,
    super.style,
  }) : super(
         borderRadius: BorderRadius.circular(14),
         dropdownColor: AppColors.surfaceVariant,
         icon: const Icon(Icons.keyboard_arrow_down_rounded),
       );
}
