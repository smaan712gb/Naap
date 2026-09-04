/// Shareable report artifacts beyond the tailor parchi:
///
/// - Size Passport: one page of international sizes + key body numbers —
///   the "never buy the wrong size online again" artifact for mainstream
///   users, men and women.
/// - Body Drift Report: baseline scan vs latest with deltas — what a
///   bespoke/MTM house wants from a remote client between fittings.
///
/// Same privacy contract as the parchi: numbers only, generated on-device.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app_state.dart' show ScanRecord;
import '../models/measurements.dart';
import '../models/profile.dart';
import '../sizing.dart';

const _brandGreen = PdfColor.fromInt(0xFF1B4D3E);
const _softGreen = PdfColor.fromInt(0xFFE8F1EC);
const _gold = PdfColor.fromInt(0xFFC9A227);

class ReportsPdf {
  static pw.TextStyle _en(double s, {bool bold = false}) => pw.TextStyle(
      font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
      fontSize: s);

  static String _fmt(double cm, PreferredUnit unit) =>
      unit == PreferredUnit.inches
          ? '${(cm / 2.54).toStringAsFixed(1)}"'
          : '${cm.toStringAsFixed(1)} cm';

  static pw.Widget _header(String title, String subtitle) => pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
            color: _brandGreen, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title,
                      style: _en(17, bold: true)
                          .copyWith(color: PdfColors.white)),
                  pw.SizedBox(height: 3),
                  pw.Text(subtitle,
                      style: _en(9).copyWith(color: PdfColors.grey300)),
                ]),
            pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://getnaap.com',
                color: PdfColors.white,
                width: 42,
                height: 42),
          ],
        ),
      );

  static pw.Widget _footer() => pw.Text(
      'Generated on-device by Naap. No photos were uploaded - measurements '
      'only. getnaap.com',
      style: _en(7.5).copyWith(color: PdfColors.grey600));

  static Future<File> _save(pw.Document doc, String stem) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${stem}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    final Uint8List bytes = await doc.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  // ------------------------------------------------------------ passport

  static Future<File> buildSizePassport({
    required UserProfile profile,
    required Naap naap,
  }) async {
    final doc = pw.Document(title: 'Naap Size Passport', producer: 'Naap');
    final unit = profile.unit;
    final isFemale = profile.bodyType == BodyType.female;
    final ladies = isFemale ? mapLadiesSizes(naap) : null;
    final mens = isFemale ? null : mapSuMisura(naap);

    pw.Widget sizeChip(String label, String value) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
              color: _softGreen, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Text(value,
                style: _en(16, bold: true).copyWith(color: _brandGreen)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: _en(8).copyWith(color: PdfColors.grey700)),
          ]),
        );

    const passportKeys = [
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
      MeasurementKey.shoulder,
      MeasurementKey.sleeveLength,
      MeasurementKey.neck,
      MeasurementKey.inseam,
    ];

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(26),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(
              'SIZE PASSPORT',
              profile.name.isEmpty
                  ? DateFormat('d MMM yyyy').format(DateTime.now())
                  : '${profile.name} · ${DateFormat('d MMM yyyy').format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          if (ladies != null) ...[
            pw.Text('Ready-to-wear sizes', style: _en(11, bold: true)),
            pw.SizedBox(height: 8),
            pw.Wrap(spacing: 8, runSpacing: 8, children: [
              sizeChip('EU / DE', '${ladies.eu}'),
              sizeChip('IT', '${ladies.it}'),
              sizeChip('FR', '${ladies.fr}'),
              sizeChip('UK', '${ladies.uk}'),
              sizeChip('US', '${ladies.us}'),
            ]),
            if (ladies.notes.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              for (final n in ladies.notes)
                pw.Text('• $n',
                    style: _en(8.5).copyWith(color: PdfColors.grey800)),
            ],
          ] else if (mens != null) ...[
            pw.Text('Suit & jacket size', style: _en(11, bold: true)),
            pw.SizedBox(height: 8),
            pw.Wrap(spacing: 8, runSpacing: 8, children: [
              sizeChip('EU', '${mens.euSize}'),
              sizeChip('US / UK', '${mens.euSize - 10}'),
              sizeChip('Drop', '${mens.drop}'),
            ]),
            if (mens.notes.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              for (final n in mens.notes)
                pw.Text('• $n',
                    style: _en(8.5).copyWith(color: PdfColors.grey800)),
            ],
          ],
          pw.SizedBox(height: 16),
          pw.Text('Key measurements', style: _en(11, bold: true)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: _softGreen),
            headerStyle: _en(8.5, bold: true).copyWith(color: _brandGreen),
            cellStyle: _en(9),
            headers: ['Measurement', 'Value'],
            data: [
              for (final k in passportKeys)
                if (naap[k] != null)
                  [kMeasurementDefs[k]!.english, _fmt(naap[k]!.cm, unit)],
            ],
          ),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _gold, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text(
                'Shop online without the returns lottery: these sizes are '
                'measured, not guessed. Standard conventions - individual '
                'brands vary.',
                style: _en(8)),
          ),
          pw.SizedBox(height: 8),
          _footer(),
        ],
      ),
    ));
    return _save(doc, 'naap_size_passport');
  }

  // --------------------------------------------------------------- drift

  static Future<File> buildDriftReport({
    required UserProfile profile,
    required ScanRecord baseline,
    required ScanRecord latest,
  }) async {
    final doc =
        pw.Document(title: 'Naap Body Drift Report', producer: 'Naap');
    final unit = profile.unit;
    final df = DateFormat('d MMM yyyy');

    const driftKeys = [
      MeasurementKey.neck,
      MeasurementKey.shoulder,
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.belly,
      MeasurementKey.hip,
      MeasurementKey.bicep,
      MeasurementKey.thigh,
    ];

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(
              'BODY DRIFT REPORT',
              '${profile.name.isEmpty ? 'Client' : profile.name} · '
                  '${df.format(baseline.date)} → ${df.format(latest.date)}'),
          pw.SizedBox(height: 14),
          pw.Text(
              'For the tailoring house: girth changes since the baseline '
              'scan. Relative change between identically-taken scans is '
              'more reliable than any absolute number - use it to adjust '
              'the block before the next commission, not as a cutting '
              'spec.',
              style: _en(9.5).copyWith(color: PdfColors.grey800)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: _softGreen),
            headerStyle: _en(9, bold: true).copyWith(color: _brandGreen),
            cellStyle: _en(9.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
            headers: [
              'Measurement',
              df.format(baseline.date),
              df.format(latest.date),
              'Change',
            ],
            data: [
              for (final k in driftKeys)
                if (baseline.naap[k] != null && latest.naap[k] != null)
                  [
                    kMeasurementDefs[k]!.english,
                    _fmt(baseline.naap[k]!.cm, unit),
                    _fmt(latest.naap[k]!.cm, unit),
                    _delta(baseline.naap[k]!.cm, latest.naap[k]!.cm, unit),
                  ],
            ],
            cellBuilder: (col, data, row) {
              if (col != 3) return null;
              final txt = '$data';
              final color = txt.startsWith('+')
                  ? const PdfColor.fromInt(0xFFB00020)
                  : txt.startsWith('−') || txt.startsWith('-')
                      ? _brandGreen
                      : PdfColors.grey700;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 3, horizontal: 4),
                child: pw.Text(txt,
                    style: _en(9.5, bold: true).copyWith(color: color),
                    textAlign: pw.TextAlign.center),
              );
            },
          ),
          pw.Spacer(),
          _footer(),
        ],
      ),
    ));
    return _save(doc, 'naap_drift_report');
  }

  static String _delta(double fromCm, double toCm, PreferredUnit unit) {
    final d = toCm - fromCm;
    if (d.abs() < 0.05) return '-';
    final v = unit == PreferredUnit.inches ? d / 2.54 : d;
    return '${d > 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)}'
        '${unit == PreferredUnit.inches ? '"' : ' cm'}';
  }
}

