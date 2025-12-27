class TransactionEntry {
  final DateTime date;
  final String description;
  final int quantity;
  final double unitPrice;
  final String source;
  final String category;
  final String? barcodeText;

  const TransactionEntry({
    required this.date,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.source,
    required this.category,
    this.barcodeText,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        "date": date.toIso8601String(),
        "description": description,
        "quantity": quantity,
        "unitPrice": double.parse(unitPrice.toStringAsFixed(2)),
        "source": source,
        "category": category,
        "barcodeText": (barcodeText?.trim().isEmpty ?? true) ? null : barcodeText!.trim(),
        "total": double.parse(total.toStringAsFixed(2)),
      };
}
