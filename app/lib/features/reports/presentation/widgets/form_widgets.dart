import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/severity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/category.dart';

/// Selector visual del nivel de importancia con explicación de cada nivel.
class SeveritySelector extends StatelessWidget {
  const SeveritySelector({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == null ? null : Severity.of(value!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (final s in Severity.all)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(s.level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == s.level ? s.color : s.color.withAlpha(28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: s.color.withAlpha(value == s.level ? 255 : 90), width: 1.5),
                  ),
                  child: Column(children: [
                    Text('${s.level}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: value == s.level ? Colors.white : s.color)),
                    Text(s.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: value == s.level ? Colors.white : s.color)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: selected == null
            ? const Padding(
                key: ValueKey('none'),
                padding: EdgeInsets.only(top: 10),
                child: Text('Selecciona qué tan grave es la problemática.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              )
            : Container(
                key: ValueKey(selected.level),
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected.color.withAlpha(22),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(children: [
                  Icon(selected.icon, color: selected.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${selected.label}: ${selected.explanation}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
      ),
    ]);
  }
}

/// Selector de categoría en cuadrícula.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.categories, required this.selectedId, required this.onSelected});
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          ChoiceChip(
            avatar: Icon(c.iconData, size: 18, color: selectedId == c.id ? Colors.white : c.color),
            label: Text(c.name),
            selected: selectedId == c.id,
            showCheckmark: false,
            selectedColor: c.color,
            labelStyle: TextStyle(
              color: selectedId == c.id ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => onSelected(c),
          ),
      ],
    );
  }
}

/// Vista previa de la foto con acciones de cámara/galería.
class PhotoField extends StatelessWidget {
  const PhotoField({super.key, required this.file, required this.onCamera, required this.onGallery, required this.onRemove});
  final File? file;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Image.file(file!, height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(children: [
            _round(Icons.photo_camera_rounded, onCamera),
            const SizedBox(width: 8),
            _round(Icons.delete_outline_rounded, onRemove),
          ]),
        ),
      ]);
    }
    return Row(children: [
      Expanded(child: _option(Icons.photo_camera_rounded, 'Tomar foto', onCamera)),
      const SizedBox(width: 10),
      Expanded(child: _option(Icons.photo_library_rounded, 'Galería', onGallery)),
    ]);
  }

  Widget _round(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
      );

  Widget _option(IconData icon, String label, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.foam,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.aqua),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 32, color: AppColors.ocean),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ocean)),
          ]),
        ),
      );
}

/// Título de un paso del formulario.
class FormStepLabel extends StatelessWidget {
  const FormStepLabel(this.letter, this.title, {super.key, this.optional = false});
  final String letter;
  final String title;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.ocean, shape: BoxShape.circle),
          child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        if (optional)
          const Text('  (opcional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      ]),
    );
  }
}
