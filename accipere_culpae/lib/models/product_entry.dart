class Product {
  final String id;
  final String name;
  final String brand;
  final String category;

  const Product({required this.id, required this.name, required this.brand, required this.category});

  String getCategory() {
    return (category.contains(":") ? category.split(":")[1] : category).trim();
  }

  String toString() {
    return '$id | $name | $brand | ' + this.getCategory();
  }
}
