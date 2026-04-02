import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:absensi_enakko_flutter/core/theme.dart';
import 'package:absensi_enakko_flutter/models/payroll_matrix_row.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/payroll_matrix_day_cell_widget.dart';
import 'package:absensi_enakko_flutter/screens/admin/widgets/payroll_matrix_summary_rail.dart';

class PayrollMatrixTable extends StatelessWidget {
  static const double employeeRailWidth = 180;
  static const double dayCellMinWidth = 92;
  static const double summaryColumnWidth = 72;
  static const double headerRowHeight = 48;
  static const double dataRowHeight = 76;
  static const double summaryRailGap = 0;

  const PayrollMatrixTable({
    super.key,
    required this.dataset,
    this.dateHeaders,
  });

  final PayrollMatrixDataset dataset;
  final List<DateTime>? dateHeaders;

  @override
  Widget build(BuildContext context) {
    final headers = dateHeaders ?? dataset.dates;
    final rows = dataset.rows;
    final totalHeight = headerRowHeight + (rows.length * dataRowHeight);
    final summaryRailWidth =
        PayrollMatrixRow.summaryLabels.length * summaryColumnWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stickyLayout = constraints.maxWidth >=
            employeeRailWidth + summaryRailWidth + dayCellMinWidth + 12;
        final tableContentWidth =
            employeeRailWidth + (headers.length * dayCellMinWidth);
        final tableViewportWidth = stickyLayout
            ? math.max(
                employeeRailWidth + dayCellMinWidth,
                constraints.maxWidth - summaryRailWidth - summaryRailGap - 4,
              )
            : tableContentWidth;
        final shellWidth = stickyLayout
            ? constraints.maxWidth
            : tableViewportWidth + summaryRailWidth + summaryRailGap;

        Widget shell = SizedBox(
          width: shellWidth,
          height: totalHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: tableViewportWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TableView.builder(
                      key: const Key('payroll-date-grid'),
                      diagonalDragBehavior: DiagonalDragBehavior.free,
                      pinnedRowCount: 1,
                      pinnedColumnCount: 1,
                      rowCount: rows.length + 1,
                      columnCount: headers.length + 1,
                      cellBuilder: (context, vicinity) {
                        if (vicinity.row == 0 && vicinity.column == 0) {
                          return const TableViewCell(
                            child: _CornerHeaderCell(),
                          );
                        }

                        if (vicinity.row == 0) {
                          return TableViewCell(
                            child: _DateHeaderCell(
                              date: headers[vicinity.column - 1],
                            ),
                          );
                        }

                        final row = rows[vicinity.row - 1];
                        if (vicinity.column == 0) {
                          return TableViewCell(
                            child: _EmployeeRailCell(row: row),
                          );
                        }

                        return TableViewCell(
                          child: PayrollMatrixDayCellWidget(
                            cell: row.cells[vicinity.column - 1],
                          ),
                        );
                      },
                      columnBuilder: (index) {
                        if (index == 0) {
                          return const TableSpan(
                            extent: FixedTableSpanExtent(employeeRailWidth),
                          );
                        }

                        return const TableSpan(
                          extent: FixedTableSpanExtent(dayCellMinWidth),
                          foregroundDecoration: TableSpanDecoration(
                            border: TableSpanBorder(
                              trailing: BorderSide(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                      rowBuilder: (index) {
                        if (index == 0) {
                          return const TableSpan(
                            extent: FixedTableSpanExtent(headerRowHeight),
                          );
                        }

                        return const TableSpan(
                          extent: FixedTableSpanExtent(dataRowHeight),
                          foregroundDecoration: TableSpanDecoration(
                            border: TableSpanBorder(
                              trailing: BorderSide(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: summaryRailGap),
              PayrollMatrixSummaryRail(
                rows: rows,
                headerHeight: headerRowHeight,
                dataRowHeight: dataRowHeight,
                summaryColumnWidth: summaryColumnWidth,
              ),
            ],
          ),
        );

        if (!stickyLayout) {
          shell = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: shell,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: shell,
        );
      },
    );
  }
}

class _CornerHeaderCell extends StatelessWidget {
  const _CornerHeaderCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('payroll-employee-rail'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Karyawan',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateHeaderCell extends StatelessWidget {
  const _DateHeaderCell({
    required this.date,
  });

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const days = <String>['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    const months = <String>[
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            days[date.weekday % 7],
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day} ${months[date.month]}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeRailCell extends StatelessWidget {
  const _EmployeeRailCell({
    required this.row,
  });

  final PayrollMatrixRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            row.employeeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.employmentContract.dbValue,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
