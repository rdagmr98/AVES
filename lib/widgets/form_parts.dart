import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Intestazione con icona in riquadro (form e sezioni del profilo).
class FormHeader extends StatelessWidget {
  const FormHeader({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: hint == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accentGlow, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(hint!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Etichetta sopra il campo (mai `labelText`: nei campi stretti si taglia).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.optional = false,
  });

  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (optional)
                  TextSpan(
                    text: '  facoltativo',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Lista di checkbox con "Seleziona tutti" in testa (privilegi e simili).
class MultiCheckList<T> extends StatelessWidget {
  const MultiCheckList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    final picked = selected.where(options.containsKey).length;
    final all = options.isNotEmpty && picked == options.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.length > 1)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            tristate: true,
            value: all ? true : (picked == 0 ? false : null),
            title: const Text(
              'Seleziona tutti',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onChanged: (_) => onChanged(all ? {} : options.keys.toSet()),
          ),
        for (final MapEntry(:key, :value) in options.entries)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selected.contains(key),
            title: Text(value, softWrap: true),
            onChanged: (on) => onChanged(
              on == true ? {...selected, key} : ({...selected}..remove(key)),
            ),
          ),
      ],
    );
  }
}

/// Barra fissa in basso con l'azione principale del form (pollice su mobile).
class SaveBar extends StatelessWidget {
  const SaveBar({
    super.key,
    required this.label,
    required this.icon,
    required this.saving,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ElevatedButton.icon(
                onPressed: saving ? null : onPressed,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Icon(icon),
                label: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
