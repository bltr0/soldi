import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'blur_widget.dart';

enum Period { month, year }

//This class can be used when we need to draw a line chart with one or two lines
class LineChartWidget extends StatefulWidget {
  final List<FlSpot> lineData; // this should be a list of Flspot(x,y)
  final Color? lineColor;

  final List<FlSpot> line2Data; // this should be a list of Flspot(x,y)
  final Color? line2Color;

  final bool enableGapFilling;

  // Used to decide the bottom label
  final Period period;
  final int? daysInMonth;
  final int currentMonthDays = DateUtils.getDaysInMonth(
    DateTime.now().year,
    DateTime.now().month,
  );

  int get axisDayCount => daysInMonth ?? currentMonthDays;
  final int nXLabel;
  final double minY;

  final Color? colorBackground;
  final bool ignoreBlur;
  final bool dashboardStyle;
  final double? height;

  LineChartWidget({
    super.key,
    required List<FlSpot> lineData,
    this.lineColor,
    List<FlSpot> line2Data = const [],
    this.line2Color,
    this.colorBackground,
    this.enableGapFilling = true,
    this.ignoreBlur = true,
    this.dashboardStyle = false,
    this.height,
    this.period = Period.month,
    this.daysInMonth,
    this.nXLabel = 10,
    double? minY,
  }) : lineData = enableGapFilling ? fillGaps(lineData) : lineData,
       line2Data = enableGapFilling ? fillGaps(line2Data) : line2Data,
       minY = minY ?? calculateMinY(lineData, line2Data);

  static double calculateMinY(List<FlSpot> line1Data, List<FlSpot> line2Data) {
    if (line1Data.isEmpty && line2Data.isEmpty) {
      return 0;
    }

    return [...line1Data, ...line2Data].map((e) => e.y).reduce(min);
  }

  static List<FlSpot> fillGaps(List<FlSpot> lineData) {
    if (lineData.isEmpty) return [];

    final sorted = List<FlSpot>.from(lineData)
      ..sort((a, b) => a.x.compareTo(b.x));
    final filledData = <FlSpot>[];
    final lastX = sorted.last.x.floor();

    for (var x = 0; x <= lastX; x++) {
      final exact = sorted.where((spot) => spot.x == x).firstOrNull;
      if (exact != null) {
        filledData.add(exact);
        continue;
      }

      final before = sorted.where((spot) => spot.x < x).lastOrNull;
      final after = sorted.where((spot) => spot.x > x).firstOrNull;
      if (before == null) {
        filledData.add(FlSpot(x.toDouble(), after?.y ?? sorted.first.y));
      } else if (after == null) {
        filledData.add(FlSpot(x.toDouble(), before.y));
      } else {
        final progress = (x - before.x) / (after.x - before.x);
        filledData.add(
          FlSpot(x.toDouble(), before.y + ((after.y - before.y) * progress)),
        );
      }
    }

    return filledData;
  }

  @override
  State<LineChartWidget> createState() => _LineChartSample2State();
}

