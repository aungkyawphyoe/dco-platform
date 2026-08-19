import 'package:flutter/material.dart';

import '../theme/dco_tokens.dart';

class DcoTextField extends StatefulWidget {
  const DcoTextField({
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
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

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
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  State<DcoTextField> createState() => _DcoTextFieldState();
}

class _DcoTextFieldState extends State<DcoTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        SizedBox(height: tokens.space.s2),
        TextField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            counterText: widget.maxLength == null ? '' : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: tokens.icon.inactive,
                    ),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}
