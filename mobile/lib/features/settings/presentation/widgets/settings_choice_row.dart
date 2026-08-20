import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:flutter/material.dart';

class SettingsChoiceRow<T> extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(width: tokens.space.s3),
          Expanded(
            child: _ChoiceChip(
              label: options[i].label,
              selected: options[i].value == selected,
              onTap: () => onSelected(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.text.accent : tokens.background.input,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? tokens.text.onAccent : tokens.text.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
