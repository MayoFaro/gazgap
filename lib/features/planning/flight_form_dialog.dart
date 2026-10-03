import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/helicos.dart';
import '../../data/flight.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

DateTime? _parseDate(String s) {
  try {
    return _dateFmt.parseStrict(s.trim());
  } catch (_) {
    return null;
  }
}

class FlightFormDialog extends StatefulWidget {
  const FlightFormDialog({super.key, this.initial});

  final Flight? initial;

  @override
  State<FlightFormDialog> createState() => _FlightFormDialogState();
}

class _FlightFormDialogState extends State<FlightFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late Helico _helico;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _duree;
  late final TextEditingController _destination;
  late final TextEditingController _remarque;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _helico = Helico.fromId(f?.helicoId) ?? Helico.h1;
    final start = f?.start ?? DateTime.now();
    _date = TextEditingController(text: _dateFmt.format(start));
    _time = TextEditingController(text: _fmtTime(start));
    _duree = TextEditingController(text: '${f?.dureeMinutes ?? 60}');
    _destination = TextEditingController(text: f?.destination ?? '');
    _remarque = TextEditingController(text: f?.remarque ?? '');
  }

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _duree.dispose();
    _destination.dispose();
    _remarque.dispose();
    super.dispose();
  }

  DateTime? _parseStart() {
    final d = _parseDate(_date.text);
    if (d == null) return null;
    final parts = _time.text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  Future<void> _pickDate() async {
    final start = _parseStart() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(start.year - 1),
      lastDate: DateTime(start.year + 2),
    );
    if (picked != null) setState(() => _date.text = _dateFmt.format(picked));
  }

  Future<void> _pickTime() async {
    final start = _parseStart() ?? DateTime.now();
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay(hour: start.hour, minute: start.minute));
    if (picked != null) {
      setState(() => _time.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final start = _parseStart();
    if (start == null) return;
    Navigator.of(context).pop(FlightDraft(
      helicoId: _helico.id,
      start: start,
      destination: _destination.text,
      remarque: _remarque.text,
      dureeMinutes: int.tryParse(_duree.text.trim()) ?? 60,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nouveau vol' : 'Modifier le vol'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Helico>(
                key: const Key('helico'),
                value: _helico,
                decoration: const InputDecoration(labelText: 'Hélico'),
                items: Helico.values
                    .map((h) => DropdownMenuItem(value: h, child: Text(h.label)))
                    .toList(),
                onChanged: (h) => setState(() => _helico = h!),
              ),
              TextFormField(
                key: const Key('date'),
                controller: _date,
                decoration: InputDecoration(
                  labelText: 'Date (jj/mm/aaaa)',
                  suffixIcon:
                      IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                validator: (v) => _parseDate(v ?? '') == null ? 'Date invalide' : null,
              ),
              TextFormField(
                key: const Key('time'),
                controller: _time,
                decoration: InputDecoration(
                  labelText: 'Heure (hh:mm)',
                  suffixIcon:
                      IconButton(icon: const Icon(Icons.access_time), onPressed: _pickTime),
                ),
                validator: (v) => _parseStart() == null ? 'Heure invalide' : null,
              ),
              TextFormField(
                key: const Key('duree'),
                controller: _duree,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Durée (minutes)'),
                validator: (v) =>
                    (int.tryParse(v?.trim() ?? '') ?? 0) > 0 ? null : 'Durée invalide',
              ),
              TextFormField(
                key: const Key('destination'),
                controller: _destination,
                decoration: const InputDecoration(labelText: 'Destination'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Destination requise' : null,
              ),
              TextFormField(
                key: const Key('remarque'),
                controller: _remarque,
                decoration: const InputDecoration(labelText: 'Remarque'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
