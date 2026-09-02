import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/ease.dart';
import '../../core/fabric.dart';
import '../../core/models/measurements.dart';
import '../../core/models/profile.dart';
import '../../core/parchi/parchi_pdf.dart';
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
      await Share.shareXFiles([XFile(file.path)],
          text: summary, sharePositionOrigin: shareOrigin);
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
    final lines =
        EaseEngine.buildParchi(s.naap, s.garment, s.fit, fabric: s.fabric);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Naap')),
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
              for (final l in lines)
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
                      'Body ${_fmt(s, l.bodyCm)} → Stitch ${_fmt(s, l.stitchCm)}'),
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
          if (mapSuMisura(s.naap) case final sm?)
            Card(
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
                      Text('European size: EU ${sm.euSize}, Drop ${sm.drop}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'For off-the-rack suits and jackets. Computed on your '
                      'phone — nothing was uploaded.'
                      '${sm.notes.isNotEmpty ? '\n• ${sm.notes.join('\n• ')}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
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
