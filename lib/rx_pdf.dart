import 'package:pdf/pdf.dart' as pc;
import 'package:pdf/widgets.dart' as pw;
import 'api.dart';
import 'common.dart';

/// Génère l'ordonnance en PDF directement dans l'application (aucune page d'impression) et la télécharge.
Future<void> downloadPrescriptionPdf(String id) async {
  final r = await Api.get('/prescriptions/$id/data') as Map;
  final items = (r['items'] as List);
  final dark = pc.PdfColor.fromInt(0xFF0A3B50);
  final mid = pc.PdfColor.fromInt(0xFF0E5976);
  final accent = pc.PdfColor.fromInt(0xFFFF6F59);

  pw.Widget cell(String t, {bool head = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: head ? pc.PdfColors.white : pc.PdfColors.black,
          ),
        ),
      );

  final doc = pw.Document(title: 'Ordonnance ${r['code']}', author: 'DoktaNet');
  doc.addPage(
    pw.MultiPage(
      pageFormat: pc.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Text('DoktaNet - Ordonnance numérique',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: dark)),
        pw.Divider(color: accent, thickness: 2),
        pw.SizedBox(height: 6),
        pw.Text('Code : ${r['code']}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Date : ${fmtDt(r['created_at'])}', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 8),
        pw.Text('Médecin : Dr ${r['doctor_name']} (${r['specialty']}) - Ordre n° ${r['order_number']}',
            style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Patient : ${r['patient_name']}', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: mid),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: mid),
              children: [cell('Médicament', head: true), cell('Posologie', head: true), cell('Durée', head: true)],
            ),
            for (final i in items) pw.TableRow(children: [cell('${i['name'] ?? ''}'), cell('${i['dosage'] ?? ''}'), cell('${i['duration'] ?? ''}')]),
          ],
        ),
        if ((r['notes'] ?? '').toString().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Remarques : ${r['notes']}', style: const pw.TextStyle(fontSize: 12)),
        ],
        pw.SizedBox(height: 22),
        pw.Text('Signature électronique (HMAC-SHA256) :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Text('${r['signature']}', style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8)),
        pw.SizedBox(height: 4),
        pw.Text('Vérification : ${r['verify_url']}', style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
  final bytes = await doc.save();
  downloadBytes('ordonnance-${r['code']}.pdf', bytes, 'application/pdf');
}
