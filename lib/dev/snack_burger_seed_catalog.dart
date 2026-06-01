/// عنصر إضافة في بيانات التعبئة.
class SeedAddon {
  const SeedAddon({required this.name, required this.price});

  final String name;
  final double price;
}

/// منتج جاهز للتعبئة في Supabase.
class SeedProduct {
  const SeedProduct({
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.addons = const [],
  });

  final String name;
  final double price;
  final String description;
  final String category;
  final String imageUrl;
  final List<SeedAddon> addons;
}

/// 50 منتجاً متنوعاً لمطعم Snack Burger.
const List<SeedProduct> snackBurgerSeedCatalog = [
  // برجر (12)
  SeedProduct(
    name: 'برجر لحم كلاسيك',
    price: 5000,
    description: 'شريحة لحم مشوية مع جبنة شيدر وخضار طازج',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-01/640/480',
    addons: [
      SeedAddon(name: 'جبنة إضافية', price: 1000),
      SeedAddon(name: 'صوص خاص', price: 500),
    ],
  ),
  SeedProduct(
    name: 'برجر دبل تشيز',
    price: 7000,
    description: 'شريحتان لحم مع مضاعفة جبنة الشيدر',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-02/640/480',
    addons: [
      SeedAddon(name: 'لحم إضافي', price: 2500),
      SeedAddon(name: 'مخلل حار', price: 500),
    ],
  ),
  SeedProduct(
    name: 'برجر دجاج مقرمش',
    price: 4500,
    description: 'صدر دجاج مقرمش مع صوص المايونيز والخس',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-03/640/480',
    addons: [
      SeedAddon(name: 'جبنة', price: 1000),
      SeedAddon(name: 'بطاطا إضافية', price: 1500),
    ],
  ),
  SeedProduct(
    name: 'برجر مشوي عالفحم',
    price: 5500,
    description: 'لحم بقري بنكهة الفحم مع صوص باربكيو',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-04/640/480',
    addons: [
      SeedAddon(name: 'صوص باربكيو', price: 500),
      SeedAddon(name: 'بصل مقرمش', price: 750),
    ],
  ),
  SeedProduct(
    name: 'برجر سبايسي',
    price: 5000,
    description: 'خلطة حارة مع الهلابينو وصوص الشطة',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-05/640/480',
    addons: [
      SeedAddon(name: 'جبنة حارة', price: 1000),
      SeedAddon(name: 'هلابينو', price: 500),
    ],
  ),
  SeedProduct(
    name: 'ميني برجر بوكس',
    price: 6500,
    description: '3 قطع برجر صغيرة متنوعة',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-06/640/480',
    addons: [SeedAddon(name: 'صوصات مشكلة', price: 500)],
  ),
  SeedProduct(
    name: 'برجر مشروم سويس',
    price: 6000,
    description: 'لحم مع فطر مشوي وجبنة سويسرية',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-07/640/480',
    addons: [
      SeedAddon(name: 'فطر إضافي', price: 1000),
      SeedAddon(name: 'جبنة سويس', price: 1000),
    ],
  ),
  SeedProduct(
    name: 'برجر باربكيو بيكون',
    price: 6200,
    description: 'لحم مع بيكون مدخن وصوص باربكيو حلو',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-08/640/480',
    addons: [
      SeedAddon(name: 'بيكون إضافي', price: 1500),
      SeedAddon(name: 'جبنة مدخنة', price: 1000),
    ],
  ),
  SeedProduct(
    name: 'برجر نباتي',
    price: 4800,
    description: 'باتي نباتي مشوي مع خضار موسمية',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-09/640/480',
    addons: [
      SeedAddon(name: 'أفوكادو', price: 1000),
      SeedAddon(name: 'جبنة نباتية', price: 1000),
    ],
  ),
  SeedProduct(
    name: 'برجر لحم غنم',
    price: 5800,
    description: 'لحم غنم متبل على الطريقة العراقية',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-10/640/480',
    addons: [
      SeedAddon(name: 'طرشي', price: 500),
      SeedAddon(name: 'عمبة', price: 500),
    ],
  ),
  SeedProduct(
    name: 'برجر فيلادلفيا',
    price: 5900,
    description: 'لحم مع فلفل وبصل وجبنة فيلادلفيا',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-11/640/480',
    addons: [SeedAddon(name: 'جبنة كريمية', price: 1000)],
  ),
  SeedProduct(
    name: 'برجر كريسبي تشيكن',
    price: 4700,
    description: 'دجاج مقرمش بالتوابل الخاصة',
    category: 'برجر',
    imageUrl: 'https://picsum.photos/seed/sb-burger-12/640/480',
    addons: [
      SeedAddon(name: 'صوص رانش', price: 500),
      SeedAddon(name: 'جبنة', price: 1000),
    ],
  ),

  // بيتزا (10)
  SeedProduct(
    name: 'بيتزا مارغريتا',
    price: 5000,
    description: 'صلصة طماطم إيطالية مع جبنة موزاريلا',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-01/640/480',
    addons: [
      SeedAddon(name: 'زيتون', price: 750),
      SeedAddon(name: 'ريحان', price: 500),
    ],
  ),
  SeedProduct(
    name: 'بيتزا لحم مفروم',
    price: 7500,
    description: 'لحم متبل مع فلفل أخضر وزيتون',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-02/640/480',
    addons: [
      SeedAddon(name: 'لحم إضافي', price: 2000),
      SeedAddon(name: 'جبنة مضاعفة', price: 1500),
    ],
  ),
  SeedProduct(
    name: 'بيتزا دجاج باربكيو',
    price: 8000,
    description: 'قطع دجاج مشوي مع صوص باربكيو',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-03/640/480',
    addons: [
      SeedAddon(name: 'دجاج إضافي', price: 2000),
      SeedAddon(name: 'بصل أحمر', price: 500),
    ],
  ),
  SeedProduct(
    name: 'بيتزا خضروات',
    price: 6000,
    description: 'فطر، زيتون، فلفل، طماطم، وذرة',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-04/640/480',
    addons: [SeedAddon(name: 'جبنة إضافية', price: 1500)],
  ),
  SeedProduct(
    name: 'بيتزا بيبروني',
    price: 8500,
    description: 'شرائح بيبروني مع موزاريلا سائحة',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-05/640/480',
    addons: [
      SeedAddon(name: 'بيبروني إضافي', price: 2000),
      SeedAddon(name: 'فلفل حار', price: 500),
    ],
  ),
  SeedProduct(
    name: 'بيتزا عشاق الجبنة',
    price: 9000,
    description: 'مزيج من 4 أنواع أجبان',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-06/640/480',
    addons: [SeedAddon(name: 'جبنة خام خامسة', price: 1500)],
  ),
  SeedProduct(
    name: 'بيتزا تونة',
    price: 7200,
    description: 'تونة طازجة مع بصل وذرة',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-07/640/480',
    addons: [SeedAddon(name: 'تونة إضافية', price: 1500)],
  ),
  SeedProduct(
    name: 'بيتزا سوبر سوبريم',
    price: 9500,
    description: 'لحم، دجاج، فلفل، فطر، وزيتون',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-08/640/480',
    addons: [
      SeedAddon(name: 'حجم كبير', price: 2000),
      SeedAddon(name: 'جبنة إضافية', price: 1500),
    ],
  ),
  SeedProduct(
    name: 'بيتزا ثلاث أجبان',
    price: 7800,
    description: 'موزاريلا، شيدر، وبارميزان',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-09/640/480',
    addons: [SeedAddon(name: 'عسل الكمأة', price: 1000)],
  ),
  SeedProduct(
    name: 'بيتزا سموكد سالمون',
    price: 9800,
    description: 'سلمون مدخن مع كريمة وشبت',
    category: 'بيتزا',
    imageUrl: 'https://picsum.photos/seed/sb-pizza-10/640/480',
    addons: [SeedAddon(name: 'سلمون إضافي', price: 2500)],
  ),

  // شاورما (8)
  SeedProduct(
    name: 'لفة شاورما لحم',
    price: 3000,
    description: 'شاورما لحم عراقية مع طرشي وعمبة',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-01/640/480',
    addons: [
      SeedAddon(name: 'ثومية', price: 500),
      SeedAddon(name: 'بطاطا', price: 1000),
    ],
  ),
  SeedProduct(
    name: 'شاورما دجاج صاج',
    price: 2500,
    description: 'خبز صاج مقرمش مع ثومية',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-02/640/480',
    addons: [
      SeedAddon(name: 'جبنة', price: 750),
      SeedAddon(name: 'صوص حار', price: 500),
    ],
  ),
  SeedProduct(
    name: 'وجبة شاورما عربي',
    price: 6000,
    description: 'شاورما مع بطاطا ومقبلات وببسي',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-03/640/480',
    addons: [SeedAddon(name: 'حمص إضافي', price: 750)],
  ),
  SeedProduct(
    name: 'صاج شاورما دبل',
    price: 5000,
    description: 'حجم عائلي مشبع باللحم والجبن',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-04/640/480',
    addons: [
      SeedAddon(name: 'لحم إضافي', price: 2000),
      SeedAddon(name: 'جبنة', price: 1000),
    ],
  ),
  SeedProduct(
    name: 'شاورما ميكس',
    price: 7000,
    description: 'لحم ودجاج مع صوصات متنوعة',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-05/640/480',
    addons: [
      SeedAddon(name: 'صوصات إضافية', price: 500),
      SeedAddon(name: 'مخلل', price: 500),
    ],
  ),
  SeedProduct(
    name: 'فتة شاورما دجاج',
    price: 5500,
    description: 'أرز متبل مع شاورما وخبز مقرمش',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-06/640/480',
    addons: [SeedAddon(name: 'لبن بالنعناع', price: 500)],
  ),
  SeedProduct(
    name: 'طبق شاورما لحم',
    price: 8500,
    description: '250غ لحم مع أرز أو بطاطا',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-07/640/480',
    addons: [
      SeedAddon(name: 'أرز إضافي', price: 1500),
      SeedAddon(name: 'سلطة', price: 750),
    ],
  ),
  SeedProduct(
    name: 'ساندويتش شاورما سريع',
    price: 3500,
    description: 'خبز فرنسي مع شاورما وخضار',
    category: 'شاورما',
    imageUrl: 'https://picsum.photos/seed/sb-shawarma-08/640/480',
    addons: [SeedAddon(name: 'جبنة ذائبة', price: 1000)],
  ),

  // مقبلات (10)
  SeedProduct(
    name: 'بطاطا مقرمشة',
    price: 2000,
    description: 'أصابع بطاطا ذهبية مع بهارات',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-01/640/480',
    addons: [
      SeedAddon(name: 'صوص جبنة', price: 750),
      SeedAddon(name: 'حجم كبير', price: 1000),
    ],
  ),
  SeedProduct(
    name: 'حلقات بصل',
    price: 2500,
    description: '10 قطع حلقات بصل مقرمشة',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-02/640/480',
    addons: [SeedAddon(name: 'صوص رانش', price: 500)],
  ),
  SeedProduct(
    name: 'أصابع موزاريلا',
    price: 3500,
    description: '6 أصابع جبن مقرمشة مع صوص',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-03/640/480',
    addons: [SeedAddon(name: 'صوص مارينارا', price: 500)],
  ),
  SeedProduct(
    name: 'مقبلات مشكلة',
    price: 4000,
    description: 'حمص، متبل، بابا غنوج، وتبولة',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-04/640/480',
    addons: [SeedAddon(name: 'خبز إضافي', price: 500)],
  ),
  SeedProduct(
    name: 'سلطة سيزر',
    price: 4500,
    description: 'خس مع دجاج مشوي وخبز محمص',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-05/640/480',
    addons: [
      SeedAddon(name: 'دجاج إضافي', price: 1500),
      SeedAddon(name: 'بارميزان', price: 750),
    ],
  ),
  SeedProduct(
    name: 'كبة حلبية',
    price: 3000,
    description: '4 قطع كبة محشية باللحم',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-06/640/480',
    addons: [SeedAddon(name: 'لبن', price: 500)],
  ),
  SeedProduct(
    name: 'أجنحة دجاج',
    price: 4200,
    description: '8 قطع أجنحة بصوص باربكيو',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-07/640/480',
    addons: [
      SeedAddon(name: 'صوص حار', price: 500),
      SeedAddon(name: '4 قطع إضافية', price: 2000),
    ],
  ),
  SeedProduct(
    name: 'ناجتس دجاج',
    price: 3800,
    description: '8 قطع ناجتس مقرمشة',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-08/640/480',
    addons: [SeedAddon(name: 'صوص عسل وخردل', price: 500)],
  ),
  SeedProduct(
    name: 'بطاطا بالجبنة',
    price: 3200,
    description: 'بطاطا مقلية مع جبنة ذائبة',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-09/640/480',
    addons: [
      SeedAddon(name: 'بيكون', price: 1000),
      SeedAddon(name: 'كريمة حامضة', price: 500),
    ],
  ),
  SeedProduct(
    name: 'سمبوسة لحم',
    price: 2800,
    description: '6 قطع سمبوسة محشية',
    category: 'مقبلات',
    imageUrl: 'https://picsum.photos/seed/sb-app-10/640/480',
    addons: [SeedAddon(name: 'صوص حار', price: 500)],
  ),

  // مشروبات (10)
  SeedProduct(
    name: 'عصير برتقال فريش',
    price: 2500,
    description: 'عصير طبيعي طازج ومبرد',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-01/640/480',
    addons: [SeedAddon(name: 'ثلج إضافي', price: 0)],
  ),
  SeedProduct(
    name: 'ببسي',
    price: 1000,
    description: 'علبة ببسي غازية مثلجة',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-02/640/480',
    addons: [SeedAddon(name: 'حجم كبير', price: 500)],
  ),
  SeedProduct(
    name: 'سفن أب',
    price: 1000,
    description: 'علبة سفن أب منعشة',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-03/640/480',
    addons: [SeedAddon(name: 'ليمون', price: 250)],
  ),
  SeedProduct(
    name: 'ميرندا برتقال',
    price: 1000,
    description: 'مشروب غازي بنكهة البرتقال',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-04/640/480',
    addons: [SeedAddon(name: 'ثلج', price: 0)],
  ),
  SeedProduct(
    name: 'كوكتيل فواكه',
    price: 3500,
    description: 'موز وفراولة ومانgo مع حليب',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-05/640/480',
    addons: [SeedAddon(name: 'عسل', price: 500)],
  ),
  SeedProduct(
    name: 'ماء معدني',
    price: 500,
    description: 'قنينة 500 مل',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-06/640/480',
    addons: [SeedAddon(name: 'غازي', price: 250)],
  ),
  SeedProduct(
    name: 'شاي ليمون',
    price: 1500,
    description: 'شاي أسود بالليمون والنعناع',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-07/640/480',
    addons: [SeedAddon(name: 'عسل', price: 500)],
  ),
  SeedProduct(
    name: 'قهوة أمريكانو',
    price: 2000,
    description: 'قهوة سوداء قوية',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-08/640/480',
    addons: [
      SeedAddon(name: 'حليب', price: 500),
      SeedAddon(name: 'ثلج', price: 250),
    ],
  ),
  SeedProduct(
    name: 'موكا بالشوكولاتة',
    price: 3200,
    description: 'قهوة مع شوكولاتة وحليب',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-09/640/480',
    addons: [SeedAddon(name: 'كريمة', price: 750)],
  ),
  SeedProduct(
    name: 'عصير ليمون بالنعناع',
    price: 2200,
    description: 'ليمونade منعشة',
    category: 'مشروبات',
    imageUrl: 'https://picsum.photos/seed/sb-drink-10/640/480',
    addons: [SeedAddon(name: 'نعناع إضافي', price: 250)],
  ),
];
