import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../models/activity_models.dart';
import '../services/currency_service.dart';

final _expiryFmt = DateFormat('dd/MM/yy');

/// Testo e colore della scadenza (null = mai svolta) per liste di tecnici.
(String, Color) expiryBadge(DateTime? d, {String never = 'Mai svolta'}) {
  if (d == null) return (never, AppColors.currencyExpired);
  final days = d.difference(DateTime.now()).inDays;
  return (
    'Scad. ${_expiryFmt.format(d)}',
    days < 0
        ? AppColors.currencyExpired
        : days <= CurrencyService.warningDays
        ? AppColors.currencyWarning
        : AppColors.currencyValid,
  );
}

class CurrencyBadgeWidget extends StatelessWidget {
  const CurrencyBadgeWidget({super.key, required this.status});

  final CurrencyStatus status;

  @override
  Widget build(BuildContext context) {
    final highlight = Color.lerp(AppColors.surfaceVariant, status.color, 0.18)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [highlight, status.color.withValues(alpha: 0.14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, size: 14, color: status.color),
          ),
          const SizedBox(width: 8),
          Text(
            status.statusText,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.4,
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
