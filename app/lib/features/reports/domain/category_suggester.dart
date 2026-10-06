import '../../../data/models/category.dart';

/// Resultado de la sugerencia de categoría.
class CategorySuggestion {
  final Category category;
  final double confidence; // 0..1
  final List<String> matchedKeywords;
  final int? suggestedSeverity;
  final String source; // 'local' | 'ai'

  const CategorySuggestion({
    required this.category,
    required this.confidence,
    required this.matchedKeywords,
    this.suggestedSeverity,
    this.source = 'local',
  });
}

/// Clasificador local y explicable (sin dependencias externas).
///
/// Compara el texto del ciudadano (normalizado, sin tildes) con las palabras
/// clave de cada categoría (`categories.keywords`, editables desde el panel).
/// Funciona sin conexión. Si la Edge Function de IA está activada, la app
/// puede pedir una segunda opinión (ver [AiClassifier]).
class CategorySuggester {
  const CategorySuggester();

  static String normalize(String s) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Palabras que suelen indicar riesgo alto para personas.
  static const _urgentTerms = [
    'peligro', 'peligroso', 'urgente', 'herido', 'heridos', 'muerte', 'colapso',
    'derrumbe', 'cables', 'electrocut', 'caer', 'caido', 'incendio', 'arrastr', 'niños',
  ];

  CategorySuggestion? suggest(String title, String description, List<Category> categories) {
    final text = ' ${normalize('$title $description')} ';
    if (text.trim().length < 4) return null;

    Category? best;
    var bestScore = 0.0;
    var bestMatches = <String>[];
    for (final c in categories) {
      if (!c.isActive || c.keywords.isEmpty) continue;
      final matches = <String>[];
      var score = 0.0;
      for (final kw in c.keywords) {
        final k = normalize(kw).trim();
        if (k.isEmpty) continue;
        // Coincidencia por palabra completa (o prefijo para plurales).
        if (text.contains(' $k ') || text.contains(' ${k}s ') || text.contains(' ${k}es ')) {
          matches.add(kw);
          score += k.contains(' ') ? 2.0 : 1.0; // frases pesan más
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
        bestMatches = matches;
      }
    }
    if (best == null) return null;

    final urgent = _urgentTerms.where((t) => text.contains(t)).length;
    return CategorySuggestion(
      category: best,
      confidence: (bestScore / 3).clamp(0.2, 1.0),
      matchedKeywords: bestMatches,
      suggestedSeverity: urgent >= 2 ? 5 : (urgent == 1 ? 4 : null),
    );
  }
}
