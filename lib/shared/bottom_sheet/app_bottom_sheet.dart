import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_action.dart';
import 'package:test_y_app/shared/widgets/app_button.dart';

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    this.title,
    this.message,
    this.content,
    required this.actions,
    this.scrollableContent = true,
    this.maxHeightFactor = 0.85,
    this.showHandle = true,
    this.showCloseButton = false,
    this.onClose,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(20, 20, 20, 16),
  });

  final String? title;
  final String? message;
  final Widget? content;
  final List<AppBottomSheetAction> actions;

  /// When true, sheet hug-wraps content and scrolls if it exceeds
  /// [maxHeightFactor]. When false, sheet uses a fixed height so children
  /// can safely use [Expanded] (e.g. searchable lists).
  final bool scrollableContent;
  final double maxHeightFactor;
  final bool showHandle;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry actionsPadding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    final header = _buildHeader(context);
    final messageWidget = message == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              message!,
              style: TypoSkin.bodyText2.copyWith(color: ColorSkin.subtitle),
            ),
          );
    final actionsWidget = actions.isEmpty
        ? null
        : Padding(
            padding: actionsPadding,
            child: _AppBottomSheetActions(actions: actions),
          );

    final Widget sheet;
    if (scrollableContent) {
      // Shrink-wrap: do NOT place SingleChildScrollView inside Flexible —
      // that expands to maxHeight and leaves a huge empty gap.
      sheet = Material(
        color: ColorSkin.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?header,
                  ?messageWidget,
                  if (content != null)
                    Padding(padding: contentPadding, child: content!),
                  ?actionsWidget,
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      sheet = SizedBox(
        height: maxHeight,
        child: Material(
          color: ColorSkin.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                ?messageWidget,
                if (content != null)
                  Expanded(
                    child: Padding(padding: contentPadding, child: content!),
                  ),
                ?actionsWidget,
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: sheet,
    );
  }

  Widget? _buildHeader(BuildContext context) {
    if (!showHandle && title == null && !showCloseButton) return null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorSkin.grey3,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          if (title != null || showCloseButton) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      title ?? '',
                      textAlign: TextAlign.center,
                      style: TypoSkin.title2.copyWith(color: ColorSkin.title),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: showCloseButton
                          ? IconButton(
                              onPressed: onClose ??
                                  () => Navigator.of(context).maybePop(),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.close,
                                size: 20,
                                color: ColorSkin.subtitle,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppBottomSheetActions extends StatelessWidget {
  const _AppBottomSheetActions({required this.actions});

  final List<AppBottomSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) {
      return _buildActionButton(context, actions.first);
    }

    if (actions.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildActionButton(context, actions[0])),
          const SizedBox(width: 12),
          Expanded(child: _buildActionButton(context, actions[1])),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(context, actions[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, AppBottomSheetAction action) {
    void handleTap() {
      action.onPressed?.call();
      if (action.dismissOnTap) {
        Navigator.of(context).pop(action.returnValue);
      }
    }

    final variant = switch (action.style) {
      AppBottomSheetActionStyle.primary => AppButtonVariant.primary,
      AppBottomSheetActionStyle.destructive => AppButtonVariant.destructive,
      AppBottomSheetActionStyle.secondary => AppButtonVariant.outlined,
    };

    final enabled = action.onPressed != null || action.dismissOnTap;

    return AppButton(
      label: action.label,
      onPressed: enabled ? handleTap : null,
      variant: variant,
      expand: true,
    );
  }
}
