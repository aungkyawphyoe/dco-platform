import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

/// Auth-only text field: icon-leading, filled background, placeholder inside.
///
/// Matches the reference auth design (login / signup / password recovery).
/// Shared [DcoTextField] (label above) is intentionally left unchanged for the
/// rest of the app.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.icon,
  });

  /// Semantic/accessibility label; also the placeholder when [hint] is null.
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final IconData? icon;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(tokens.radius.md);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: 1),
    );
    return Semantics(
      label: widget.label,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint ?? widget.label,
          errorText: widget.errorText,
          counterText: '',
          filled: true,
          fillColor: tokens.input.background,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.icon == null ? tokens.space.s4 : tokens.space.s2,
            vertical: tokens.space.s4,
          ),
          prefixIcon: widget.icon == null
              ? null
              : Icon(widget.icon, color: tokens.icon.inactive, size: 22),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: widget.obscureText
              ? IconButton(
                  tooltip: _obscured ? s.showPassword : s.hidePassword,
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: tokens.icon.inactive,
                  ),
                )
              : null,
          enabledBorder: border(tokens.input.border),
          focusedBorder: border(tokens.input.borderFocus),
          errorBorder: border(tokens.input.errorBorder),
          focusedErrorBorder: border(tokens.input.errorBorder),
          errorStyle: TextStyle(
            color: tokens.status.dangerFg,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
