import 'package:flutter/material.dart';

import '../models/activity_models.dart';

class CurrencyBadgeWidget extends StatelessWidget {
  const CurrencyBadgeWidget({super.key, required this.status});

  final CurrencyStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: 6),
          Text(
            status.statusText,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class CurrencyBadge extends CurrencyBadgeWidget {
  const CurrencyBadge({super.key, required super.status});
}
