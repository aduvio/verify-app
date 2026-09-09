import 'package:flutter/material.dart';

Future<List<String>?> requestReasons(
  BuildContext context,
  String title,
  List<String> labels, {
  String? requiredConfirmation,
  bool allowBlockingRecheck = false,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _ReasonDialog(
    title: title,
    labels: labels,
    requiredConfirmation: requiredConfirmation,
    allowBlockingRecheck: allowBlockingRecheck,
  ),
);

class _ReasonDialog extends StatefulWidget {
  final String title;
  final List<String> labels;
  final String? requiredConfirmation;
  final bool allowBlockingRecheck;
  const _ReasonDialog({
    required this.title,
    required this.labels,
    this.requiredConfirmation,
    this.allowBlockingRecheck = false,
  });
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final controllers = widget.labels
      .map((_) => TextEditingController())
      .toList();
  final form = GlobalKey<FormState>();
  bool confirmed = false;
  bool savingBlockingRecheck = false;
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: controllers[i],
                  maxLines: 2,
                  decoration: InputDecoration(labelText: widget.labels[i]),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ),
            if (widget.requiredConfirmation != null)
              FormField<bool>(
                validator: (_) => confirmed || savingBlockingRecheck
                    ? null
                    : widget.allowBlockingRecheck
                    ? 'Confirm a successful recheck before clearing this concern.'
                    : 'Confirm this determination before saving.',
                builder: (field) => Column(
                  children: [
                    CheckboxListTile(
                      value: confirmed,
                      onChanged: (value) => setState(() {
                        confirmed = value ?? false;
                        field.didChange(confirmed);
                      }),
                      title: Text(widget.requiredConfirmation!),
                    ),
                    if (field.hasError)
                      Text(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      if (widget.allowBlockingRecheck)
        TextButton(
          onPressed: () {
            savingBlockingRecheck = true;
            if (form.currentState!.validate()) {
              Navigator.pop(context, [
                ...controllers.map((c) => c.text.trim()),
                'false',
              ]);
            }
            savingBlockingRecheck = false;
          },
          child: const Text('SAVE FAILED / INCOMPLETE RECHECK'),
        ),
      FilledButton(
        onPressed: () {
          savingBlockingRecheck = false;
          if (form.currentState!.validate()) {
            Navigator.pop(context, [
              ...controllers.map((c) => c.text.trim()),
              if (widget.allowBlockingRecheck) 'true',
            ]);
          }
        },
        child: const Text('SAVE'),
      ),
    ],
  );
}
