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
  });

  final String? title;
  final String? message;
  final Widget? content;
  final List<AppBottomSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: ColorSkin.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorSkin.grey3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 16),
                Text(
                  title!,
                  style: TypoSkin.title2.copyWith(color: ColorSkin.title),
                ),
              ],
              if (_buildContent() != null) ...[
                const SizedBox(height: 12),
                _buildContent()!,
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(context, actions[i]),
                      ),
                    ],
                  ],
                ),
              ],
              SizedBox(height: bottomPadding > 0 ? 0 : 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildContent() {
    if (content != null) return content;
    if (message == null) return null;
    return Text(
      message!,
      style: TypoSkin.bodyText2.copyWith(color: ColorSkin.subtitle),
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
    );
  }
}
