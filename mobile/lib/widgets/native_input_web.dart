import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Pravo HTML polje za unos (iPhone, igra na početnom ekranu): dodir ga direktno fokusira
/// i tastatura se pouzdano otvara — bez uključivanja pristupačnosti za celu aplikaciju.
class NativeInput extends StatefulWidget {
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
  State<NativeInput> createState() => _NativeInputState();
}

class _NativeInputState extends State<NativeInput> {
  web.HTMLInputElement? _el;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_fromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_fromController);
    super.dispose();
  }

  void _fromController() {
    final el = _el;
    if (el != null && el.value != widget.controller.text) el.value = widget.controller.text;
  }

  String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void _setup(Object obj) {
    final el = obj as web.HTMLInputElement;
    _el = el;
    final kt = widget.keyboardType;
    el.type = widget.obscure
        ? 'password'
        : kt == TextInputType.emailAddress
            ? 'email'
            : kt == TextInputType.phone
                ? 'tel'
                : 'text';
    if (kt == TextInputType.number) el.inputMode = 'numeric';
    if (widget.maxLength != null) el.maxLength = widget.maxLength!;
    el.disabled = !widget.enabled;
    el.autocomplete = widget.obscure ? 'current-password' : 'off';
    el.setAttribute('autocapitalize', switch (widget.capitalization) {
      TextCapitalization.characters => 'characters',
      TextCapitalization.words => 'words',
      TextCapitalization.sentences => 'sentences',
      _ => 'none',
    });
    el.setAttribute('autocorrect', widget.autocorrect ? 'on' : 'off');
    el.spellcheck = false;
    final s = widget.style;
    final st = el.style;
    st.width = '100%';
    st.height = '100%';
    st.border = 'none';
    st.outline = 'none';
    st.background = 'transparent';
    st.padding = '0';
    st.margin = '0';
    // 16px ili više — inače iPhone uveličava stranicu pri kucanju.
    st.fontSize = '${(s.fontSize ?? 16) < 16 ? 16 : s.fontSize}px';
    st.fontWeight = '${s.fontWeight?.value ?? 500}';
    st.fontFamily = '-apple-system, system-ui, sans-serif';
    st.color = _hex(s.color ?? const Color(0xFFFFFFFF));
    st.letterSpacing = s.letterSpacing == null ? 'normal' : '${s.letterSpacing}px';
    st.textAlign = widget.textAlign == TextAlign.center ? 'center' : 'left';
    st.setProperty('caret-color', _hex(s.color ?? const Color(0xFFFFFFFF)));
    el.value = widget.controller.text;
    el.addEventListener(
        'input',
        ((web.Event _) {
          var v = el.value;
          if (widget.capitalization == TextCapitalization.characters) v = v.toUpperCase();
          widget.controller.value =
              TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
          widget.onChanged?.call(v);
        }).toJS);
    el.addEventListener(
        'keydown',
        ((web.KeyboardEvent e) {
          if (e.key == 'Enter') {
            el.blur();
            widget.onSubmitted?.call(el.value);
          }
        }).toJS);
    el.addEventListener('focus', ((web.Event _) => widget.onFocus?.call(true)).toJS);
    el.addEventListener('blur', ((web.Event _) => widget.onFocus?.call(false)).toJS);
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(tagName: 'input', onElementCreated: _setup);
}
