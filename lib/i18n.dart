// ============================================================================
//  i18n — Khmer (default) / English
//  អត្ថបទ UI ទាំងអស់សរសេរជាភាសាខ្មែរ; ពេលភាសា = en → បកប្រែតាមតារាង en[]
//  ពាក្យណាគ្មានក្នុងតារាង → បង្ហាញភាសាខ្មែរដើមវិញ (មិនខូច UI)
// ============================================================================
import 'package:flutter/material.dart';
// ignore: duplicate_import
import 'package:flutter/material.dart' as m;

import 'i18n_en.dart';

export 'package:flutter/material.dart' hide Text;

class Lang {
  static String code = 'km';

  static String tr(String s) {
    if (code == 'km' || s.isEmpty) return s;
    return en[s] ?? s;
  }
}

/// អ្នកបង្កប់ភាសា — Text ទាំងអស់ rebuild ពេលភាសាផ្លាស់ (ទោះជា const)
class LangScope extends InheritedWidget {
  final String code;
  const LangScope({super.key, required this.code, required super.child});

  static String codeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>()?.code ?? Lang.code;

  @override
  bool updateShouldNotify(LangScope oldWidget) => oldWidget.code != code;
}

/// Text ជំនួស — បកប្រែអត្ថបទខ្មែរដោយស្វ័យប្រវត្តិ ពេលភាសាអង់គ្លេស
class Text extends StatelessWidget {
  final String? _data;
  final InlineSpan? _span;

  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const Text(String data,
      {super.key,
      this.style,
      this.strutStyle,
      this.textAlign,
      this.textDirection,
      this.locale,
      this.softWrap,
      this.overflow,
      this.textScaler,
      this.maxLines,
      this.semanticsLabel,
      this.textWidthBasis,
      this.textHeightBehavior,
      this.selectionColor})
      : _data = data,
        _span = null;

  const Text.rich(InlineSpan span,
      {super.key,
      this.style,
      this.strutStyle,
      this.textAlign,
      this.textDirection,
      this.locale,
      this.softWrap,
      this.overflow,
      this.textScaler,
      this.maxLines,
      this.semanticsLabel,
      this.textWidthBasis,
      this.textHeightBehavior,
      this.selectionColor})
      : _span = span,
        _data = null;

  @override
  Widget build(BuildContext context) {
    final code = LangScope.codeOf(context);
    if (_data != null) {
      final data = _data!;
      return m.Text(code == 'km' ? data : (en[data] ?? data),
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor);
    }
    return m.Text.rich(translateSpan(_span!, code),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor);
  }
}

InlineSpan translateSpan(InlineSpan span, String code) {
  if (span is! TextSpan) return span;
  final t = span.text;
  final kids = span.children == null
      ? null
      : span.children!.map((c) => translateSpan(c, code)).toList();
  return TextSpan(
    text: (t == null || code == 'km') ? t : (en[t] ?? t),
    children: kids,
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    semanticsIdentifier: span.semanticsIdentifier,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}
