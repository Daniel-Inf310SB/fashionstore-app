import 'package:flutter/material.dart';
import '../../models/return_request.dart';
import 'return_style.dart';

/// Resumen visual. FastAPI sigue siendo la autoridad sobre la elegibilidad.
class ReturnPolicyNotice extends StatelessWidget {
  const ReturnPolicyNotice({super.key, required this.eligibility});
  final ReturnEligibility eligibility;

  String _format(DateTime value) {
    final v = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(v.day)}/${two(v.month)}/${v.year} a las ${two(v.hour)}:${two(v.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final expires = eligibility.expiresAt;
    final expired = eligibility.isExpired;
    final accepted = eligibility.canRequest && !expired;
    final title = expired
        ? 'Plazo de devolución vencido'
        : !eligibility.canRequest
            ? 'Devolución no disponible'
            : expires == null
                ? 'Política de devoluciones: ${eligibility.windowDays} días'
                : 'Devolución dentro del plazo';
    final detail = expired
        ? 'Han transcurrido los ${eligibility.windowDays} días desde la entrega. No puedes iniciar una nueva solicitud ordinaria.'
        : !eligibility.canRequest
            ? (eligibility.reason ?? 'Este pedido no tiene prendas elegibles.')
            : expires == null
                ? 'El plazo comienza con la entrega efectiva. La tienda debe confirmar la fecha y la elegibilidad.'
                : 'Entrega confirmada: ${eligibility.deliveredAt == null ? 'Sin fecha' : _format(eligibility.deliveredAt!)}.\nFecha límite para solicitar: ${_format(expires)}.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ReturnStyle.canvas,
        border: Border.all(color: ReturnStyle.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(accepted ? Icons.verified_outlined : Icons.event_busy_outlined,
            color: accepted ? const Color(0xFF187D55) : ReturnStyle.accent, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: ReturnStyle.grey, height: 1.4, fontSize: 12)),
        ])),
      ]),
    );
  }
}
