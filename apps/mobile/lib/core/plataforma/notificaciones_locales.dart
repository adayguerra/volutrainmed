import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'plataforma.dart';

/// Notificaciones locales del sistema (recordatorio de repaso y aviso previo
/// al fin de la prueba gratuita). Se programan en el dispositivo y se
/// entregan aunque no haya conexión. La inicialización no pide permiso: el
/// permiso de notificaciones se pide en contexto tras la primera lección.
class NotificadorLocal implements Notificador {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _listo;

  Future<void> _iniciar() => _listo ??= () async {
        tzdata.initializeTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(requestAlertPermission: false, requestSoundPermission: false, requestBadgePermission: false),
            macOS: DarwinInitializationSettings(requestAlertPermission: false, requestSoundPermission: false, requestBadgePermission: false),
          ),
        );
      }();

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails('recordatorios', 'Recordatorios', channelDescription: 'Repaso diario y avisos de la suscripción'),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> programar(NotificacionProgramada n) async {
    if (kIsWeb) return;
    try {
      await _iniciar();
      // La hora se programa como instante absoluto (UTC): no depende de la zona.
      final cuando = tz.TZDateTime.from(n.cuando.toUtc(), tz.UTC);
      if (!cuando.isAfter(tz.TZDateTime.now(tz.UTC))) return;
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: cuando,
        notificationDetails: _detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.titulo,
        body: n.texto,
      );
    } catch (e) {
      debugPrint('No se ha podido programar la notificación ${n.id}: $e');
    }
  }

  @override
  Future<void> cancelar(int id) async {
    if (kIsWeb) return;
    try {
      await _iniciar();
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}