class _LineChartSample2State extends State<LineChartWidget> {
  _LineChartSample2State();

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final chart = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.colorBackground ?? themeData.colorScheme.tertiary,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: widget.dashboardStyle ? Sizes.xs : Sizes.xl,
        ),
        child: Builder(
          builder: (context) {
            if (widget.lineData.length < 2 && widget.line2Data.length < 2) {
              return Center(
                child: Text(
                  "We are sorry but there is not\nenough data to make the graph...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.dashboardStyle
                        ? context.dashboardTheme.textSecondary
                        : Theme.of(context).hintColor,
                  ),
                ),
              );
            }
            return LineChart(
              mainData(),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: widget.dashboardStyle ? 160 : 220),
              curve: Curves.easeOutCubic,
            );
          },
        ),
      ),
    );
    final boundedChart = widget.dashboardStyle
        ? SizedBox(height: widget.height ?? 220, child: chart)
        : AspectRatio(aspectRatio: 2, child: chart);

    return BlurWidget(
      ignore: widget.ignoreBlur,
      replacement: SizedBox(
        height: widget.dashboardStyle ? widget.height ?? 220 : 180,
        child: const Center(child: Icon(Icons.visibility_off_outlined)),
      ),
      child: boundedChart,
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    final ThemeData themeData = Theme.of(context);
    Color lineColor = widget.lineColor ?? themeData.colorScheme.primary;
    final style = TextStyle(
      color: widget.dashboardStyle
          ? context.dashboardTheme.textSecondary
          : lineColor,
      fontWeight: FontWeight.normal,
      fontSize: widget.dashboardStyle ? 10 : 8,
    );
    Widget text;
    switch (widget.period) {
      case Period.year:
        switch (value.toInt()) {
          case 1:
            text = Text('Feb', style: style);
            break;
          case 2:
            text = Text('Mar', style: style);
            break;
          case 3:
            text = Text('Apr', style: style);
            break;
          case 4:
            text = Text('May', style: style);
            break;
          case 5:
            text = Text('Jun', style: style);
            break;
          case 6:
            text = Text('Jul', style: style);
            break;
          case 7:
            text = Text('Aug', style: style);
            break;
          case 8:
            text = Text('Sep', style: style);
            break;
          case 9:
            text = Text('Oct', style: style);
            break;
          case 10:
            text = Text('Nov', style: style);
            break;
          default:
            text = Text('', style: style);
            break;
        }
        break;
      case Period.month:
        int step = (widget.axisDayCount / widget.nXLabel).round();
        final day = value.toInt() + 1;
        final showDashboardLabel =
            day == 1 || day % step == 0 || day == widget.axisDayCount;
        if ((widget.dashboardStyle && showDashboardLabel) ||
            (!widget.dashboardStyle &&
                value.toInt() % step == 1 &&
                value.toInt() != widget.axisDayCount)) {
          text = Text((value + 1).toStringAsFixed(0), style: style);
        } else {
          text = Text('', style: style);
        }
    }

    return SideTitleWidget(meta: meta, child: text);
  }

  LineChartData mainData() {
    final ThemeData themeData = Theme.of(context);
    final visual = context.dashboardTheme;
    Color lineColor = widget.lineColor ?? themeData.colorScheme.primary;
    Color line2Color = widget.line2Color ?? themeData.disabledColor;

    return LineChartData(
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
      ),
      gridData: const FlGridData(show: false),
      lineTouchData: LineTouchData(
        getTouchedSpotIndicator:
            (LineChartBarData barData, List<int> spotIndexes) {
              bool allSameX = spotIndexes.toSet().length == 1;

              if (!allSameX) {
                return [];
              }
              return spotIndexes.map((spotIndex) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: widget.dashboardStyle
                        ? visual.textSecondary.withValues(alpha: 0.45)
                        : Colors.blueGrey,
                    strokeWidth: widget.dashboardStyle ? 1 : 2,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: widget.dashboardStyle ? 3 : 2,
                        color: widget.dashboardStyle
                            ? visual.raisedSurface
                            : Colors.grey,
                        strokeWidth: 2,
                        strokeColor: widget.dashboardStyle
                            ? barData.color ?? lineColor
                            : Colors.blueGrey,
                      );
                    },
                  ),
                );
              }).toList();
            },
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipBorderRadius: BorderRadius.circular(
            widget.dashboardStyle ? 14 : 4,
          ),
          tooltipBorder: widget.dashboardStyle
              ? BorderSide(color: visual.glassBorder)
              : BorderSide.none,
          getTooltipColor: (spot) => widget.dashboardStyle
              ? visual.raisedSurface
              : defaultLineTooltipColor(spot),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            if (touchedBarSpots.isEmpty) {
              return [];
            }

            return touchedBarSpots.map((spot) {
              final now = DateTime.now();
              final date = widget.period == Period.month
                  ? DateTime(
                      now.year,
                      now.month - spot.barIndex,
                      spot.x.toInt() + 1,
                    )
                  : DateTime(now.year, spot.x.toInt() + 1, 1);
              final dateLabel = widget.period == Period.month
                  ? DateFormat(DateFormat.ABBR_MONTH_DAY).format(date)
                  : DateFormat(DateFormat.ABBR_MONTH).format(date);
              final valueColor = spot.barIndex == 0 ? lineColor : line2Color;

              return LineTooltipItem(
                '$dateLabel\n',
                TextStyle(
                  color: widget.dashboardStyle
                      ? visual.textSecondary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                children: [
                  TextSpan(
                    text: spot.y.toStringAsFixed(2),
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),

      borderData: FlBorderData(
        show: !widget.dashboardStyle,
        border: widget.dashboardStyle
            ? Border.all(color: Colors.transparent)
            : const Border(
                bottom: BorderSide(
                  color: Colors.grey,
                  width: 1.0,
                  style: BorderStyle.solid,
                ),
              ),
      ),
      minX: 0,
      // if year display 12 month, if month display the number of days in it
      maxX: widget.period == Period.year ? 11 : widget.axisDayCount - 1,
      minY: widget.minY,
      lineBarsData: [
        LineChartBarData(
          spots: widget.lineData,
          isCurved: true,
          curveSmoothness: widget.dashboardStyle ? 0.22 : 0.15,
          preventCurveOverShooting: true,
          barWidth: widget.dashboardStyle ? 2.6 : 1.5,
          isStrokeCapRound: true,
          color: lineColor,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: widget.dashboardStyle
                ? null
                : lineColor.withValues(alpha: 0.2),
            gradient: widget.dashboardStyle
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      visual.chartFill,
                      visual.chartFill.withValues(alpha: 0),
                    ],
                  )
                : null,
          ),
        ),
        LineChartBarData(
          spots: widget.line2Data,
          isCurved: true,
          curveSmoothness: widget.dashboardStyle ? 0.22 : 0.15,
          preventCurveOverShooting: true,
          barWidth: widget.dashboardStyle ? 1.6 : 1,
          isStrokeCapRound: true,
          color: line2Color,
          dashArray: widget.dashboardStyle ? const [7, 5] : null,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}
