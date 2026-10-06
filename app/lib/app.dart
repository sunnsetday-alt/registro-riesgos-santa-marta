import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/local_notification_service.dart';

class RegistroRiesgosApp extends ConsumerStatefulWidget {
  const RegistroRiesgosApp({super.key});

  @override
  ConsumerState<RegistroRiesgosApp> createState() => _RegistroRiesgosAppState();
}

class _RegistroRiesgosAppState extends ConsumerState<RegistroRiesgosApp> {
  @override
  void initState() {
    super.initState();
    ref.read(localNotificationServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Registro de Riesgos Santa Marta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Se muestra si la app se compiló sin las variables de entorno.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Falta la configuración del servidor.\n\n'
              'Compila la aplicación con:\n'
              'flutter build apk --release --dart-define-from-file=env.json\n\n'
              'Consulta docs/INSTALACION.md',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
