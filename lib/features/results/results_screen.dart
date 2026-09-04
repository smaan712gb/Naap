import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/app_version.dart';
import '../../core/ease.dart';
import '../../core/fabric.dart';
import '../../core/models/measurements.dart';
import '../../core/models/profile.dart';
import '../../core/parchi/parchi_pdf.dart';
import '../../core/parchi/reports_pdf.dart';
import '../../core/brand_fits.dart';
import '../../core/shop_api.dart';
import '../../core/silhouettes.dart';
import '../../core/sizing.dart';
import '../../core/styles.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _sharing = false;

  String _fmt(AppState s, double cm) => s.profile.unit == PreferredUnit.inches
      ? '${(cm / 2.54).toStringAsFixed(1)}″'
      : '${cm.toStringAsFixed(1)} cm';

  Future<void> _editValue(
      BuildContext context, AppState s, MeasurementDef def, double cm) async {
    final isInches = s.profile.unit == PreferredUnit.inches;
    final ctrl = TextEditingController(
        text: isInches
            ? (cm / 2.54).toStringAsFixed(1)
            : cm.toStringAsFixed(1));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${def.english} (${def.tailorTerm})'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(suffixText: isInches ? 'inches' : 'cm'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final d = double.tryParse(ctrl.text);
              if (d != null) {
                Navigator.pop(ctx, isInches ? d * 2.54 : d);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null) await s.editMeasurement(def.key, v);
  }

  Future<void> _shareParchi(AppState s, {bool direct = false}) async {
    // iOS requires an anchor rect for the share sheet ("sharePositionOrigin"
    // PlatformException without it); resolve it before any async gap.
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    setState(() => _sharing = true);
    try {
      final file = await ParchiPdf.build(
        profile: s.profile,
        naap: s.naap,
        garment: s.garment,
        fit: s.fit,
        fabric: s.fabric,
        style: s.style,
        silhouette: s.silhouette,
        measuredBy: s.shopName,
        bilingual: s.parchiBilingual,
        posture: s.active.posture,
      );
      final summary =
          'Naap parchi for ${s.profile.name} — ${kGarments[s.garment]!.english} '
          '(${s.fit.name} fit). Measurements attached as PDF. Sent from Naap.';
      if (direct && s.profile.tailorWhatsApp != null) {
        // Open the tailor's chat first so the share lands in the right place,
        // then hand the PDF to the share sheet.
        final num = s.profile.tailorWhatsApp!.replaceAll(RegExp(r'[^\d]'), '');
        final uri = Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(summary)}');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      // Parchi PDF + any design references the user attached, one bundle.
      await Share.shareXFiles(
          [
            XFile(file.path),
            for (final p in s.active.referencePaths)
              if (File(p).existsSync()) XFile(p),
          ],
          text: summary,
          sharePositionOrigin: shareOrigin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final lines = EaseEngine.buildParchi(s.naap, s.garment, s.fit,
        fabric: s.fabric, silhouette: s.silhouette);
    // All three fits side by side, so the fitted/regular/loose variation is
    // visible at a glance instead of only changing one number in place.
    final byFit = {
      for (final f in FitPreference.values)
        f: EaseEngine.buildParchi(s.naap, s.garment, f,
            fabric: s.fabric, silhouette: s.silhouette)
    };
    final isTrouserGarment = s.garment == GarmentType.suitTwoPiece ||
        s.garment == GarmentType.trousersShirt;
    String stitchRow(int i) {
      final fitted = byFit[FitPreference.fitted]![i].stitchCm;
      final regular = byFit[FitPreference.regular]![i].stitchCm;
      final loose = byFit[FitPreference.loose]![i].stitchCm;
      if (fitted == regular && regular == loose) {
        return 'Stitch ${_fmt(s, regular)} (all fits)';
      }
      String mark(FitPreference f, String label, double cm) =>
          s.fit == f ? '▶$label ${_fmt(s, cm)}' : '$label ${_fmt(s, cm)}';
      return '${mark(FitPreference.fitted, 'F', fitted)} · '
          '${mark(FitPreference.regular, 'R', regular)} · '
          '${mark(FitPreference.loose, 'L', loose)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.profile.name.isEmpty
            ? 'Your Naap'
            : '${s.profile.name} — Naap'),
        actions: [
          IconButton(
            tooltip: 'Tape check — darzi verification',
            icon: const Icon(Icons.straighten),
            onPressed: () => _showTapeCheck(context, s),
          ),
          if (s.active.history.length > 1)
            IconButton(
              tooltip: 'Naap history',
              icon: const Icon(Icons.history),
              onPressed: () => _showHistory(context, s),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Garment + fit pickers
          DropdownButtonFormField<GarmentType>(
            initialValue: s.garment,
            decoration: const InputDecoration(
                labelText: 'Garment', border: OutlineInputBorder()),
            items: [
              for (final g in kGarments.values)
                DropdownMenuItem(
                    value: g.type, child: Text('${g.english}  ${g.urdu}')),
            ],
            onChanged: (g) => g != null ? s.setGarment(g) : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FabricType?>(
            initialValue: s.fabric,
            decoration: const InputDecoration(
                labelText: 'Fabric (adjusts ease for stretch)',
                border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<FabricType?>(
                  value: null, child: Text('Not sure / default')),
              for (final f in kFabrics.values)
                DropdownMenuItem<FabricType?>(
                    value: f.type, child: Text('${f.english}  ${f.urdu}')),
            ],
            onChanged: (f) => s.setFabric(f),
          ),
          const SizedBox(height: 12),
          SegmentedButton<FitPreference>(
            segments: const [
              ButtonSegment(
                  value: FitPreference.fitted, label: Text('Fitted')),
              ButtonSegment(
                  value: FitPreference.regular, label: Text('Regular')),
              ButtonSegment(value: FitPreference.loose, label: Text('Loose')),
            ],
            selected: {s.fit},
            onSelectionChanged: (sel) => s.setFit(sel.first),
          ),
          if (isTrouserGarment) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<SilhouetteProfile>(
              initialValue: s.silhouette,
              decoration: const InputDecoration(
                  labelText: 'Trouser silhouette (trend layer)',
                  border: OutlineInputBorder()),
              items: [
                for (final d in kSilhouettes.values)
                  DropdownMenuItem(
                      value: d.profile,
                      child: Text('${d.english}  ${d.urdu}')),
              ],
              onChanged: (v) => v != null ? s.setSilhouette(v) : null,
            ),
          ],
          const SizedBox(height: 12),
          if (s.garment == GarmentType.shalwarKameez ||
              s.garment == GarmentType.kurtaPajama)
            _styleSection(context, s),
          const SizedBox(height: 16),
          Text('Tap any value to correct it — your edits are remembered.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),

          // Measurement rows
          Card(
            child: Column(children: [
              for (final (i, l) in lines.indexed)
                ListTile(
                  dense: true,
                  title: Row(children: [
                    Expanded(
                        child: Text('${l.def.english} (${l.def.tailorTerm})')),
                    Text(l.def.urdu,
                        style: const TextStyle(
                            fontSize: 15, color: Color(0xFF1B4D3E))),
                  ]),
                  subtitle: Text(
                      'Body ${_fmt(s, l.bodyCm)} → ${stitchRow(i)}'),
                  trailing: _sourceBadge(l.source, l.confidence),
                  onTap: () => _editValue(context, s, l.def, l.bodyCm),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          if (_sharing)
            const Center(child: CircularProgressIndicator())
          else ...[
            FilledButton.icon(
              onPressed: () => _shareParchi(s,
                  direct: s.profile.tailorWhatsApp != null),
              icon: const Icon(Icons.send),
              label: Text(s.profile.tailorWhatsApp != null
                  ? 'WhatsApp parchi to my tailor'
                  : 'Share parchi (PDF)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _shareParchi(s),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Share PDF anywhere'),
            ),
          ],
          const SizedBox(height: 16),
          _referencesCard(context, s),
          const SizedBox(height: 16),
          _fitReportCard(context, s),
          const SizedBox(height: 16),
          _sizeCard(context, s),
          const SizedBox(height: 8),
          _brandSizesCard(context, s),
          const SizedBox(height: 8),
          if (s.active.posture case final p?)
            Card(
              elevation: 0,
              color: const Color(0xFFE8F1EC),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.accessibility_new,
                    color: Color(0xFF1B4D3E)),
                title: const Text('Figuration (for your tailor)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${p.tailorSummary}\nAdvisory estimate — precise '
                    'posture arrives with 3D capture.'),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _shareSizePassport(s),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Share my Size Passport (PDF)'),
          ),
          if (s.garment == GarmentType.suitTwoPiece ||
              s.garment == GarmentType.trousersShirt ||
              s.garment == GarmentType.ladiesSuit) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _shareAtelierSpec(s),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Atelier Specification (EN, for MTM houses)'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _sendToAtelier(s),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send to atelier (request code)'),
          ),
          const SizedBox(height: 16),
          Text(
            'Estimates from on-device analysis. Values marked ~ are lower-confidence — '
            'verify with a tape for your first order, then Naap learns from your edits.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Naap over time: girths per scan, newest first, with deltas — the
  /// "watch your body change" retention loop.
  /// Darzi verification mode: enter tape-measured values next to the
  /// engine's estimates. Filled fields become (estimate, tape) calibration
  /// pairs — sent numbers-only to Naap — AND are applied as manual edits,
  /// so the parchi is corrected and per-user learning kicks in.
  Future<void> _showTapeCheck(BuildContext context, AppState s) async {
    final isInches = s.profile.unit == PreferredUnit.inches;
    final unit = isInches ? '″' : 'cm';
    final keys = [
      for (final k in kGarments[s.garment]!.keys)
        if (s.naap[k] != null) k
    ];
    final ctrls = {for (final k in keys) k: TextEditingController()};
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tape check — darzi verification',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                'Enter the tape measurement next to any value. Filled rows '
                'correct your naap and (numbers only, no name) help Naap '
                'calibrate for everyone.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final k in keys)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: ctrls[k],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          labelText:
                              '${kMeasurementDefs[k]!.english} (${kMeasurementDefs[k]!.tailorTerm})',
                          hintText:
                              'app: ${_fmt(s, s.naap[k]!.cm)} — tape $unit',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save tape values')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final pairs = <({String key, double estimateCm, double tapeCm})>[];
    for (final k in keys) {
      final raw = double.tryParse(ctrls[k]!.text.trim());
      if (raw == null || raw <= 0) continue;
      final tapeCm = isInches ? raw * 2.54 : raw;
      pairs.add((key: k.name, estimateCm: s.naap[k]!.cm, tapeCm: tapeCm));
    }
    if (pairs.isEmpty) return;

    // Tape wins locally: manual edits + per-user calibration learning.
    for (final p in pairs) {
      final key = keys.firstWhere((k) => k.name == p.key);
      await s.editMeasurement(key, p.tapeCm);
    }
    // Best-effort upload of the anonymous pairs; offline is fine.
    try {
      await ShopApi.submitCalibrationPairs(
        pairs: pairs,
        heightCm: s.profile.heightCm,
        gender: s.profile.bodyType.name,
        appBuild: kNaapBuild,
      );
    } catch (_) {/* pairs still applied locally */}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${pairs.length} tape values saved — naap '
              'updated, shukriya!')));
    }
  }

  /// Measure-request loop: the client types the atelier's 6-character
  /// code, sees WHO is asking, and consents before any number leaves the
  /// phone. Numbers only — no photos, no address (product law).
  Future<void> _sendToAtelier(AppState s) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to atelier'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Request code from your atelier',
              hintText: 'e.g. 4F09A1',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Look up')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;

    try {
      final req = await ShopApi.fetchMeasureRequest(code);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Send to ${req.atelier}?'),
          content: Text(
              '${req.note != null ? '"${req.note}"\n\n' : ''}'
              'Your measurement NUMBERS (never photos, never your address) '
              'will be sent to ${req.atelier} for this request. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send numbers')),
          ],
        ),
      );
      if (ok != true) return;

      final measurements = <String, double>{
        for (final k in MeasurementKey.values)
          if (s.naap[k] != null) k.name: s.naap[k]!.cm,
      };
      await ShopApi.submitSpecToAtelier(
        code: code,
        clientLabel: s.profile.name.isEmpty
            ? 'Client'
            : s.profile.name.split(' ').first,
        measurementsCm: measurements,
        heightCm: s.profile.heightCm,
        gender: s.profile.bodyType.name,
        posture: s.active.posture?.tailorSummary,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Measurements sent to ${req.atelier} — done!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
  }

  /// The Western-atelier document: cutting-ticket idiom, EU size/drop
  /// headline, cm body truth + block deltas, white-labeled with the
  /// device's shop name when set. No bazaar vocabulary, no QR.
  Future<void> _shareAtelierSpec(AppState s) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      final file = await AtelierSpec.buildAtelierSpec(
        profile: s.profile,
        naap: s.naap,
        house: s.shopName,
        postureSummary: s.active.posture?.tailorSummary,
      );
      await Share.shareXFiles([XFile(file.path)],
          text: 'Measurement Specification (naap-spec-v1).',
          sharePositionOrigin: origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  void _showHistory(BuildContext context, AppState s) {
    final entries = s.active.history;
    const keys = [
      MeasurementKey.chest,
      MeasurementKey.waist,
      MeasurementKey.hip,
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('Naap history — ناپ کی تاریخ',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          if (entries.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareDriftReport(s);
                },
                icon: const Icon(Icons.trending_up),
                label: const Text(
                    'Share Body Drift Report for your tailor (PDF)'),
              ),
            ),
          for (var i = 0; i < entries.length; i++)
            Card(
              elevation: 0,
              color: i == 0 ? const Color(0xFFE8F1EC) : null,
              child: ListTile(
                dense: true,
                title: Text(
                    '${entries[i].date.toLocal().toString().substring(0, 16)}'
                    '${i == 0 ? '  · current' : ''}'),
                subtitle: Text([
                  for (final k in keys)
                    if (entries[i].naap[k] != null)
                      '${kMeasurementDefs[k]!.tailorTerm} '
                          '${_fmt(s, entries[i].naap[k]!.cm)}'
                          '${i + 1 < entries.length && entries[i + 1].naap[k] != null ? ' (${(entries[i].naap[k]!.cm - entries[i + 1].naap[k]!.cm) >= 0 ? '+' : ''}${((entries[i].naap[k]!.cm - entries[i + 1].naap[k]!.cm) / (s.profile.unit == PreferredUnit.inches ? 2.54 : 1)).toStringAsFixed(1)})' : ''}'
                ].join('  ·  ')),
              ),
            ),
        ],
      ),
    );
  }

  /// International size card, gendered correctly: women get EU/IT/FR/UK/US
  /// ready-to-wear conversions, men get EU suiting + drop + US suit size.
  /// Per-BRAND accuracy comes later from the fit library — these are the
  /// standard conventions, computed on-device.
  Widget _sizeCard(BuildContext context, AppState s) {
    Widget card(String title, List<String> notes, String caption) => Card(
          color: const Color(0xFFF7F1E1),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.public, color: Color(0xFFC9A227)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15))),
                ]),
                const SizedBox(height: 4),
                Text(
                  '$caption Computed on your phone — nothing was uploaded.'
                  '${notes.isNotEmpty ? '\n• ${notes.join('\n• ')}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );

    if (s.profile.bodyType == BodyType.female) {
      final ls = mapLadiesSizes(s.naap);
      if (ls == null) return const SizedBox.shrink();
      return card(
          'Your sizes: EU ${ls.eu} · IT ${ls.it} · FR ${ls.fr} · '
              'UK ${ls.uk} · US ${ls.us}',
          ls.notes,
          'For off-the-rack ready-to-wear.');
    }
    final sm = mapSuMisura(s.naap);
    if (sm == null) return const SizedBox.shrink();
    return card(
        'Your suit size: EU ${sm.euSize} / US ${sm.euSize - 10} · '
            'Drop ${sm.drop}',
        sm.notes,
        'For off-the-rack suits and jackets.');
  }

  /// Per-brand sizes — chart/reputation starting points, refined by the
  /// fit library as reports arrive. Honest labeling built in.
  Widget _brandSizesCard(BuildContext context, AppState s) {
    final advice = brandAdvice(s.naap,
        female: s.profile.bodyType == BodyType.female);
    if (advice.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.storefront),
        title: const Text('Your size across brands (beta)'),
        subtitle: const Text(
            'From published charts & fit reputation — refined as real '
            'fit reports come in'),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final a in advice)
            ListTile(
              dense: true,
              title: Text(a.brand),
              subtitle: Text(a.note,
                  style: const TextStyle(fontSize: 11.5)),
              trailing: Text(a.size,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B4D3E))),
            ),
        ],
      ),
    );
  }

  /// The mainstream artifact: shareable one-page international size card.
  Future<void> _shareSizePassport(AppState s) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      final file = await ReportsPdf.buildSizePassport(
          profile: s.profile, naap: s.naap);
      await Share.shareXFiles([XFile(file.path)],
          text: 'My measured sizes — Naap Size Passport. getnaap.com',
          sharePositionOrigin: origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share passport: $e')));
      }
    }
  }

  /// The bespoke-house artifact: baseline vs latest scan with deltas.
  Future<void> _shareDriftReport(AppState s) async {
    final h = s.active.history;
    if (h.length < 2) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      final file = await ReportsPdf.buildDriftReport(
          profile: s.profile, baseline: h.last, latest: h.first);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Body drift report for my tailor — Naap. getnaap.com',
          sharePositionOrigin: origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share report: $e')));
      }
    }
  }

  /// Design/fabric reference photos (Imran's request: tailors often ask
  /// for pictures). User-picked from the gallery only — capture photos
  /// are deleted by law and can never appear here; the parchi PDF stays
  /// numbers-only, references travel as separate files in the share.
  Widget _referencesCard(BuildContext context, AppState s) {
    final refs = s.active.referencePaths;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.image_outlined),
        title: const Text('Design references (تصویریں) for your tailor'),
        subtitle: Text(refs.isEmpty
            ? 'Attach photos of a design or fabric you like — sent with the parchi'
            : '${refs.length} photo(s) will be sent with the parchi'),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in refs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(p),
                            width: 84, height: 84, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                width: 84,
                                height: 84,
                                child: Icon(Icons.broken_image))),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => s.removeReference(p),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ),
                if (refs.length < 6)
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1600,
                          imageQuality: 85);
                      if (picked != null) await s.addReference(picked.path);
                    },
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(84, 84)),
                    child: const Icon(Icons.add_photo_alternate_outlined),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Only photos you choose here are shared. Your measurement '
              'photos are always deleted and never attached.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  bool _fitReportSent = false;

  /// Phase 2 fit-library flywheel: one optional question after a scan.
  /// Anonymous — brand + size + verdict + this body's chest/waist numbers.
  Widget _fitReportCard(BuildContext context, AppState s) {
    if (_fitReportSent) {
      return Card(
        color: const Color(0xFFE8F1EC),
        elevation: 0,
        child: const ListTile(
            leading: Icon(Icons.check_circle, color: Color(0xFF1B4D3E)),
            title: Text('Shukriya! That helps Naap size every brand.')),
      );
    }
    final brandCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    String verdict = 'true-to-size';
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.checkroom_outlined),
        title: const Text('Help Naap learn brand sizes (optional)'),
        subtitle: const Text(
            'e.g. "I wear EU 50 in ZEGNA" — anonymous, numbers only'),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Brand',
                        hintText: 'ZEGNA, BOSS, Khaadi…',
                        border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            SizedBox(
                width: 110,
                child: TextField(
                    controller: sizeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Size',
                        hintText: '50 / M / 40R',
                        border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (ctx, setLocal) => Column(children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'runs-small', label: Text('Small')),
                  ButtonSegment(
                      value: 'true-to-size', label: Text('True to size')),
                  ButtonSegment(value: 'runs-large', label: Text('Large')),
                ],
                selected: {verdict},
                onSelectionChanged: (sel) =>
                    setLocal(() => verdict = sel.first),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () async {
                  final brand = brandCtrl.text.trim();
                  final size = sizeCtrl.text.trim();
                  if (brand.isEmpty || size.isEmpty) return;
                  try {
                    await ShopApi.submitFitReport(
                      brand: brand,
                      sizeLabel: size,
                      fitVerdict: verdict,
                      bodyChestCm: s.naap[MeasurementKey.chest]?.cm,
                      bodyWaistCm: s.naap[MeasurementKey.waist]?.cm,
                    );
                  } catch (_) {/* best effort */}
                  if (mounted) setState(() => _fitReportSent = true);
                },
                child: const Text('Send'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _styleSection(BuildContext context, AppState s) {
    final st = s.style;
    final isInches = s.profile.unit == PreferredUnit.inches;
    Future<void> editLength(String title, double? currentCm,
        void Function(double?) apply) async {
      final ctrl = TextEditingController(
          text: currentCm == null
              ? ''
              : (isInches
                  ? (currentCm / 2.54).toStringAsFixed(1)
                  : currentCm.toStringAsFixed(1)));
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                suffixText: isInches ? 'inches' : 'cm',
                helperText: 'Leave empty to let the tailor decide'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      );
      if (saved == true) {
        final d = double.tryParse(ctrl.text);
        apply(d == null ? null : (isInches ? d * 2.54 : d));
        await s.setStyle(st);
      }
    }

    String lenLabel(double? cm) => cm == null
        ? 'tailor decides'
        : (isInches
            ? '${(cm / 2.54).toStringAsFixed(1)}″'
            : '${cm.toStringAsFixed(1)} cm');

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.design_services),
        title: const Text('Style options (کٹائی)'),
        subtitle: Text(
            '${kNecklineLabels[st.neckline]!.english} · '
            '${kSleeveLabels[st.sleeve]!.english} · '
            '${kDamanLabels[st.daman]!.english}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          DropdownButtonFormField<NecklineStyle>(
            initialValue: st.neckline,
            decoration: const InputDecoration(
                labelText: 'Neckline (گلا)', border: OutlineInputBorder()),
            items: [
              for (final e in kNecklineLabels.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.value.english}  ${e.value.urdu}')),
            ],
            onChanged: (v) async {
              if (v != null) {
                st.neckline = v;
                await s.setStyle(st);
              }
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => editLength('Front neck depth (گلے کی گہرائی)',
                    st.neckDepthCm, (v) => st.neckDepthCm = v),
                child: Text('Neck depth: ${lenLabel(st.neckDepthCm)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => editLength('Neck width (گلے کی چوڑائی)',
                    st.neckWidthCm, (v) => st.neckWidthCm = v),
                child: Text('Neck width: ${lenLabel(st.neckWidthCm)}'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<SleeveStyle>(
            initialValue: st.sleeve,
            decoration: const InputDecoration(
                labelText: 'Sleeve (آستین)', border: OutlineInputBorder()),
            items: [
              for (final e in kSleeveLabels.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.value.english}  ${e.value.urdu}')),
            ],
            onChanged: (v) async {
              if (v != null) {
                st.sleeve = v;
                await s.setStyle(st);
              }
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<DamanStyle>(
            initialValue: st.daman,
            decoration: const InputDecoration(
                labelText: 'Daman (دامن)', border: OutlineInputBorder()),
            items: [
              for (final e in kDamanLabels.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.value.english}  ${e.value.urdu}')),
            ],
            onChanged: (v) async {
              if (v != null) {
                st.daman = v;
                await s.setStyle(st);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Side pockets (سائیڈ جیب)'),
            value: st.sidePockets,
            onChanged: (v) async {
              st.sidePockets = v;
              await s.setStyle(st);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chest pocket (سینے کی جیب)'),
            value: st.chestPocket,
            onChanged: (v) async {
              st.chestPocket = v;
              await s.setStyle(st);
            },
          ),
        ],
      ),
    );
  }

  Widget _sourceBadge(MeasurementSource src, double confidence) {
    // A bounded/contaminated AI value drops to the "verify with tape" badge
    // rather than presenting as a confident measurement.
    final (label, color) = switch (src) {
      MeasurementSource.landmarks ||
      MeasurementSource.silhouette when confidence < 0.5 =>
        ('~', Colors.orange),
      MeasurementSource.landmarks => ('AI', const Color(0xFF1B4D3E)),
      MeasurementSource.silhouette => ('AI', const Color(0xFF1B4D3E)),
      MeasurementSource.regression => ('~', Colors.orange),
      MeasurementSource.manual => ('✎', Colors.blueGrey),
    };
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
