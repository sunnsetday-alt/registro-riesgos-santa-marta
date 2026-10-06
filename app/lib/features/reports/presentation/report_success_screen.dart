import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/report_widgets.dart';

/// Confirmación posterior al envío (o al guardado sin conexión).
class ReportSuccessScreen extends StatelessWidget {
  const ReportSuccessScreen({super.key, required this.queued, this.code, this.reportId});
  final bool queued;
  final String? code;
  final String? reportId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (queued ? AppColors.sun : AppColors.success).withAlpha(35),
                ),
                child: Icon(queued ? Icons.cloud_upload_outlined : Icons.check_circle_rounded,
                    size: 72, color: queued ? const Color(0xFFB7791F) : AppColors.success),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              queued ? 'Reporte guardado' : 'Reporte enviado correctamente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (queued)
              const Text(
                'Reporte guardado. Se enviará automáticamente cuando recuperes la conexión.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              )
            else ...[
              const Text('Código de seguimiento', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(code ?? '',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.deepSea, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Estado inicial: ', style: TextStyle(color: AppColors.textSecondary)),
                StatusChip('recibido'),
              ]),
            ],
            const Spacer(),
            if (!queued && reportId != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => context.go('/my-reports/$reportId'),
                child: const Text('Ver mi reporte'),
              ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => context.go('/home'),
              child: const Text('Volver al inicio'),
            ),
          ]),
        ),
      ),
    );
  }
}
