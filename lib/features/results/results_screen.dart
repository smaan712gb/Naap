import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/ease.dart';
import '../../core/models/measurements.dart';
import '../../core/models/profile.dart';
import '../../core/parchi/parchi_pdf.dart';

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
    setState(() => _sharing = true);
    try {
      final file = await ParchiPdf.build(
        profile: s.profile,
        naap: s.naap,
        garment: s.garment,
        fit: s.fit,
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
      await Share.shareXFiles([XFile(file.path)], text: summary);
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
    final lines = EaseEngine.buildParchi(s.naap, s.garment, s.fit);

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
                  trailing: _sourceBadge(l.source),
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
          const SizedBox(height: 24),
          Text(
            'Estimates from on-device analysis. Values marked ~ are lower-confidence — '
            'verify with a tape for your first order, then Naap learns from your edits.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _sourceBadge(MeasurementSource src) {
    final (label, color) = switch (src) {
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
