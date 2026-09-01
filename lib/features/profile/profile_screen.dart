import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _heightFt;
  late final TextEditingController _heightIn;
  late final TextEditingController _heightCm;
  late final TextEditingController _weight;
  late final TextEditingController _tailor;
  late BodyType _bodyType;
  late PreferredUnit _unit;
  bool _useFtIn = true;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _name = TextEditingController(text: p.name);
    final totalIn = p.heightCm / 2.54;
    _heightFt = TextEditingController(text: (totalIn ~/ 12).toString());
    _heightIn =
        TextEditingController(text: (totalIn % 12).toStringAsFixed(0));
    _heightCm =
        TextEditingController(text: p.heightCm.toStringAsFixed(0));
    _weight = TextEditingController(
        text: p.weightKg?.toStringAsFixed(0) ?? '');
    _tailor = TextEditingController(text: p.tailorWhatsApp ?? '');
    _bodyType = p.bodyType;
    _unit = p.unit;
  }

  @override
  void dispose() {
    for (final c in [_name, _heightFt, _heightIn, _heightCm, _weight, _tailor]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _heightCmValue {
    if (_useFtIn) {
      final ft = int.tryParse(_heightFt.text);
      final inch = double.tryParse(_heightIn.text) ?? 0;
      if (ft == null) return null;
      return (ft * 12 + inch) * 2.54;
    }
    return double.tryParse(_heightCm.text);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final h = _heightCmValue!;
    final p = UserProfile(
      name: _name.text.trim(),
      heightCm: h,
      weightKg: double.tryParse(_weight.text),
      bodyType: _bodyType,
      unit: _unit,
      tailorWhatsApp:
          _tailor.text.trim().isEmpty ? null : _tailor.text.trim(),
    );
    await context.read<AppState>().saveProfile(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Height', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('ft/in')),
                  ButtonSegment(value: false, label: Text('cm')),
                ],
                selected: {_useFtIn},
                onSelectionChanged: (s) =>
                    setState(() => _useFtIn = s.first),
              ),
            ]),
            const SizedBox(height: 10),
            if (_useFtIn)
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightFt,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Feet', border: OutlineInputBorder()),
                    validator: (_) => _heightCmValue == null ||
                            _heightCmValue! < 100 ||
                            _heightCmValue! > 230
                        ? 'Enter a valid height'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightIn,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Inches', border: OutlineInputBorder()),
                  ),
                ),
              ])
            else
              TextFormField(
                controller: _heightCm,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Height (cm)', border: OutlineInputBorder()),
                validator: (_) => _heightCmValue == null ||
                        _heightCmValue! < 100 ||
                        _heightCmValue! > 230
                    ? 'Enter a valid height'
                    : null,
              ),
            const SizedBox(height: 6),
            Text(
              'Height is what the camera calibrates against — measure it accurately once.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Weight (kg, optional — improves estimates)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SegmentedButton<BodyType>(
              segments: const [
                ButtonSegment(value: BodyType.male, label: Text('Male')),
                ButtonSegment(value: BodyType.female, label: Text('Female')),
              ],
              selected: {_bodyType},
              onSelectionChanged: (s) => setState(() => _bodyType = s.first),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PreferredUnit>(
              segments: const [
                ButtonSegment(
                    value: PreferredUnit.inches,
                    label: Text('Parchi in inches')),
                ButtonSegment(
                    value: PreferredUnit.cm, label: Text('Parchi in cm')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tailor,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Tailor's WhatsApp (optional)",
                hintText: '+92 300 1234567',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
