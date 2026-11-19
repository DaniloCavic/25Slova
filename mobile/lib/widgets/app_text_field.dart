import 'package:flutter/material.dart';
import '../push/push.dart' show iosStandalone;
import '../theme.dart';
import 'native_input_stub.dart' if (dart.library.js_interop) 'native_input_web.dart';

/// Polje za unos. Svuda je obično Flutter polje, osim na iPhone-u kad je igra dodata na
/// početni ekran: tamo je unutra pravo HTML polje, jer iPhone inače ume da ne otvori tastaturu.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final bool obscureText;
  final bool autocorrect;
  final bool autofocus;
  final bool? enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final TextStyle? style;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.obscureText = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.enabled,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.style,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  /// Lozinka je sakrivena dok se ne dodirne oko.
  late bool _hidden = widget.obscureText;

  /// Polje za lozinku dobija dugme „oko“ (prikaži / sakrij).
  InputDecoration? get _decoration {
    final d = widget.decoration;
    if (!widget.obscureText || d?.suffixIcon != null) return d;
    return (d ?? const InputDecoration()).copyWith(
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Prikaži lozinku' : 'Sakrij lozinku',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget;
    if (!iosStandalone()) {
      return TextField(
        controller: f.controller,
        decoration: _decoration,
        obscureText: _hidden,
        autocorrect: f.autocorrect,
        autofocus: f.autofocus,
        enabled: f.enabled,
        keyboardType: f.keyboardType,
        textInputAction: f.textInputAction,
        textCapitalization: f.textCapitalization,
        maxLength: f.maxLength,
        style: f.style,
        textAlign: f.textAlign,
        onChanged: f.onChanged,
        onSubmitted: f.onSubmitted,
      );
    }
    return _IosField(f, decoration: _decoration, obscure: _hidden);
  }
}

class _IosField extends StatefulWidget {
  final AppTextField f;
  final InputDecoration? decoration;
  final bool obscure;
  const _IosField(this.f, {required this.decoration, required this.obscure});
  @override
  State<_IosField> createState() => _IosFieldState();
}

class _IosFieldState extends State<_IosField> {
  late final TextEditingController _own = TextEditingController();
  TextEditingController get _c => widget.f.controller ?? _own;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_rebuild);
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium!.copyWith(color: textMain).merge(f.style);
    final fontSize = (style.fontSize ?? 16) < 16 ? 16.0 : style.fontSize!;
    final deco = (widget.decoration ?? const InputDecoration())
        .applyDefaults(theme.inputDecorationTheme)
        .copyWith(counterText: '');
    return InputDecorator(
      decoration: deco,
      isEmpty: _c.text.isEmpty && !_focused,
      isFocused: _focused,
      textAlign: f.textAlign,
      child: SizedBox(
        height: fontSize * 1.45,
        child: NativeInput(
          controller: _c,
          style: style.copyWith(fontSize: fontSize),
          obscure: widget.obscure,
          keyboardType: f.keyboardType,
          maxLength: f.maxLength,
          textAlign: f.textAlign,
          capitalization: f.textCapitalization,
          autocorrect: f.autocorrect,
          enabled: f.enabled ?? true,
          onChanged: f.onChanged,
          onSubmitted: f.onSubmitted,
          onFocus: (v) => setState(() => _focused = v),
        ),
      ),
    );
  }
}

/// Isto kao TextFormField (sa proverom unosa), ali preko AppTextField.
class AppTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final bool obscureText;
  final bool autocorrect;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;

  const AppTextFormField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.obscureText = false,
    this.autocorrect = true,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => FormField<String>(
        validator: (_) => validator?.call(controller?.text ?? ''),
        builder: (state) => AppTextField(
          controller: controller,
          decoration: (decoration ?? const InputDecoration()).copyWith(errorText: state.errorText),
          obscureText: obscureText,
          autocorrect: autocorrect,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: state.didChange,
        ),
      );
}
