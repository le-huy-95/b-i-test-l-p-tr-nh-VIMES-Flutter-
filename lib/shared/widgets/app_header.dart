import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/shared/widgets/app_notification_bell.dart';

enum AppHeaderVariant {
  sidebar,
  detail,
  auth,
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  // ignore_for_file: prefer_const_constructors_in_immutables
  AppHeader({
    super.key,
    this.variant = AppHeaderVariant.detail,
    this.leading,
    this.title,
    this.actions,
    this.bottom,
    this.leadingWidth,
    this.titleSpacing,
    this.centerTitle,
    this.automaticallyImplyLeading,
    this.toolbarHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showNotificationAction = true,
    this.notificationTooltip = 'Thông báo',
    this.notificationRoute = '/notifications',
    this.titlePadding,
    this.titleOverflow = TextOverflow.ellipsis,
    this.onTitleTap,
  });

  final AppHeaderVariant variant;
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double? leadingWidth;
  final double? titleSpacing;
  final bool? centerTitle;
  final bool? automaticallyImplyLeading;
  final double? toolbarHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool showNotificationAction;
  final String notificationTooltip;
  final String notificationRoute;
  final EdgeInsetsGeometry? titlePadding;
  final TextOverflow titleOverflow;

  /// Xử lý khi người dùng ấn vào title của header.
  /// Nếu không truyền, mặc định: khi header hiển thị nút quay lại (back arrow)
  /// thì ấn vào title cũng quay lại trang trước giống hệt nút back.
  final VoidCallback? onTitleTap;

  double get _defaultToolbarHeight {
    return switch (variant) {
      AppHeaderVariant.sidebar => 72,
      AppHeaderVariant.auth => kToolbarHeight,
      AppHeaderVariant.detail => kToolbarHeight,
    };
  }

  double get _defaultLeadingWidth {
    return switch (variant) {
      AppHeaderVariant.sidebar => 64,
      AppHeaderVariant.auth => 56,
      AppHeaderVariant.detail => 56,
    };
  }

  bool get _defaultCenterTitle {
    return switch (variant) {
      AppHeaderVariant.sidebar => false,
      AppHeaderVariant.auth => false,
      AppHeaderVariant.detail => false,
    };
  }

  double get _defaultTitleSpacing {
    return switch (variant) {
      AppHeaderVariant.sidebar => 8,
      AppHeaderVariant.auth => 0,
      AppHeaderVariant.detail => 0,
    };
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight((toolbarHeight ?? _defaultToolbarHeight) + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = foregroundColor ?? ColorSkin.title;
    final effectiveTitleStyle = TextStyle(
      color: effectiveForeground,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    // Khi header sẽ hiển thị nút back mặc định, mặc định ấn title cũng back.
    final showsDefaultBackButton = leading == null &&
        automaticallyImplyLeading != false &&
        (ModalRoute.of(context)?.canPop ?? false);
    final effectiveTitleOnTap = onTitleTap ??
        (showsDefaultBackButton ? () => Navigator.of(context).maybePop() : null);
    final effectiveTitle = title == null
        ? null
        : Padding(
            padding: titlePadding ?? EdgeInsets.zero,
            child: _wrapTitleIfTappable(
              _truncatableTitle(title!, effectiveTitleStyle),
              effectiveTitleOnTap,
            ),
          );

    final resolvedActions = <Widget>[
      if (showNotificationAction) const AppNotificationBell(),
      if (actions != null) ...actions!,
    ];

    return AppBar(
      leading: leading,
      title: effectiveTitle,
      actions: resolvedActions,
      bottom: bottom,
      toolbarHeight: toolbarHeight ?? _defaultToolbarHeight,
      leadingWidth: leadingWidth ?? _defaultLeadingWidth,
      titleSpacing: titleSpacing ?? _defaultTitleSpacing,
      centerTitle: centerTitle ?? _defaultCenterTitle,
      automaticallyImplyLeading: automaticallyImplyLeading ?? true,
      backgroundColor: backgroundColor ?? ColorSkin.white,
      surfaceTintColor: backgroundColor ?? ColorSkin.white,
      shadowColor: Colors.transparent,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 0,
      foregroundColor: effectiveForeground,
      iconTheme: IconThemeData(color: effectiveForeground),
      actionsIconTheme: IconThemeData(color: effectiveForeground),
      titleTextStyle: effectiveTitleStyle,
    );
  }

  // Bọc title bằng InkWell để ấn vào title thực hiện hành động (ví dụ quay lại).
  Widget _wrapTitleIfTappable(Widget title, VoidCallback? onTap) {
    if (onTap == null) return title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: title,
    );
  }

  // Khoá tiêu đề trong vùng title của AppBar: text dài chỉ bị cắt với "..."
  // chứ không wrap xuống dòng gây đẩy các icon leading/actions.
  Widget _truncatableTitle(Widget title, TextStyle baseStyle) {
    Widget resolved = title;
    if (title is Text && title.data != null) {
      resolved = Text(
        title.data!,
        key: title.key,
        style: baseStyle.merge(title.style),
        textAlign: title.textAlign,
        textDirection: title.textDirection,
        locale: title.locale,
        softWrap: false,
        overflow: titleOverflow,
        maxLines: 1,
        textWidthBasis: title.textWidthBasis,
        textHeightBehavior: title.textHeightBehavior,
        textScaler: title.textScaler,
        selectionColor: title.selectionColor,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: resolved,
    );
  }
}