/// Atelier Specification — the third document, for Western MTM houses
/// and their associates. Cutting-ticket idiom: EU size and drop as the
/// headline, body truth + block deltas in centimetres, posture
/// figuration, optionally white-labeled with the house's own name.
/// No bazaar vocabulary, no QR marketing — a working atelier paper.
extension AtelierSpec on ReportsPdf {
  static const _specKeys = [
    MeasurementKey.chest, MeasurementKey.waist, MeasurementKey.hip,
    MeasurementKey.shoulder, MeasurementKey.sleeveLength, MeasurementKey.neck,
    MeasurementKey.overArm, MeasurementKey.frontChest,
    MeasurementKey.backWidth, MeasurementKey.jacketLength,
    MeasurementKey.bicep, MeasurementKey.wrist,
    MeasurementKey.trouserWaist, MeasurementKey.thigh,
    MeasurementKey.knee, MeasurementKey.calf,
  ];

  static Future<File> buildAtelierSpec({
    required UserProfile profile,
    required Naap naap,
    String? house, // white-label: the atelier's own name
    String? postureSummary,
  }) async {
    final doc = pw.Document();
    final female = profile.bodyType == BodyType.female;
    final su = female ? null : mapSuMisura(naap);
    final ladies = female ? mapLadiesSizes(naap) : null;

    // One body, every convention — side by side, no filtering needed on
    // paper. Men: EU/IT share the scale, UK/US = EU-10 (R length).
    final sizeCells = <(String, String)>[
      if (su != null) ...[
        ('EU', '${su.euSize}'),
        ('IT', '${su.euSize}'),
        ('UK', '${su.euSize - 10}'),
        ('US', '${su.euSize - 10}R'),
        ('DROP', '${su.drop}'),
      ],
      if (ladies != null) ...[
        ('EU', '${ladies.eu}'),
        ('IT', '${ladies.it}'),
        ('FR', '${ladies.fr}'),
        ('UK', '${ladies.uk}'),
        ('US', '${ladies.us}'),
      ],
    ];
    final ink = const PdfColor.fromInt(0xFF14110F);
    final stone = const PdfColor.fromInt(0xFF8C877D);
    pw.TextStyle label() => pw.TextStyle(
        font: pw.Font.helvetica(), fontSize: 7, color: stone,
        letterSpacing: 1.6);
    // cm and inches side by side — Milan and New York read the same row.
    pw.Widget row(String name, double cm) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColor.fromInt(0xFFDCD8D0), width: .5))),
          child: pw.Row(children: [
            pw.Expanded(
                child: pw.Text(name,
                    style: pw.TextStyle(
                        font: pw.Font.helvetica(), fontSize: 9.5))),
            pw.SizedBox(
                width: 44,
                child: pw.Text(cm.toStringAsFixed(1),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: pw.Font.helveticaBold(), fontSize: 9.5))),
            pw.SizedBox(
                width: 40,
                child: pw.Text((cm / 2.54).toStringAsFixed(1),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 9, color: stone))),
          ]),
        );

    pw.Widget colHead() => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(children: [
            pw.Expanded(child: pw.SizedBox()),
            pw.SizedBox(
                width: 44,
                child: pw.Text('CM',
                    textAlign: pw.TextAlign.right, style: label())),
            pw.SizedBox(
                width: 40,
                child: pw.Text('IN',
                    textAlign: pw.TextAlign.right, style: label())),
          ]),
        );

    final present = <MeasurementKey>[
      for (final k in _specKeys)
        if (naap[k] != null) k
    ];
    final half = (present.length + 1) ~/ 2;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(42),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text((house?.isNotEmpty == true ? house! : 'NAAP').toUpperCase(),
              style: label()),
          pw.SizedBox(height: 6),
          pw.Text('Measurement Specification',
              style: pw.TextStyle(
                  font: pw.Font.timesItalic(), fontSize: 26, color: ink)),
          pw.SizedBox(height: 2),
          pw.Text(
              '${profile.name.isEmpty ? 'Client' : profile.name} · '
              '${DateFormat('d MMMM yyyy').format(DateTime.now())} · '
              'stature ${(profile.heightCm).toStringAsFixed(0)} cm',
              style: pw.TextStyle(
                  font: pw.Font.helvetica(), fontSize: 9, color: stone)),
          pw.SizedBox(height: 18),
          if (sizeCells.isNotEmpty)
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
              child: pw.Row(
                  children: [
                for (var i = 0; i < sizeCells.length; i++)
                  pw.Expanded(
                    child: pw.Container(
                      padding:
                          const pw.EdgeInsets.symmetric(vertical: 10),
                      decoration: i == 0
                          ? null
                          : const pw.BoxDecoration(
                              border: pw.Border(
                                  left: pw.BorderSide(
                                      color: PdfColor.fromInt(0xFFDCD8D0),
                                      width: .5))),
                      child: pw.Column(children: [
                        pw.Text(sizeCells[i].$1, style: label()),
                        pw.SizedBox(height: 3),
                        pw.Text(sizeCells[i].$2,
                            style: pw.TextStyle(
                                font: pw.Font.timesBold(), fontSize: 19)),
                      ]),
                    ),
                  ),
              ]),
            ),
          if (su != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
                'vs nominal EU block: chest '
                '${su.chestDeltaCm >= 0 ? '+' : ''}${su.chestDeltaCm} · '
                'waist ${su.waistDeltaCm >= 0 ? '+' : ''}${su.waistDeltaCm} · '
                'seat ${su.hipDeltaCm >= 0 ? '+' : ''}${su.hipDeltaCm} cm',
                style: pw.TextStyle(
                    font: pw.Font.helvetica(), fontSize: 8.5, color: stone)),
          ],
          pw.SizedBox(height: 16),
          pw.Text('BODY MEASUREMENTS', style: label()),
          pw.SizedBox(height: 6),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                child: pw.Column(children: [
              colHead(),
              for (final k in present.take(half))
                row(kMeasurementDefs[k]!.english, naap[k]!.cm),
            ])),
            pw.SizedBox(width: 28),
            pw.Expanded(
                child: pw.Column(children: [
              colHead(),
              for (final k in present.skip(half))
                row(kMeasurementDefs[k]!.english, naap[k]!.cm),
            ])),
          ]),
          if (su != null && su.notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('FIGURATION NOTES', style: label()),
            pw.SizedBox(height: 4),
            for (final n in su.notes)
              pw.Text('- $n',
                  style: pw.TextStyle(
                      font: pw.Font.helvetica(), fontSize: 9)),
          ],
          if (postureSummary != null && postureSummary.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('- Posture: $postureSummary',
                style:
                    pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9)),
          ],
          pw.Spacer(),
          pw.Text(
              'Measured on-device with the client\'s consent. No photograph '
              'ever left the client\'s phone. Format naap-spec-v1.',
              style: pw.TextStyle(
                  font: pw.Font.helvetica(), fontSize: 7.5, color: stone)),
        ],
      ),
    ));
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/atelier_spec_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
