import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Professional Math & LaTeX Parser and Formatter for Educational & Research Content.
class MathRenderer {
  MathRenderer._();

  static const Map<String, String> _superscripts = {
    'T': 'ᵀ',
    '-1': '⁻¹',
    '+': '⁺',
    '-': '⁻',
    '=': '⁼',
    '(': '⁽',
    ')': '⁾',
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    'a': 'ᵃ',
    'b': 'ᵇ',
    'c': 'ᶜ',
    'd': 'ᵈ',
    'e': 'ᵉ',
    'f': 'ᶠ',
    'g': 'ᵍ',
    'h': 'ʰ',
    'i': 'ⁱ',
    'j': 'ʲ',
    'k': 'ᵏ',
    'l': 'ˡ',
    'm': 'ᵐ',
    'n': 'ⁿ',
    'o': 'ᵒ',
    'p': 'ᵖ',
    'r': 'ʳ',
    's': 'ˢ',
    't': 'ᵗ',
    'u': 'ᵘ',
    'v': 'ᵛ',
    'w': 'ʷ',
    'x': 'ˣ',
    'y': 'ʸ',
    'z': 'ᶻ',
  };

  static const Map<String, String> _subscripts = {
    '+': '₊',
    '-': '₋',
    '=': '₌',
    '(': '₍',
    ')': '₎',
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    'a': 'ₐ',
    'e': 'ₑ',
    'h': 'ₕ',
    'i': 'ᵢ',
    'j': 'ⱼ',
    'k': 'ₖ',
    'l': 'ₗ',
    'm': 'ₘ',
    'n': 'ₙ',
    'o': 'ₒ',
    'p': 'ₚ',
    'r': 'ᵣ',
    's': 'ₛ',
    't': 'ₜ',
    'u': 'ᵤ',
    'v': 'ᵥ',
    'x': 'ₓ',
  };

  static const Map<String, String> _latexSymbols = {
    r'\times': '×',
    r'\cdot': '·',
    r'\div': '÷',
    r'\pm': '±',
    r'\mp': '∓',
    r'\neq': '≠',
    r'\leq': '≤',
    r'\geq': '≥',
    r'\ll': '≪',
    r'\gg': '≫',
    r'\approx': '≈',
    r'\equiv': '≡',
    r'\sim': '∼',
    r'\propto': '∝',
    r'\Rightarrow': '⇒',
    r'\Leftarrow': '⇐',
    r'\Leftrightarrow': '⇔',
    r'\rightarrow': '→',
    r'\leftarrow': '←',
    r'\leftrightarrow': '↔',
    r'\to': '→',
    r'\mapsto': '↦',
    r'\in': '∈',
    r'\notin': '∉',
    r'\subset': '⊂',
    r'\supset': '⊃',
    r'\subseteq': '⊆',
    r'\supseteq': '⊇',
    r'\cup': '∪',
    r'\cap': '∩',
    r'\emptyset': '∅',
    r'\infty': '∞',
    r'\partial': '∂',
    r'\nabla': '∇',
    r'\forall': '∀',
    r'\exists': '∃',
    r'\sum': '∑',
    r'\prod': '∏',
    r'\int': '∫',
    r'\iint': '∬',
    r'\iiint': '∭',
    r'\oint': '∮',
    r'\sqrt': '√',
    r'\degree': '°',
    r'\circ': '°',
    r'\det': 'det',
    r'\ln': 'ln',
    r'\log': 'log',
    r'\exp': 'exp',
    r'\sin': 'sin',
    r'\cos': 'cos',
    r'\tan': 'tan',
    r'\cot': 'cot',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\epsilon': 'ε',
    r'\theta': 'θ',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\pi': 'π',
    r'\rho': 'ρ',
    r'\sigma': 'σ',
    r'\tau': 'τ',
    r'\phi': 'φ',
    r'\omega': 'ω',
    r'\Gamma': 'Γ',
    r'\Delta': 'Δ',
    r'\Theta': 'Θ',
    r'\Lambda': 'Λ',
    r'\Pi': 'Π',
    r'\Sigma': 'Σ',
    r'\Omega': 'Ω',
    r'\quad': '   ',
    r'\qquad': '      ',
    r'\,': ' ',
    r'\;': ' ',
    r'\!': '',
  };

