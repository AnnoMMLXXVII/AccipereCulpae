enum HistoryField {
  description,
  source,
  category,
  barcodeText,
}

extension HistoryFieldKey on HistoryField {
  String get key => 'history_${name}';
}
