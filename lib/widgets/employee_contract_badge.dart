import 'package:flutter/material.dart';

import 'package:absensi_enakko_flutter/models/employee_contract.dart';

/// Compact circular badge displaying the employee contract type.
class EmployeeContractBadge extends StatelessWidget {
  final EmployeeContract contract;

  const EmployeeContractBadge({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: contract == EmployeeContract.fulltime
            ? const Color(0xFFDC2626)
            : const Color(0xFFF97316),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        contract == EmployeeContract.fulltime ? 'F' : 'P',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
