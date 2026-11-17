import '../../../core/data/almacenes.dart';
import '../../../core/domain/ids.dart';
import '../../../core/domain/reloj.dart';

/// Formulario de consulta (onboarding-account, «Formulario de consulta»).
const textoSinConsultasClinicas = 'No respondemos consultas sobre pacientes ni tratamientos';

const tiposConsulta = {
  'exercise_error': 'Error en un ejercicio',
  'explanation_doubt': 'Duda sobre una explicación',
  'technical': 'Problema técnico',
  'content_suggestion': 'Sugerencia de contenido',
  'other': 'Otro',
};

const estadosConsulta = {
  'pending': 'Pendiente de envío',
  'received': 'Recibida',
  'in_review': 'En revisión',
  'answered': 'Respondida',
};

/// Ejercicio adjunto. La sesión abre `/consulta` con un mapa con las claves
/// del contrato `InquiryInput.exercise`: `variantId`, `templateId`,
/// `questionId`, `answerValue` y `answerUnit` (y, opcionalmente, `etiqueta`).
Map<String, dynamic>? ejercicioAdjunto(Map<String, dynamic>? adjunto) {
  if (adjunto == null || adjunto['variantId'] == null) return null;
  return {
    'variantId': '${adjunto['variantId']}',
    'templateId': adjunto['templateId'],
    'questionId': adjunto['questionId'],
    'answerValue': adjunto['answerValue'],
    'answerUnit': adjunto['answerUnit'],
  };
}

/// Guarda la consulta en el dispositivo como pendiente y la encola. Se envía
/// en cuanto hay conexión (también sin cuenta).
Future<ConsultaGuardada> guardarConsulta({
  required AlmacenAprendizaje almacen,
  required Reloj reloj,
  required String tipo,
  required String mensaje,
  String? correo,
  Map<String, dynamic>? ejercicio,
}) async {
  final ahora = reloj.ahora().toUtc();
  final json = <String, dynamic>{
    'id': nuevoId(),
    'type': tipo,
    'message': mensaje.trim(),
    'replyEmail': (correo == null || correo.trim().isEmpty) ? null : correo.trim(),
    'exercise': ejercicio,
    'createdAt': ahora.toIso8601String(),
  };
  final c = ConsultaGuardada(id: json['id'] as String, json: json, status: 'pending', createdAt: ahora);
  await almacen.guardarConsulta(c);
  await almacen.encolar('inquiry', c.id, json);
  return c;
}