  /// Converts a LaTeX math expression to clean unicode text
  static String formatMathText(String text) {
    if (text.isEmpty) return text;
    String res = text;

    // 1. Convert LaTeX symbols
    _latexSymbols.forEach((k, v) {
      res = res.replaceAll(k, v);
    });

    // 2. Fractions in text: \frac{a}{b} -> (a / b)
    res = res.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) {
      final num = formatMathText(m.group(1)!);
      final den = formatMathText(m.group(2)!);
      return '($num / $den)';
    });

    // 3. Superscripts: ^{exp} or ^char
    res = res.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (m) {
      final inner = m.group(1)!;
      if (_superscripts.containsKey(inner)) {
        return _superscripts[inner]!;
      }
      return inner.split('').map((c) => _superscripts[c] ?? c).join();
    });

    res = res.replaceAllMapped(RegExp(r'\^([a-zA-Z0-9+-])'), (m) {
      final c = m.group(1)!;
      return _superscripts[c] ?? '^$c';
    });

    // 4. Subscripts: _{sub} or _char
    res = res.replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (m) {
      final inner = m.group(1)!;
      return inner.split('').map((c) => _subscripts[c] ?? c).join();
    });

    res = res.replaceAllMapped(RegExp(r'_([a-zA-Z0-9+-])'), (m) {
      final c = m.group(1)!;
      return _subscripts[c] ?? '_$c';
    });

    // 5. Clean unnecessary leftover curly braces
    res = res.replaceAll('{', '').replaceAll('}', '');

    return res.trim();
  }

  /// Pre-processes inline markdown containing $...$ so math renders cleanly in text
  static String formatInlineMathInMarkdown(String markdown) {
    if (markdown.isEmpty) return markdown;

    // Matches $ ... $ but not $$ ... $$
    final inlineMathRegex = RegExp(r'(?<!\$)\$(?!\$)([^\n$]+?)(?<!\$)\$(?!\$)');

    return markdown.replaceAllMapped(inlineMathRegex, (match) {
      final rawMath = match.group(1)!.trim();
      if (rawMath.isEmpty) return match.group(0)!;

      final formatted = formatMathText(rawMath);
      // Wrap in bold or italic for math distinction
      return '**$formatted**';
    });
  }
}

/// A parsed content segment: either regular Markdown or a Block Math formula
class ContentSegment {
  final bool isMathBlock;
  final String content;

  const ContentSegment.markdown(this.content) : isMathBlock = false;
  const ContentSegment.math(this.content) : isMathBlock = true;
}

/// Splits text into Markdown segments and Block Math ($$ ... $$) segments
List<ContentSegment> splitContentSegments(String raw) {
  final segments = <ContentSegment>[];
  if (raw.isEmpty) return segments;

  final blockMathRegex = RegExp(r'\$\$(.*?)\$\$', dotAll: true);
  int lastEnd = 0;

  for (final match in blockMathRegex.allMatches(raw)) {
    if (match.start > lastEnd) {
      final mdPart = raw.substring(lastEnd, match.start);
      if (mdPart.isNotEmpty) {
        segments.add(ContentSegment.markdown(mdPart));
      }
    }

    final mathBlockContent = match.group(1)!.trim();
    if (mathBlockContent.isNotEmpty) {
      segments.add(ContentSegment.math(mathBlockContent));
    }
    lastEnd = match.end;
  }

  if (lastEnd < raw.length) {
    final remaining = raw.substring(lastEnd);
    if (remaining.isNotEmpty) {
      segments.add(ContentSegment.markdown(remaining));
    }
  }

  return segments;
}

