import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/core/skin/typo_skin.dart';
import 'package:test_y_app/features/overview/overview_date_range.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_action.dart';

class OverviewDateRangeBottomSheet extends StatefulWidget {
  const OverviewDateRangeBottomSheet({super.key, required this.initialRange});

  final DateTimeRange initialRange;

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTimeRange initialRange,
  }) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OverviewDateRangeBottomSheet(initialRange: initialRange),
    );
  }

  @override
  State<OverviewDateRangeBottomSheet> createState() =>
      _OverviewDateRangeBottomSheetState();
}

class _OverviewDateRangeBottomSheetState
    extends State<OverviewDateRangeBottomSheet> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _rangeStart = _dateOnly(widget.initialRange.start);
    _rangeEnd = _dateOnly(widget.initialRange.end);
    _focusedDay = _rangeEnd ?? _rangeStart ?? DateTime.now();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool get _canConfirm => _rangeStart != null && _rangeEnd != null;

  DateTimeRange? get _selectedRange {
    if (_rangeStart == null || _rangeEnd == null) return null;
    return DateTimeRange(start: _rangeStart!, end: _rangeEnd!);
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
    });
  }

  void _confirm() {
    final range = _selectedRange;
    if (range == null) return;
    Navigator.of(context).pop(range);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _selectedRange == null
        ? 'Chọn ngày bắt đầu và kết thúc'
        : formatOverviewDateRange(_selectedRange!.start, _selectedRange!.end);
    final today = _dateOnly(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AppBottomSheet(
        title: 'Chọn khoảng thời gian',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview,
              textAlign: TextAlign.center,
              style: TypoSkin.bodyText2.copyWith(
                color: _canConfirm ? ColorSkin.title : ColorSkin.subtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TableCalendar<void>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: today,
              focusedDay: _focusedDay.isAfter(today) ? today : _focusedDay,
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              rangeSelectionMode: RangeSelectionMode.enforced,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'vi_VN',
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TypoSkin.bodyText1.copyWith(
                  color: ColorSkin.title,
                  fontWeight: FontWeight.w700,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: ColorSkin.primary,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: ColorSkin.primary,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TypoSkin.bodyText2.copyWith(
                  fontSize: 12,
                  color: ColorSkin.subtitle,
                  fontWeight: FontWeight.w600,
                ),
                weekendStyle: TypoSkin.bodyText2.copyWith(
                  fontSize: 12,
                  color: ColorSkin.subtitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: ColorSkin.tealLight,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: ColorSkin.primarySub,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  color: ColorSkin.primary,
                  shape: BoxShape.circle,
                ),
                rangeHighlightColor: ColorSkin.tealLight,
                rangeStartDecoration: const BoxDecoration(
                  color: ColorSkin.primary,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: const BoxDecoration(
                  color: ColorSkin.primary,
                  shape: BoxShape.circle,
                ),
                withinRangeTextStyle: const TextStyle(
                  color: ColorSkin.primarySub,
                  fontWeight: FontWeight.w600,
                ),
                defaultTextStyle: TypoSkin.bodyText2.copyWith(
                  color: ColorSkin.title,
                ),
                weekendTextStyle: TypoSkin.bodyText2.copyWith(
                  color: ColorSkin.title,
                ),
                disabledTextStyle: TypoSkin.bodyText2.copyWith(
                  color: ColorSkin.subtitle.withValues(alpha: 0.45),
                ),
              ),
              onRangeSelected: _onRangeSelected,
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              enabledDayPredicate: (day) => !_dateOnly(day).isAfter(today),
            ),
          ],
        ),
        actions: [
          AppBottomSheetAction(
            label: 'Huỷ',
            returnValue: null,
          ),
          AppBottomSheetAction(
            label: 'Đồng ý',
            style: AppBottomSheetActionStyle.primary,
            dismissOnTap: false,
            onPressed: _canConfirm ? _confirm : null,
          ),
        ],
      ),
    );
  }
}
