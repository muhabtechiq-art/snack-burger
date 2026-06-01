import '../../models/product_model.dart';

/// مؤقت: `true` لعرض 30 منتجاً وهمياً؛ `false` لجلب المنتجات الحقيقية من Firestore.
const kUseMockMenuProducts = false;

final DateTime _mockCreatedAt = DateTime(2024, 6, 1);

ProductModel _mockProduct({
  required String id,
  required String name,
  required String description,
  required double price,
  required String category,
}) {
  return ProductModel(
    id: id,
    name: name,
    description: description,
    price: price,
    category: category,
    restaurantId: 'snack_burger',
    createdAt: _mockCreatedAt,
  );
}

/// بيانات تجريبية لاختبار التصميم والسكرول (30 منتجاً).
final List<ProductModel> mockMenuProducts = [
  // قسم البرجر
  _mockProduct(id: 'b1', name: 'برجر لحم كلاسيك', description: 'شريحة لحم مشوية مع جبنة شيدر وخضار طازج', price: 5000, category: 'برجر'),
  _mockProduct(id: 'b2', name: 'برجر دبل تشيز', description: 'شريحتين لحم مع مضاعفة جبنة الشيدر السائحة', price: 7000, category: 'برجر'),
  _mockProduct(id: 'b3', name: 'برجر دجاج مقرمش', description: 'صدر دجاج مقرمش مع صوص المايونيز والخس', price: 4500, category: 'برجر'),
  _mockProduct(id: 'b4', name: 'برجر مشوي عالفحم', description: 'لحم بقري بنكهة الفحم الحقيقي مع صوص باربكيو', price: 5500, category: 'برجر'),
  _mockProduct(id: 'b5', name: 'برجر سبايسي Zblock', description: 'خلطة حارة جداً مع الهلابينو وصوص الشطة الحارة', price: 5000, category: 'برجر'),
  _mockProduct(id: 'b6', name: 'ميني برجر بوكس', description: '3 قطع برجر صغيرة متنوعة (لحم ودجاج)', price: 6500, category: 'برجر'),
  // قسم البيتزا
  _mockProduct(id: 'p1', name: 'بيتزا مارغريتا', description: 'صلصة طماطم إيطالية مع جبنة الموزاريلا الفاخرة', price: 5000, category: 'بيتزا'),
  _mockProduct(id: 'p2', name: 'بيتزا لحم مفروم وسط', description: 'قطع لحم متبلة مع الفلفل الأخضر والزيتون', price: 7500, category: 'بيتزا'),
  _mockProduct(id: 'p3', name: 'بيتزا دجاج باربكيو', description: 'قطع دجاج مشوي مع صوص الباربكيو المدخن', price: 8000, category: 'بيتزا'),
  _mockProduct(id: 'p4', name: 'بيتزا خضروات مشكلة', description: 'فطر، زيتون، فلفل بارد، طماطم، وذرة', price: 6000, category: 'بيتزا'),
  _mockProduct(id: 'p5', name: 'بيتزا بيبروني فخم', description: 'شرائح البيبروني البقري مع غرق موزاريلا', price: 8500, category: 'بيتزا'),
  _mockProduct(id: 'p6', name: 'بيتزا عشاق الجبنة', description: 'مزيج من 4 أنواع أجبان فاخرة وسائحة', price: 9000, category: 'بيتزا'),
  // قسم الشاورما
  _mockProduct(id: 's1', name: 'لفات شاورما لحم غنم', description: 'شاورما لحم على الطريقة العراقية مع الطرشي والعمبة', price: 3000, category: 'شاورما'),
  _mockProduct(id: 's2', name: 'شاورما دجاج صاج', description: 'خبز صاج مقرمش مع الثومية والبطاطا', price: 2500, category: 'شاورما'),
  _mockProduct(id: 's3', name: 'وجبة شاورما عربي دبل', description: 'قطع شاورما مقطعة مع بطاطا ومقبلات وثومية وببسي', price: 6000, category: 'شاورما'),
  _mockProduct(id: 's4', name: 'صاج شاورما لحم دبل', description: 'حجم عائلي مشبع جداً مليء باللحم والجبن', price: 5000, category: 'شاورما'),
  _mockProduct(id: 's5', name: 'شاورما ميكس بوكس', description: 'قطع شاورما لحم ودجاج مع تشكيلة صوصات غنية', price: 7000, category: 'شاورما'),
  _mockProduct(id: 's6', name: 'فتة شاورما دجاج', description: 'أرز متبل مع قطع الشاورما والخبز المقرمش واللبن', price: 5500, category: 'شاورما'),
  // قسم المقبلات
  _mockProduct(id: 'm1', name: 'صحن بطاطا مقرمشة', description: 'أصابع بطاطا ذهبية مع بهارات البابريكا اللذيذة', price: 2000, category: 'مقبلات'),
  _mockProduct(id: 'm2', name: 'حلقات البصل المقلي', description: '10 قطع من حلقات البصل المقرمشة مع صوص جانبي', price: 2500, category: 'مقبلات'),
  _mockProduct(id: 'm3', name: 'أصابع الموزاريلا', description: 'أصابع جبن مغطاة بالبقسماط ومقلية ومطاطية جداً', price: 3500, category: 'مقبلات'),
  _mockProduct(id: 'm4', name: 'صحن مقبلات مشكل وسط', description: 'حمص، متبل، بابا غنوج، وتبولة فريش', price: 4000, category: 'مقبلات'),
  _mockProduct(id: 'm5', name: 'سلطة سيزر بالدجاج', description: 'خس، قطع دجاج مشوي، خبز محمص، وصوص سيزر', price: 4500, category: 'مقبلات'),
  _mockProduct(id: 'm6', name: 'كبة برغل حلبية', description: '4 قطع كبة محشية باللحم المفروم والمكسرات', price: 3000, category: 'مقبلات'),
  // قسم المشروبات
  _mockProduct(id: 'd1', name: 'عصير برتقال فريش', description: 'عصير طبيعي طازج ومبرد بدون سكر مضاف', price: 2500, category: 'مشروبات'),
  _mockProduct(id: 'd2', name: 'ببسي بارد', description: 'علبة ببسي غازية مثلجة', price: 1000, category: 'مشروبات'),
  _mockProduct(id: 'd3', name: 'سفن أب', description: 'علبة سفن أب منعشة ومثلجة', price: 1000, category: 'مشروبات'),
  _mockProduct(id: 'd4', name: 'ميرندا برتقال', description: 'مشروب غازي بنكهة البرتقال اللذيذة', price: 1000, category: 'مشروبات'),
  _mockProduct(id: 'd5', name: 'كوكتيل فواكه طبيعي', description: 'مزيج فواكه طبيعية موز وفراولة ومانجو مع الحليب', price: 3500, category: 'مشروبات'),
  _mockProduct(id: 'd6', name: 'ماء معدني مبرد', description: 'قنينة ماء نقي سعة 500 مل', price: 500, category: 'مشروبات'),
];
