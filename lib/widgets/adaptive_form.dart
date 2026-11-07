import 'package:flutter/material.dart';

/// Ouvre un formulaire en plein écran sur mobile, ou en boîte de dialogue sur grand écran.
Future<T?> showAdaptiveForm<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) body,
  required Widget Function(BuildContext) actions,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (!wide) {
    return Navigator.of(context).push<T>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: body(ctx)),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: actions(ctx)),
          ]),
        ),
      ),
    ));
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
            child: Row(children: [
              Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleLarge)),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 8), child: body(ctx)),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 20), child: actions(ctx)),
        ]),
      ),
    ),
  );
}

/// Champ date en lecture seule ouvrant le sélecteur.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.format,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String Function(DateTime) format;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(1970),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          suffixIcon: clearable && value != null
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => onChanged(null))
              : null,
        ),
        child: Text(value == null ? 'Non renseignée' : format(value!)),
      ),
    );
  }
}
