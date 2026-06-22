import '../../models/promo_banner_model.dart';

/// يعيد ترتيب قائمة البانرات بعد سحب وإفلات ReorderableListView.
List<PromoBannerModel> reorderBannersList(
  List<PromoBannerModel> banners,
  int oldIndex,
  int newIndex, {
  bool newIndexPreAdjusted = false,
}) {
  if (banners.isEmpty) return const [];
  if (oldIndex < 0 ||
      oldIndex >= banners.length ||
      newIndex < 0 ||
      newIndex > banners.length) {
    return List<PromoBannerModel>.from(banners);
  }

  var targetIndex = newIndex;
  if (!newIndexPreAdjusted && targetIndex > oldIndex) {
    targetIndex -= 1;
  }

  final reordered = List<PromoBannerModel>.from(banners);
  final item = reordered.removeAt(oldIndex);
  reordered.insert(targetIndex, item);
  return reordered;
}

/// يبني قائمة sort_order جديدة (0..n) حسب ترتيب القائمة.
List<int> sortOrdersForBannerList(List<PromoBannerModel> banners) {
  return List<int>.generate(banners.length, (index) => index);
}
