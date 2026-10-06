import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/category.dart';
import '../../../data/models/report_draft.dart';
import '../../../shared/widgets/common.dart';
import '../../map/location_service.dart';
import '../application/reports_providers.dart';
import '../data/ai_classifier.dart';
import '../data/photo_service.dart';
import '../domain/category_suggester.dart';
import 'widgets/form_widgets.dart';
import 'widgets/location_picker.dart';

/// Formulario "REPORTAR PROBLEMÁTICA" (pasos A–H).
class CreateReportScreen extends ConsumerStatefulWidget {
  const CreateReportScreen({super.key});

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _clientUuid = const Uuid().v4();
  final _reportedAt = DateTime.now(); // H. fecha y hora automática

  Category? _category;
  int? _severity;
  LatLng _position = Geo.santaMarta;
  bool _hasGps = false;
  bool _locating = false;
  double? _accuracy;
  File? _photo;

  CategorySuggestion? _suggestion;
  bool _aiLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _locate();
    _title.addListener(_scheduleSuggestion);
    _description.addListener(_scheduleSuggestion);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final res = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.ok) {
        _position = LatLng(res.latitude!, res.longitude!);
        _accuracy = res.accuracy;
        _hasGps = true;
      }
    });
    if (!res.ok && res.error != null) showSnack(context, res.error!, error: true);
  }

  void _scheduleSuggestion() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final cats = ref.read(categoriesProvider).valueOrNull;
      if (cats == null || !mounted) return;
      final s = const CategorySuggester().suggest(_title.text, _description.text, cats);
      setState(() => _suggestion = (s != null && s.category.id != _category?.id) ? s : null);
    });
  }

  Future<void> _askAi() async {
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    setState(() => _aiLoading = true);
    try {
      final s = await ref.read(aiClassifierProvider).classify(_title.text, _description.text, cats);
      if (!mounted) return;
      if (s == null) {
        showSnack(context, 'El asistente no pudo sugerir una categoría.');
      } else {
        setState(() => _suggestion = s);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'El asistente de clasificación no está disponible.', error: true);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _applySuggestion() {
    final s = _suggestion;
    if (s == null) return;
    setState(() {
      _category = s.category;
      if (_severity == null && s.suggestedSeverity != null) _severity = s.suggestedSeverity;
      _suggestion = null;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final f = await ref.read(photoServiceProvider).pick(source);
      if (f != null && mounted) setState(() => _photo = f);
    } catch (_) {
      if (mounted) showSnack(context, 'No se pudo acceder a la cámara o galería.', error: true);
    }
  }

  void _review() {
    final valid = _formKey.currentState?.validate() ?? false;
    String? problem;
    if (_category == null) {
      problem = 'Selecciona una categoría.';
    } else if (_severity == null) {
      problem = 'Selecciona el nivel de importancia.';
    } else if (!Geo.isInsideDistrict(_position.latitude, _position.longitude)) {
      problem = 'La ubicación debe estar dentro del Distrito de Santa Marta.';
    }
    if (!valid || problem != null) {
      if (problem != null) showSnack(context, problem, error: true);
      return;
    }
    if (!_hasGps) {
      // Se permite continuar, pero se advierte que se use el mapa.
      showSnack(context, 'Verifica en el mapa que el marcador esté en el lugar correcto.');
    }
    final draft = ReportDraft(
      clientUuid: _clientUuid,
      title: _title.text.trim(),
      description: _description.text.trim(),
      categoryId: _category!.id,
      categoryName: _category!.name,
      severity: _severity!,
      latitude: _position.latitude,
      longitude: _position.longitude,
      address: _address.text.trim(),
      localPhotoPath: _photo?.path,
      reportedAt: _reportedAt,
    );
    context.push('/report/confirm', extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final ai = ref.watch(aiClassifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar problemática')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            const FormStepLabel('A', 'Título'),
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ej.: Gran hueco en la Avenida Libertador'),
              validator: Validators.reportTitle,
            ),
            const FormStepLabel('B', 'Descripción'),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Explica qué está ocurriendo, desde cuándo y a quién afecta.',
              ),
              validator: Validators.reportDescription,
            ),
            const FormStepLabel('C', 'Categoría'),
            if (_suggestion != null) _SuggestionBanner(suggestion: _suggestion!, onApply: _applySuggestion),
            if (ai.enabled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _aiLoading || _description.text.trim().length < 10 ? null : _askAi,
                  icon: _aiLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Sugerir categoría con el asistente'),
                ),
              ),
            AsyncView<List<Category>>(
              value: categories,
              onRetry: () => ref.invalidate(categoriesProvider),
              data: (cats) => CategoryGrid(
                categories: cats,
                selectedId: _category?.id,
                onSelected: (c) => setState(() {
                  _category = c;
                  if (_suggestion?.category.id == c.id) _suggestion = null;
                }),
              ),
            ),
            const FormStepLabel('D', 'Nivel de importancia'),
            SeveritySelector(value: _severity, onChanged: (v) => setState(() => _severity = v)),
            const FormStepLabel('E', 'Ubicación'),
            LocationPicker(
              position: _position,
              accuracy: _accuracy,
              locating: _locating,
              onLocateMe: _locate,
              onChanged: (p) => setState(() {
                _position = p;
                _accuracy = null;
              }),
            ),
            const FormStepLabel('F', 'Dirección o referencia', optional: true),
            TextFormField(
              controller: _address,
              maxLength: 250,
              decoration: const InputDecoration(
                hintText: 'Ej.: Avenida Libertador, cerca de la entrada al barrio X',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: Validators.address,
            ),
            const FormStepLabel('G', 'Fotografía', optional: true),
            PhotoField(
              file: _photo,
              onCamera: () => _pickPhoto(ImageSource.camera),
              onGallery: () => _pickPhoto(ImageSource.gallery),
              onRemove: () => setState(() => _photo = null),
            ),
            const SizedBox(height: 10),
            const Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text('La fecha y hora se registran automáticamente.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _review,
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('REVISAR REPORTE'),
          ),
        ),
      ),
    );
  }
}

class _SuggestionBanner extends StatelessWidget {
  const _SuggestionBanner({required this.suggestion, required this.onApply});
  final CategorySuggestion suggestion;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final c = suggestion.category;
    final why = suggestion.source == 'ai'
        ? (suggestion.matchedKeywords.isNotEmpty ? suggestion.matchedKeywords.first : 'Sugerido por el asistente')
        : 'Detectado: ${suggestion.matchedKeywords.take(3).join(', ')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color.withAlpha(90)),
      ),
      child: Row(children: [
        Icon(suggestion.source == 'ai' ? Icons.auto_awesome_rounded : Icons.lightbulb_outline_rounded, color: c.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¿Categoría "${c.name}"?', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(why, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        TextButton(onPressed: onApply, child: const Text('Usar')),
      ]),
    );
  }
}
