import 'package:flutter/material.dart';
import '../data/history_fields.dart';
import '../data/history_repository.dart';

typedef Validator = String? Function(String? value);

class HistoryAutocompleteField extends StatelessWidget {
  const HistoryAutocompleteField({
    super.key,
    required this.repo,
    required this.field,
    required this.label,
    this.hintText,
    required this.controller,
    this.validator,
    this.maxOptions = 8,
    this.textInputAction,
    this.keyboardType,
  });

  final HistoryRepository repo;
  final HistoryField field;
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final Validator? validator;
  final int maxOptions;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue tv) {
        final typed = tv.text.trim();
        final suggestions = repo.suggest(field, typed, limit: maxOptions);

        if (typed.isNotEmpty) {
          final exists = suggestions.any(
            (s) => s.toLowerCase() == typed.toLowerCase(),
          );
          return [if (!exists) 'Use: $typed', ...suggestions];
        }
        return suggestions;
      },
      onSelected: (selection) {
        final v = selection.startsWith('Use: ')
            ? selection.substring(5)
            : selection;
        controller.text = v;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: v.length),
        );
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        textCtrl.value = controller.value;

        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: InputDecoration(labelText: label, hintText: hintText),
          validator: validator,
          onChanged: (_) => controller.value = textCtrl.value,
        );
      },
      optionsViewBuilder: (context, onSelected, opts) {
        final scheme = Theme.of(context).colorScheme;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 520),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final o = opts.elementAt(i);
                  final isUse = o.startsWith('Use: ');
                  final text = isUse ? o.substring(5) : o;

                  return ListTile(
                    dense: true,
                    leading: Icon(isUse ? Icons.add : Icons.history),
                    title: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
