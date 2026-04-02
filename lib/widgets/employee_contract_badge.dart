import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/models/employee_contract.dart';

/// Compact neutral badge displaying the employee contract type.
class EmployeeContractBadge extends StatelessWidget {
  final EmployeeContract contract;

  const EmployeeContractBadge({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bgColor;
    switch (contract) {
      case EmployeeContract.fulltime:
        color = const Color(0xFF2563EB);
        bgColor = const Color(0xFF2563EB).withValues(alpha: 0.10);
      case EmployeeContract.parttime:
        color = const Color(0xFF7C3AED);
        bgColor = const Color(0xFF7C3AED).withValues(alpha: 0.10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        contract.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
