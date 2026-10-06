import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../data/models/category.dart';
import '../../../data/supabase_providers.dart';
import '../domain/category_suggester.dart';

/// Cliente de la Edge Function `classify-report` (IA opcional).
/// Solo se usa si AI_CLASSIFIER_ENABLED=true y la función está desplegada.
class AiClassifier {
  AiClassifier(this._client);
  final SupabaseClient _client;

  bool get enabled => Env.aiClassifierEnabled;

  Future<CategorySuggestion?> classify(
      String title, String description, List<Category> categories) async {
    if (!enabled) return null;
    final res = await _client.functions.invoke(
      'classify-report',
      body: {'title': title, 'description': description},
    );
    if (res.status != 200 || res.data is! Map) return null;
    final data = Map<String, dynamic>.from(res.data as Map);
    final code = data['category_code'] as String?;
    final match = categories.where((c) => c.code == code);
    if (match.isEmpty) return null;
    return CategorySuggestion(
      category: match.first,
      confidence: 0.8,
      matchedKeywords: [if (data['reason'] != null) data['reason'] as String],
      suggestedSeverity: (data['severity'] as num?)?.toInt(),
      source: 'ai',
    );
  }
}

final aiClassifierProvider =
    Provider<AiClassifier>((ref) => AiClassifier(ref.watch(supabaseProvider)));