/// Widget that renders a Block Math formula ($$ ... $$) with matrices, fractions, and symbols
class MathBlockCard extends StatelessWidget {
  final String formula;

  const MathBlockCard({super.key, required this.formula});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if formula contains matrices
    final hasMatrix = formula.contains(RegExp(r'\\begin\{(pmatrix|bmatrix|vmatrix|matrix)\}'));
    final hasCases = formula.contains(r'\begin{cases}');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFEDF2F7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasMatrix
                          ? Icons.grid_view_rounded
                          : (hasCases ? Icons.account_tree_outlined : Icons.functions_rounded),
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasMatrix ? 'Matritsa' : (hasCases ? 'Tenglamalar tizimi' : 'Formula'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: formula));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📐 Formula nusxalandi!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nusxalash',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Mathematical Presentation Area
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Center(
              child: _buildFormulaContent(context, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaContent(BuildContext context, bool isDark) {
    if (formula.contains(RegExp(r'\\begin\{(pmatrix|bmatrix|vmatrix|matrix)\}'))) {
      return _buildMatrixFormula(context, isDark);
    } else if (formula.contains(r'\begin{cases}')) {
      return _buildCasesFormula(context, isDark);
    } else {
      return _buildGenericMathText(context, formula, isDark);
    }
  }

  Widget _buildGenericMathText(BuildContext context, String text, bool isDark) {
    // Check for fractions: \frac{a}{b}
    final fractionRegex = RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}');
    if (fractionRegex.hasMatch(text)) {
      return _buildTextWithFractions(context, text, isDark);
    }

    final formatted = MathRenderer.formatMathText(text);
    return SelectableText(
      formatted,
      style: TextStyle(
        fontFamily: 'serif',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.8,
        color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328),
      ),
    );
  }

  Widget _buildTextWithFractions(BuildContext context, String text, bool isDark) {
    final parts = <Widget>[];
    final regex = RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}');
    int last = 0;

    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        final prefix = text.substring(last, m.start);
        parts.add(_buildGenericMathText(context, prefix, isDark));
      }

      final num = MathRenderer.formatMathText(m.group(1)!);
      final den = MathRenderer.formatMathText(m.group(2)!);
      parts.add(_buildFractionWidget(num, den, isDark));

      last = m.end;
    }

    if (last < text.length) {
      final suffix = text.substring(last);
      parts.add(_buildGenericMathText(context, suffix, isDark));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: parts,
    );
  }

  Widget _buildFractionWidget(String numerator, String denominator, bool isDark) {
    final color = isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            numerator,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Container(
            height: 1.5,
            width: (numerator.length > denominator.length ? numerator.length : denominator.length) * 10.0 + 8.0,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: isDark ? AppColors.primary : Colors.black87,
          ),
          Text(
            denominator,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasesFormula(BuildContext context, bool isDark) {
    final inner = formula
        .replaceAll(r'\begin{cases}', '')
        .replaceAll(r'\end{cases}', '')
        .trim();

    final lines = _splitRows(inner);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tall Curly Bracket
        Text(
          '⎧\n⎨\n⎩',
          style: TextStyle(
            fontSize: 22,
            height: 0.95,
            color: isDark ? AppColors.primary : Colors.black87,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) {
            final formatted = MathRenderer.formatMathText(line);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                formatted,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMatrixFormula(BuildContext context, bool isDark) {
    // Splits formula into non-matrix expressions and matrix environments
    final matrixRegex = RegExp(r'\\begin\{(pmatrix|bmatrix|vmatrix|matrix)\}(.*?)\\end\{(pmatrix|bmatrix|vmatrix|matrix)\}', dotAll: true);
    final widgets = <Widget>[];
    int lastEnd = 0;

    for (final match in matrixRegex.allMatches(formula)) {
      if (match.start > lastEnd) {
        final textPart = formula.substring(lastEnd, match.start).trim();
        if (textPart.isNotEmpty) {
          widgets.add(_buildGenericMathText(context, textPart, isDark));
        }
      }

      final type = match.group(1)!;
      final body = match.group(2)!.trim();
      widgets.add(_buildSingleMatrix(type, body, isDark));

      lastEnd = match.end;
    }

    if (lastEnd < formula.length) {
      final remaining = formula.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        widgets.add(_buildGenericMathText(context, remaining, isDark));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: widgets.map((w) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: w,
      )).toList(),
    );
  }

  Widget _buildSingleMatrix(String type, String body, bool isDark) {
    final rowsRaw = _splitRows(body);
    final rows = rowsRaw.map((r) => r.split('&').map((c) => c.trim()).toList()).toList();

    final isDeterminant = type == 'vmatrix';
    final isSquareBracket = type == 'bmatrix';

    final textColor = isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328);

    final tableWidget = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: rows.map((row) {
        return TableRow(
          children: row.map((cell) {
            final formatted = MathRenderer.formatMathText(cell);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Center(
                child: Text(
                  formatted,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );

    // Render with mathematical brackets: ( ) or [ ] or | |
    return CustomPaint(
      painter: _MatrixBracketPainter(
        isDeterminant: isDeterminant,
        isSquareBracket: isSquareBracket,
        color: isDark ? AppColors.primary : const Color(0xFF334155),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: tableWidget,
      ),
    );
  }

  List<String> _splitRows(String body) {
    // Normalizes row separators: \\ or \4 (LLM escaped slash followed by number/minus)
    String normalized = body.replaceAll(r'\\', '###ROW###');

    // Handle single slash before digits or letters: e.g. \4, \-, \2
    normalized = normalized.replaceAllMapped(RegExp(r'\\(?=[0-9\-a-zA-Z])'), (m) => '###ROW###');

    // Split by normalized row tag or newlines
    final parts = normalized.split(RegExp(r'###ROW###|\n'));
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
}

/// Custom Painter for Crisp Mathematical Matrix Brackets
class _MatrixBracketPainter extends CustomPainter {
  final bool isDeterminant;
  final bool isSquareBracket;
  final Color color;

  _MatrixBracketPainter({
    required this.isDeterminant,
    required this.isSquareBracket,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const bracketWidth = 8.0;

    if (isDeterminant) {
      // Determinant: Single vertical bars on both sides | ... |
      canvas.drawLine(const Offset(3, 0), Offset(3, h), paint);
      canvas.drawLine(Offset(w - 3, 0), Offset(w - 3, h), paint);
      return;
    }

    if (isSquareBracket) {
      // bmatrix: [ ... ]
      // Left bracket
      final leftPath = Path()
        ..moveTo(bracketWidth, 0)
        ..lineTo(3, 0)
        ..lineTo(3, h)
        ..lineTo(bracketWidth, h);
      canvas.drawPath(leftPath, paint);

      // Right bracket
      final rightPath = Path()
        ..moveTo(w - bracketWidth, 0)
        ..lineTo(w - 3, 0)
        ..lineTo(w - 3, h)
        ..lineTo(w - bracketWidth, h);
      canvas.drawPath(rightPath, paint);
      return;
    }

    // pmatrix: Curved Parentheses ( ... )
    final leftCurve = Path()
      ..moveTo(bracketWidth, 0)
      ..cubicTo(0, h * 0.2, 0, h * 0.8, bracketWidth, h);
    canvas.drawPath(leftCurve, paint);

    final rightCurve = Path()
      ..moveTo(w - bracketWidth, 0)
      ..cubicTo(w, h * 0.2, w, h * 0.8, w - bracketWidth, h);
    canvas.drawPath(rightCurve, paint);
  }

  @override
  bool shouldRepaint(covariant _MatrixBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.isDeterminant != isDeterminant ||
      oldDelegate.isSquareBracket != isSquareBracket;
}
