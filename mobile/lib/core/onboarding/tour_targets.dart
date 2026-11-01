import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stable identifiers for controls the post-login tour can point at.
///
/// Features register real widgets with [TourAnchor] and the onboarding overlay
/// resolves their on-screen position. Keeping the contract here lets the app
/// shell, dashboard, and navigation share targets without importing another
/// feature's presentation or data layer.
enum TourTarget { vehicle, maintenance, expenses, settings }

/// Holds the live [GlobalKey] for each anchored target.
class TourTargetRegistry {
  final Map<TourTarget, GlobalKey> _keys = {};

  GlobalKey? keyFor(TourTarget target) => _keys[target];

  void register(TourTarget target, GlobalKey key) {
    _keys[target] = key;
  }

  void unregister(TourTarget target, GlobalKey key) {
    if (identical(_keys[target], key)) _keys.remove(target);
  }

  void clear() => _keys.clear();
}

final tourTargetRegistryProvider = Provider<TourTargetRegistry>((ref) {
  final registry = TourTargetRegistry();
  ref.onDispose(registry.clear);
  return registry;
});

/// Marks a widget as a tour target without changing its layout or behaviour.
class TourAnchor extends StatefulWidget {
  const TourAnchor({super.key, required this.target, required this.child});

  final TourTarget target;
  final Widget child;

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  late final GlobalKey _key;
  TourTargetRegistry? _registry;

  @override
  void initState() {
    super.initState();
    _key = GlobalKey(debugLabel: 'tour-${widget.target.name}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ProviderScope.containerOf(
      context,
    ).read(tourTargetRegistryProvider);
    if (identical(_registry, registry)) return;
    _registry?.unregister(widget.target, _key);
    _registry = registry..register(widget.target, _key);
  }

  @override
  void didUpdateWidget(TourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target == widget.target) return;
    _registry
      ?..unregister(oldWidget.target, _key)
      ..register(widget.target, _key);
  }

  @override
  void dispose() {
    _registry?.unregister(widget.target, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
