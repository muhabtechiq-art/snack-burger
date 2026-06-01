/// استثناء حفظ المنتج برسالة مفهومة للمستخدم.
class ProductFormSaveException implements Exception {
  const ProductFormSaveException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}
