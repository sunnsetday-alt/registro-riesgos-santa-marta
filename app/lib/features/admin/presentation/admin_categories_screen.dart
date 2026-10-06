import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/category_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../data/models/category.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../../reports/application/reports_providers.dart';
import '../application/admin_providers.dart';
import '../data/admin_repository.dart';

/// Gestión de categorías: nombre, ícono, color, peso de prioridad, palabras
/// clave del clasificador y activación.
class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [Category? c]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CategorySheet(category: c),
    );
    if (ok == true) {
      ref.invalidate(adminCategoriesProvider);
      ref.invalidate(categoriesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(sessionProvider.select((s) => s.isAdmin));
    final cats = ref.watch(adminCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva'),
            )
          : null,
      body: AsyncView<List<Category>>(
        value: cats,
        onRetry: () => ref.invalidate(adminCategoriesProvider),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = list[i];
            return AppCard(
              padding: const EdgeInsets.all(12),
              onTap: isAdmin ? () => _edit(context, ref, c) : null,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.color.withAlpha(35), borderRadius: BorderRadius.circular(12)),
                  child: Icon(c.iconData, color: c.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: TextStyle(fontWeight: FontWeight.w700,
                        decoration: c.isActive ? null : TextDecoration.lineThrough)),
                    Text('Peso de prioridad ${c.priorityWeight.toStringAsFixed(2)} · ${c.keywords.length} palabras clave',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                if (!c.isActive) const Chip(label: Text('Inactiva'), visualDensity: VisualDensity.compact),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.category});
  final Category? category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _code = TextEditingController(text: widget.category?.code ?? '');
  late final _color = TextEditingController(text: widget.category?.colorHex ?? '#0077B6');
  late final _keywords = TextEditingController(text: widget.category?.keywords.join(', ') ?? '');
  late String _icon = widget.category?.icon ?? 'report';
  late double _weight = widget.category?.priorityWeight ?? 1.0;
  late bool _active = widget.category?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _code, _color, _keywords]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final c = Category(
      id: widget.category?.id ?? 0,
      code: _code.text.trim(),
      name: _name.text.trim(),
      icon: _icon,
      colorHex: _color.text.trim().toUpperCase(),
      priorityWeight: double.parse(_weight.toStringAsFixed(2)),
      keywords: _keywords.text.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList(),
      isActive: _active,
      sortOrder: widget.category?.sortOrder ?? 50,
    );
    try {
      await ref.read(adminRepositoryProvider).saveCategory(c, id: widget.category?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Nombre requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            enabled: widget.category == null,
            decoration: const InputDecoration(labelText: 'Código interno (a-z y _)'),
            validator: (v) => RegExp(r'^[a-z_]{2,40}$').hasMatch(v?.trim() ?? '') ? null : 'Solo minúsculas y _',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _color,
            decoration: const InputDecoration(labelText: 'Color (#RRGGBB)'),
            validator: (v) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v?.trim() ?? '') ? null : 'Formato #RRGGBB',
          ),
          const SizedBox(height: 14),
          const Text('Ícono', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in CategoryIcons.map.entries)
              ChoiceChip(
                label: Icon(e.value, size: 20),
                selected: _icon == e.key,
                onSelected: (_) => setState(() => _icon = e.key),
              ),
          ]),
          const SizedBox(height: 14),
          Text('Peso en el índice de prioridad: ${_weight.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _weight, min: 0.5, max: 1.5, divisions: 20, onChanged: (v) => setState(() => _weight = v)),
          TextFormField(
            controller: _keywords,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Palabras clave (separadas por coma)',
              helperText: 'Usadas para sugerir automáticamente esta categoría.',
            ),
          ),
          SwitchListTile(
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Categoría activa'),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando…' : 'Guardar')),
        ]),
      ),
    );
  }
}
