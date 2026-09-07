import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';

class CustomFloatingNavBar extends StatefulWidget {
  const CustomFloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 64,
    this.horizontalMargin = 20,
    this.bottomMargin = 16,
  });

  final List<CustomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;
  final double horizontalMargin;
  final double bottomMargin;

  @override
  State<CustomFloatingNavBar> createState() => _CustomFloatingNavBarState();
}

class _CustomFloatingNavBarState extends State<CustomFloatingNavBar> {
  static const _barBackground = Color(0xFF1A2832);
  static const _glowBorder = Color(0xFFA855F7);
  static const _activeFill = Color(0xFF38244B);
  static const _inactiveIcon = Color(0xFFB3A8C1);
  static const _activeContent = Colors.white;
  static const _dropShadow = Color(0x4411091C);
  static const _itemPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
  static const _gap = 6.0;
  static const _radius = 50.0;
  static const _outerPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);
  static const _itemSpacing = 8.0;
  static const _animDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.currentIndex;
    final items = widget.items;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomMargin),
      child: AnimatedSize(
        duration: _animDuration,
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.none,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _barBackground,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                BoxShadow(
                  color: _dropShadow,
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: _outerPadding,
              child: SizedBox(
                height: widget.height - 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: _itemSpacing),
                      _NavItem(
                        item: items[i],
                        selected: selectedIndex == i,
                        onTap: () => widget.onTap(i),
                        barRadius: _radius,
                        activeFill: _activeFill,
                        glowBorder: _glowBorder,
                        inactiveIcon: _inactiveIcon,
                        activeContent: _activeContent,
                        itemPadding: _itemPadding,
                        gap: _gap,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomNavItem {
  const CustomNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.barRadius,
    required this.activeFill,
    required this.glowBorder,
    required this.inactiveIcon,
    required this.activeContent,
    required this.itemPadding,
    required this.gap,
  });

  final CustomNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final double barRadius;
  final Color activeFill;
  final Color glowBorder;
  final Color inactiveIcon;
  final Color activeContent;
  final EdgeInsets itemPadding;
  final double gap;

  static const _animDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? activeContent : inactiveIcon;
    final iconData = selected ? (item.activeIcon ?? item.icon) : item.icon;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(barRadius),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: _animDuration,
        curve: Curves.easeOutCubic,
        padding: itemPadding,
        decoration: BoxDecoration(
          color: selected ? activeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(barRadius),
          border: selected
              ? Border.all(color: glowBorder, width: 1.2)
              : Border.all(color: Colors.transparent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: _animDuration,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(
                iconData,
                key: ValueKey(iconData),
                size: 24,
                color: iconColor,
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: _animDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: selected ? 1.0 : 0.0,
                child: Padding(
                  padding: EdgeInsets.only(left: gap),
                  child: AnimatedDefaultTextStyle(
                    duration: _animDuration,
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: activeContent,
                    ),
                    child: Text(item.label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}