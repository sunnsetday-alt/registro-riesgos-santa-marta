import 'package:flutter_test/flutter_test.dart';
import 'package:registro_riesgos_sm/core/utils/geo.dart';
import 'package:registro_riesgos_sm/core/utils/validators.dart';
import 'package:registro_riesgos_sm/data/models/category.dart';
import 'package:registro_riesgos_sm/data/models/report.dart';
import 'package:registro_riesgos_sm/data/models/report_draft.dart';
import 'package:registro_riesgos_sm/features/reports/domain/category_suggester.dart';

Category _cat(int id, String code, String name, List<String> kw) => Category(
      id: id,
      code: code,
      name: name,
      icon: 'report',
      colorHex: '#0077B6',
      priorityWeight: 1,
      keywords: kw,
      isActive: true,
      sortOrder: id,
    );

void main() {
  final categories = [
    _cat(1, 'vias', 'Vías', ['hueco', 'bache', 'pavimento']),
    _cat(2, 'inundaciones', 'Inundaciones', ['inundacion', 'arroyo', 'aguacero']),
    _cat(3, 'alumbrado', 'Alumbrado público', ['luz', 'poste', 'luminaria']),
    _cat(4, 'senalizacion', 'Señalización', ['señal', 'pare']),
  ];

  group('CategorySuggester', () {
    const s = CategorySuggester();

    test('sugiere Vías para un hueco', () {
      final r = s.suggest('Gran hueco en la Avenida Libertador', 'Hay un hueco enorme', categories);
      expect(r?.category.code, 'vias');
    });

    test('ignora tildes y mayúsculas', () {
      final r = s.suggest('INUNDACIÓN en Bonda', 'El arroyo se desbordó con el aguacero', categories);
      expect(r?.category.code, 'inundaciones');
    });

    test('reconoce plurales y ñ', () {
      final r = s.suggest('Señales caídas', 'La señal de pare está en el piso', categories);
      expect(r?.category.code, 'senalizacion');
    });

    test('sugiere severidad alta con términos de peligro', () {
      final r = s.suggest('Poste a punto de caer', 'Peligro: cables sueltos sobre la luz pública', categories);
      expect(r?.suggestedSeverity, greaterThanOrEqualTo(4));
    });

    test('devuelve null sin coincidencias', () {
      expect(s.suggest('Hola', 'Texto sin relación alguna', categories), isNull);
    });
  });

  group('Validators', () {
    test('título', () {
      expect(Validators.reportTitle('abc'), isNotNull);
      expect(Validators.reportTitle('Hueco en la vía'), isNull);
    });
    test('contraseña', () {
      expect(Validators.password('corta1'), isNotNull);
      expect(Validators.password('soloLetras'), isNotNull);
      expect(Validators.password('Segura2026'), isNull);
    });
    test('teléfono opcional', () {
      expect(Validators.phoneOptional(''), isNull);
      expect(Validators.phoneOptional('300 123 4567'), isNull);
      expect(Validators.phoneOptional('abc'), isNotNull);
    });
  });

  group('Geo', () {
    test('Santa Marta está dentro del distrito', () {
      expect(Geo.isInsideDistrict(Geo.santaMarta.latitude, Geo.santaMarta.longitude), isTrue);
      expect(Geo.isInsideDistrict(4.71, -74.07), isFalse); // Bogotá
    });
    test('distancia Haversine coherente con la base de datos (~34 m)', () {
      final d = Geo.distanceMeters(11.23652, -74.19480, 11.23670, -74.19455);
      expect(d, closeTo(33.8, 1.0));
    });
  });

  group('Modelos', () {
    test('ReportDraft se serializa para la cola offline', () {
      final d = ReportDraft(
        clientUuid: 'abc',
        title: 'Hueco',
        description: 'Descripción larga',
        categoryId: 1,
        categoryName: 'Vías',
        severity: 4,
        latitude: 11.24,
        longitude: -74.2,
        address: null,
        localPhotoPath: '/tmp/x.jpg',
        reportedAt: DateTime.utc(2026, 10, 5, 12),
      );
      final back = ReportDraft.fromJson(d.toJson());
      expect(back.clientUuid, 'abc');
      expect(back.severity, 4);
      expect(back.toInsertMap(userId: 'u')['address'], isNull);
    });

    test('Report.fromMap acepta la vista pública y relaciones embebidas', () {
      final base = {
        'id': '1', 'code': 'RSM-2026-000001', 'title': 'T', 'description': 'D',
        'category_id': 1, 'severity': 5, 'status': 'recibido',
        'latitude': 11.2, 'longitude': -74.2, 'created_at': '2026-10-05T10:00:00Z',
      };
      final pub = Report.fromMap({...base, 'category_name': 'Vías', 'sector_name': 'Pando'});
      expect(pub.categoryName, 'Vías');
      expect(pub.userId, isNull);
      final emb = Report.fromMap({...base, 'user_id': 'u', 'categories': {'name': 'Agua', 'code': 'agua'}});
      expect(emb.categoryName, 'Agua');
      expect(emb.userId, 'u');
    });
  });
}
