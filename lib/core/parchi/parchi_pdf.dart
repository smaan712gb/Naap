/// The "Digital Parchi" — a bilingual (English/Urdu) PDF measurement slip a
/// user sends to their tailor on WhatsApp. Contains ONLY numbers and the
/// generic mannequin sketch. Never the user's photos.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ease.dart';
import '../fabric.dart';
import '../models/measurements.dart';
import '../models/profile.dart';
import '../styles.dart';

/// Simple generic mannequin sketch (front view) — the privacy-preserving
/// stand-in for the user's body on the parchi.
const String _mannequinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 300">
  <g fill="none" stroke="#1b4d3e" stroke-width="2.4" stroke-linecap="round">
    <circle cx="60" cy="26" r="15"/>
    <path d="M60 41 v10"/>
    <path d="M35 55 q25 -8 50 0 l6 60 q-5 4 -10 3 l-6 -38 v88 q0 6 -5 6 h-20 q-5 0 -5 -6 v-88 l-6 38 q-5 1 -10 -3 z"/>
    <path d="M48 174 l-3 96 q0 6 5 6 h4 q4 0 4 -6 l2 -70 l2 70 q0 6 4 6 h4 q5 0 5 -6 l-3 -96"/>
  </g>
</svg>
''';

class ParchiPdf {
  static pw.Font? _urduFont;
  static pw.Font? _latinFont;
  static pw.Font? _latinBold;

  static Future<void> _ensureFonts() async {
    if (_urduFont != null) return;
    final urduData =
        await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    _urduFont = pw.Font.ttf(urduData);
    _latinFont = pw.Font.helvetica();
    _latinBold = pw.Font.helveticaBold();
  }

  /// Builds the parchi PDF and returns the written file.
  static Future<File> build({
    required UserProfile profile,
    required Naap naap,
    required GarmentType garment,
    required FitPreference fit,
    FabricType? fabric,
    KameezStyle? style,
  }) async {
    await _ensureFonts();
    final lines = EaseEngine.buildParchi(naap, garment, fit, fabric: fabric);
    // All three fits appear on the parchi; the selected one is highlighted
    // as the cutting column, the others are reference for the tailor's
    // "kaisi fitting?" conversation.
    final byFit = {
      for (final f in FitPreference.values)
        f: EaseEngine.buildParchi(naap, garment, f, fabric: fabric)
    };
    final gdef = kGarments[garment]!;
    final fdef = fabric != null ? kFabrics[fabric] : null;
    final isInches = profile.unit == PreferredUnit.inches;
    final unitLabel = isInches ? 'in' : 'cm';
    final unitUrdu = isInches ? 'انچ' : 'سینٹی میٹر';
    String fmt(double cm) =>
        isInches ? (cm / 2.54).toStringAsFixed(1) : cm.toStringAsFixed(1);

    final doc = pw.Document(
      title: 'Naap Digital Parchi',
      producer: 'Naap',
    );

    pw.TextStyle en(double s, {bool bold = false}) => pw.TextStyle(
        font: bold ? _latinBold : _latinFont, fontSize: s);
    pw.TextStyle ur(double s) =>
        pw.TextStyle(font: _urduFont, fontSize: s);

    pw.Widget urduText(String s, {double size = 11}) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(s, style: ur(size)),
        );

    const brandGreen = PdfColor.fromInt(0xFF1B4D3E);
    const softGreen = PdfColor.fromInt(0xFFE8F1EC);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // ---- Header ----
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: brandGreen,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('NAAP — Digital Parchi',
                        style: en(18, bold: true)
                            .copyWith(color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Measurement slip · ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                        style:
                            en(10).copyWith(color: PdfColors.grey300)),
                  ],
                ),
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text('ڈیجیٹل ناپ پرچی',
                      style: ur(16).copyWith(color: PdfColors.white)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ---- Customer / garment strip ----
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(profile.name.isEmpty ? 'Customer' : profile.name,
                      style: en(13, bold: true)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                      '${gdef.english} · ${fit.name} fit'
                      '${fdef != null ? ' · ${fdef.english}' : ''} · units: $unitLabel',
                      style: en(10).copyWith(color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  urduText(gdef.urdu, size: 13),
                  pw.SizedBox(height: 2),
                  urduText('پیمائش: $unitUrdu', size: 9),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ---- Table + mannequin ----
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.TableHelper.fromTextArray(
                  headerDecoration: const pw.BoxDecoration(color: softGreen),
                  headerStyle: en(9, bold: true).copyWith(color: brandGreen),
                  cellStyle: en(9.5),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.6),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.0),
                    3: const pw.FlexColumnWidth(1.1),
                    4: const pw.FlexColumnWidth(1.1),
                    5: const pw.FlexColumnWidth(1.1),
                  },
                  headers: [
                    'Measurement ($unitLabel)',
                    'اردو',
                    'Body',
                    fit == FitPreference.fitted ? '» Fitted «' : 'Fitted',
                    fit == FitPreference.regular ? '» Regular «' : 'Regular',
                    fit == FitPreference.loose ? '» Loose «' : 'Loose',
                  ],
                  data: [
                    for (final (i, l) in lines.indexed)
                      [
                        '${l.def.english} (${l.def.tailorTerm})',
                        l.def.urdu,
                        fmt(l.bodyCm),
                        fmt(byFit[FitPreference.fitted]![i].stitchCm),
                        fmt(byFit[FitPreference.regular]![i].stitchCm),
                        fmt(byFit[FitPreference.loose]![i].stitchCm),
                      ],
                  ],
                  // Highlight the customer's chosen fit column — that is
                  // the cutting column; the others are reference.
                  cellDecoration: (int col, dynamic data, int rowNum) {
                    final selCol = 3 + FitPreference.values.indexOf(fit);
                    if (col == selCol) {
                      return const pw.BoxDecoration(color: softGreen);
                    }
                    return const pw.BoxDecoration();
                  },
                  cellBuilder: (int col, dynamic data, int rowNum) {
                    final selCol = 3 + FitPreference.values.indexOf(fit);
                    if (col == selCol) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 3, horizontal: 4),
                        child: pw.Text('$data',
                            style: en(9.5, bold: true)
                                .copyWith(color: brandGreen),
                            textAlign: pw.TextAlign.center),
                      );
                    }
                    if (col != 1) return null; // default rendering
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 3, horizontal: 4),
                      child: pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text('$data', style: ur(10)),
                      ),
                    );
                  },
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 1,
                child: pw.Column(children: [
                  pw.SvgImage(svg: _mannequinSvg, height: 180),
                  pw.SizedBox(height: 6),
                  pw.Text('Generic avatar — not a photo',
                      style: en(7).copyWith(color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // ---- Style section (kameez cut choices — not measurements) ----
          if (style != null &&
              (garment == GarmentType.shalwarKameez ||
                  garment == GarmentType.kurtaPajama)) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: brandGreen, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Style — کٹائی',
                            style: en(10, bold: true)
                                .copyWith(color: brandGreen)),
                      ]),
                  pw.SizedBox(height: 4),
                  for (final (enLine, urLine) in style.parchiLines(
                      isInches: profile.unit == PreferredUnit.inches))
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(child: pw.Text(enLine, style: en(9))),
                          pw.Directionality(
                            textDirection: pw.TextDirection.rtl,
                            child: pw.Text(urLine, style: ur(9)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],

          // ---- Notes ----
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: softGreen,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Notes for the tailor', style: en(10, bold: true)),
                pw.SizedBox(height: 3),
                pw.Text(
                    'Customer selected the »${fit.name.toUpperCase()}« column '
                    '(highlighted) — cut to it. All three columns already '
                    'include ease (asan)'
                    '${fdef != null ? ' for ${fdef.english}' : ''}; fitted/'
                    'regular/loose are shown so you can advise. Style numbers '
                    '(ghera, paincha, kameez length) are the customer\'s '
                    'preference and can be adjusted.',
                    style: en(9)),
                pw.SizedBox(height: 5),
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text(
                      'درزی کے لیے: گاہک نے نمایاں (سبز) والا خانہ منتخب کیا ہے — اسی کے مطابق کاٹیں۔ تینوں خانوں میں آسان شامل ہے۔ گھیرا، پائنچہ اور قمیض کی لمبائی گاہک کی پسند کے مطابق ہے۔',
                      style: ur(10)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated on-device by Naap (ناپ). No photos were uploaded — measurements only. getnaap.com',
              style: en(7.5).copyWith(color: PdfColors.grey600)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeName = profile.name.isEmpty
        ? 'naap'
        : profile.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
    final file = File(
        '${dir.path}/naap_parchi_${safeName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    final Uint8List bytes = await doc.save();
    await file.writeAsBytes(bytes);
    return file;
  }
}
