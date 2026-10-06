import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Muestra la política de privacidad o los términos (assets/legal/*.md).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc; // 'privacidad' | 'terminos'

  @override
  Widget build(BuildContext context) {
    final title = doc == 'terminos' ? 'Términos y condiciones' : 'Política de privacidad';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/${doc == 'terminos' ? 'terminos' : 'privacidad'}.md'),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.sun.withAlpha(45), borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'TEXTO PRELIMINAR: debe ser revisado por un abogado antes de un lanzamiento oficial.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            for (final line in snap.data!.split('\n')) _line(line),
          ]);
        },
      ),
    );
  }

  /// Render mínimo de Markdown (títulos, viñetas y párrafos).
  Widget _line(String line) {
    final t = line.trimRight();
    if (t.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(t.substring(2), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      );
    }
    if (t.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t.substring(3), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
      );
    }
    if (t.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  '),
          Expanded(child: Text(t.substring(2).replaceAll('**', ''))),
        ]),
      );
    }
    if (t.isEmpty) return const SizedBox(height: 8);
    return Text(t.replaceAll('**', ''), style: const TextStyle(height: 1.45));
  }
}
