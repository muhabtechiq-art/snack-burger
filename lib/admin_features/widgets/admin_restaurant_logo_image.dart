import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../shell/admin_panel_colors.dart';

enum _AdminLogoSource { asset, network, icon }

/// شعار المطعم للوحة الإدارة — أصل محلي أولاً، ثم شبكة، ثم أيقونة.
class AdminRestaurantLogoImage extends StatefulWidget {
  const AdminRestaurantLogoImage({
    super.key,
    required this.size,
    this.logoUrl,
    this.iconSize,
    this.debugTag,
  });

  final double size;
  final String? logoUrl;
  final double? iconSize;
  final String? debugTag;

  @override
  State<AdminRestaurantLogoImage> createState() =>
      _AdminRestaurantLogoImageState();
}

class _AdminRestaurantLogoImageState extends State<AdminRestaurantLogoImage> {
  late _AdminLogoSource _source;

  @override
  void initState() {
    super.initState();
    _source = _initialSource(widget.logoUrl);
  }

  @override
  void didUpdateWidget(covariant AdminRestaurantLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _source = _initialSource(widget.logoUrl);
    }
  }

  static _AdminLogoSource _initialSource(String? logoUrl) {
    if (_isValidNetworkLogoUrl(logoUrl)) {
      return _AdminLogoSource.network;
    }
    return _AdminLogoSource.asset;
  }

  static bool _isValidNetworkLogoUrl(String? value) {
    if (value == null) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  void _fallbackFrom(_AdminLogoSource failed) {
    if (!mounted) return;
    setState(() {
      switch (failed) {
        case _AdminLogoSource.network:
          _source = _AdminLogoSource.asset;
        case _AdminLogoSource.asset:
          _source = _AdminLogoSource.icon;
        case _AdminLogoSource.icon:
          break;
      }
    });
  }

  void _logLoadFailure(String source, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[${widget.debugTag ?? 'AdminRestaurantLogo'}] $source logo failed: $error',
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_source) {
      case _AdminLogoSource.network:
        return Image.network(
          widget.logoUrl!.trim(),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            _logLoadFailure('network', error);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fallbackFrom(_AdminLogoSource.network);
            });
            return _loadingPlaceholder();
          },
        );
      case _AdminLogoSource.asset:
        return Image.asset(
          AppAssets.menuLogo,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            _logLoadFailure('asset', error);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fallbackFrom(_AdminLogoSource.asset);
            });
            return _loadingPlaceholder();
          },
        );
      case _AdminLogoSource.icon:
        final resolvedIconSize = widget.iconSize ?? (widget.size * 0.5);
        return Icon(
          Icons.restaurant_rounded,
          size: resolvedIconSize,
          color: AdminPanelColors.charcoal.withValues(alpha: 0.65),
        );
    }
  }

  Widget _loadingPlaceholder() {
    return SizedBox(width: widget.size, height: widget.size);
  }
}
