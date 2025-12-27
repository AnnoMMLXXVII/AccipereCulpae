enum EntryPrefKey {
  keepDate,
  keepSource,
  keepCategory,
  keepQuantity,
  keepDescription,
  keepUnitPrice,
  keepBarcodeText,
  quickAddExpanded,
}

extension EntryPrefKeyStorage on EntryPrefKey {
  String get key => 'entry_pref_${name}';
}
