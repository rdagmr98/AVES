import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/hours_format.dart';

/// Campo ore in formato h:mm o minuti, con anteprima del valore interpretato.
class HoursField extends StatelessWidget {
  const HoursField({super.key, required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final empty = value.text.trim().isEmpty;
            final hours = parseHours(value.text);
            return TextField(
              controller: controller,
              // Tastierino numerico con punto/virgola: "1.35" = 1 h 35 min.
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.schedule_rounded),
                hintText: 'es. 1:35 oppure 95 (minuti)',
                helperText: empty || hours == null
                    ? 'Ore:minuti (1:35, 1.35) o solo minuti (95)'
                    : '= ${describeHours(hours)}',
                helperStyle: TextStyle(
                  color: empty || hours == null
                      ? AppColors.textHint
                      : AppColors.accentGlow,
                  fontWeight: empty ? null : FontWeight.w600,
                ),
                errorText: !empty && hours == null
                    ? 'Formato non valido: usa h:mm (1:35) o minuti (95)'
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
