import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Titolo della card filtri con contatore dei filtri attivi e "Azzera".
class FiltersHeader extends StatelessWidget {
  const FiltersHeader({super.key, required this.active, required this.onClear});

  final int active;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.filter_list, size: 20, color: AppColors.accentGlow),
        const SizedBox(width: 8),
        Text(
          'Filtri',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (active > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$active',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: active > 0 ? onClear : null,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Azzera'),
        ),
      ],
    );
  }
}

/// Gruppo di filtri: etichetta piccola maiuscola e chip allineati a sinistra.
class FilterSection extends StatelessWidget {
  const FilterSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: children),
        ],
      ),
    );
  }
}

/// Chip compatto a selezione multipla; [color] colora bordo e fondo se attivo.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.color = AppColors.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      selectedColor: color.withValues(alpha: 0.28),
      side: BorderSide(
        color: selected ? color : AppColors.border,
        width: selected ? 1.4 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        color: AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Come combinare più chip della stessa sezione: almeno uno / tutti.
class FilterMatchMode extends StatelessWidget {
  const FilterMatchMode({
    super.key,
    required this.all,
    required this.onChanged,
  });

  final bool all;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Più chip nella stessa voce',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: false, label: Text('Almeno uno')),
                ButtonSegment(value: true, label: Text('Tutti')),
              ],
              selected: {all},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
