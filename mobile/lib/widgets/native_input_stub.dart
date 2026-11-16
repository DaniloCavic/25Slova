import 'package:flutter/material.dart';

/// Van weba se ne koristi (vidi native_input_web.dart).
class NativeInput extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextAlign textAlign;
  final TextCapitalization capitalization;
  final bool autocorrect;
  final bool enabled;
  final TextStyle style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<bool>? onFocus;
  const NativeInput({
    super.key,
    required this.controller,
    required this.style,
    this.obscure = false,
    this.keyboardType,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.capitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
