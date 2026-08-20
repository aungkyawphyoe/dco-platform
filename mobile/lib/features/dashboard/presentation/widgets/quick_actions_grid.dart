import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:flutter/material.dart';

class QuickActionItem {
  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.items});

  final List<QuickActionItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: tokens.space.s3,
      crossAxisSpacing: tokens.space.s3,
      childAspectRatio: 1,
      children: [
        for (final item in items) _QuickActionTile(item: item),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.item});

  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.background.card,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Padding(
          padding: EdgeInsets.all(tokens.space.s3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              SizedBox(height: tokens.space.s2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
