import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/csv_import_result.dart';
import '../../models/outlet.dart';
import '../../services/csv_import_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';

/// Steps for the CSV import wizard.
enum ImportStep { upload, preview, confirm, result }

/// Full-screen 4-step wizard for batch CSV employee import.
///
/// Flow: Upload → Preview (with validation) → Confirm → Result.
/// All CSV parsing/validation uses [CsvImportService] from Plan 01.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  ImportStep _currentStep = ImportStep.upload;

  List<CsvRowValidation> _validations = [];
  CsvImportResult? _importResult;

  bool _isLoading = false;
  bool _showErrorPanel = true;

  // Pre-fetched outlet data
  Map<String, String> _outletNameToId = {};
  Map<String, String> _outletNameDisplay = {};
  Map<String, String> _outletIdToName = {};

  // Pre-fetched employee keys for duplicate detection
  Set<String> _existingEmployeeKeys = {};

  bool _dataReady = false;

  @override
  void initState() {
    super.initState();
    _loadLookupData();
  }

  Future<void> _loadLookupData() async {
    try {
      // Fetch active outlets
      final outData = await SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .eq('is_active', true)
          .order('name');
      final outlets = outData.map((o) => Outlet.fromJson(o)).toList();

      final nameToId = <String, String>{};
      final nameDisplay = <String, String>{};
      final idToName = <String, String>{};
      for (final o in outlets) {
        final key = o.name.toLowerCase();
        nameToId[key] = o.id;
        nameDisplay[key] = o.name;
        idToName[o.id] = o.name;
      }

      // Fetch existing active employees for duplicate check
      final empData = await SupabaseClientFactory.admin
          .from('employees')
          .select('name, home_outlet_id')
          .eq('is_active', true);
      final empKeys = <String>{};
      for (final e in empData) {
        final name = (e['name'] as String?)?.toLowerCase() ?? '';
        final outletId = e['home_outlet_id'] as String? ?? '';
        if (name.isNotEmpty && outletId.isNotEmpty) {
          empKeys.add('$name|$outletId');
        }
      }

      if (!mounted) return;
      setState(() {
        _outletNameToId = nameToId;
        _outletNameDisplay = nameDisplay;
        _outletIdToName = idToName;
        _existingEmployeeKeys = empKeys;
        _dataReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Gagal memuat data outlet: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // File picker + parse + validate
  // ──────────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      if (!mounted) return;
      AppToast.error(context, 'Tidak dapat membaca file');
      return;
    }

    try {
      final rows = CsvImportService.parseBytes(bytes);
      final validations = CsvImportService.validate(
        rows: rows,
        outletNameToId: _outletNameToId,
        outletNameDisplay: _outletNameDisplay,
        existingEmployeeKeys: _existingEmployeeKeys,
      );

      if (!mounted) return;
      setState(() {
        _validations = validations;
        _showErrorPanel = true;
        _currentStep = ImportStep.preview;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final csvContent = CsvImportService.generateTemplateCsv();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/template_import_karyawan.csv');
      await file.writeAsString(csvContent);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Template Import Karyawan Enakko',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Gagal membuat template: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Execute import
  // ──────────────────────────────────────────────────────────────────

  Future<void> _executeImport() async {
    setState(() => _isLoading = true);
    try {
      final validRows = _validations.where((v) => v.isValid).toList();
      final payloads = CsvImportService.buildInsertPayloads(validRows);
      final result =
          await CsvImportService.insertAll(payloads, _outletIdToName);

      if (!mounted) return;
      setState(() {
        _importResult = result;
        _currentStep = ImportStep.result;
        _isLoading = false;
      });
      AppToast.success(
          context, '${result.totalImported} karyawan berhasil diimpor!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Karyawan CSV'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == ImportStep.upload ||
                _currentStep == ImportStep.result) {
              context.pop();
            } else {
              // Allow going back to previous wizard step
              setState(() {
                if (_currentStep == ImportStep.preview) {
                  _currentStep = ImportStep.upload;
                } else if (_currentStep == ImportStep.confirm) {
                  _currentStep = ImportStep.preview;
                }
              });
            }
          },
        ),
      ),
      body: !_dataReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                const Divider(height: 1),
                Expanded(child: _buildCurrentStep()),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Step indicator (custom — NOT Material Stepper)
  // ──────────────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final steps = [
      (ImportStep.upload, 'Upload'),
      (ImportStep.preview, 'Preview'),
      (ImportStep.confirm, 'Konfirmasi'),
      (ImportStep.result, 'Hasil'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.surface,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: _stepIndex(steps[i].$1) <= _stepIndex(_currentStep)
                      ? AppColors.accent
                      : AppColors.border,
                ),
              ),
            _buildStepCircle(steps[i].$1, steps[i].$2, i + 1),
          ],
        ],
      ),
    );
  }

  int _stepIndex(ImportStep step) => ImportStep.values.indexOf(step);

  Widget _buildStepCircle(ImportStep step, String label, int number) {
    final isActive = step == _currentStep;
    final isCompleted = _stepIndex(step) < _stepIndex(_currentStep);

    Color bgColor;
    Color textColor;
    if (isCompleted) {
      bgColor = AppColors.success;
      textColor = Colors.white;
    } else if (isActive) {
      bgColor = AppColors.accent;
      textColor = Colors.white;
    } else {
      bgColor = AppColors.border;
      textColor = AppColors.textMuted;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Step content switcher
  // ──────────────────────────────────────────────────────────────────

  Widget _buildCurrentStep() {
    return switch (_currentStep) {
      ImportStep.upload => _buildUploadStep(),
      ImportStep.preview => _buildPreviewStep(),
      ImportStep.confirm => _buildConfirmStep(),
      ImportStep.result => _buildResultStep(),
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // Step 1: Upload
  // ──────────────────────────────────────────────────────────────────

  Widget _buildUploadStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file,
              size: 72,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih file CSV untuk import karyawan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Format: nama, jabatan, gerai, foto_url',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Pilih File CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download Template'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Step 2: Preview
  // ──────────────────────────────────────────────────────────────────

  Widget _buildPreviewStep() {
    final validCount = _validations.where((v) => v.isValid).length;
    final errorCount = _validations.length - validCount;
    final hasErrors = errorCount > 0;
    final errorRows = _validations.where((v) => !v.isValid).toList();

    return Column(
      children: [
        // Summary row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${_validations.length} baris ditemukan',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• $validCount valid',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              if (hasErrors) ...[
                const SizedBox(width: 8),
                Text(
                  '• $errorCount error',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),

        // DataTable
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.surface),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columnSpacing: 16,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Jabatan', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Gerai', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
                rows: _validations.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final v = entry.value;
                  final isEven = idx % 2 == 0;
                  return DataRow(
                    color: WidgetStateProperty.all(
                      isEven ? Colors.white : AppColors.surface,
                    ),
                    cells: [
                      DataCell(Text('${v.row.rowNumber}')),
                      DataCell(Text(
                        v.row.nama,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      )),
                      DataCell(Text(v.row.jabatan ?? '-')),
                      DataCell(Text(
                        v.isValid
                            ? (v.resolvedOutletName ?? v.row.gerai)
                            : v.row.gerai,
                      )),
                      DataCell(
                        v.isValid
                            ? const Icon(Icons.check_circle,
                                size: 20, color: AppColors.success)
                            : const Icon(Icons.cancel,
                                size: 20, color: AppColors.danger),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Error panel (expandable)
        if (hasErrors) _buildErrorPanel(errorRows),

        // Bottom action bar
        _buildPreviewActions(hasErrors),
      ],
    );
  }

  Widget _buildErrorPanel(List<CsvRowValidation> errorRows) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dangerLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle header
          GestureDetector(
            onTap: () => setState(() => _showErrorPanel = !_showErrorPanel),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _showErrorPanel
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Detail Error (${errorRows.length} baris)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error list
          if (_showErrorPanel)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                padding:
                    const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                shrinkWrap: true,
                itemCount: errorRows.length,
                itemBuilder: (_, i) {
                  final v = errorRows[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Baris ${v.row.rowNumber}: ${v.errors.join(", ")}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewActions(bool hasErrors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: hasErrors
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Perbaiki CSV dan upload ulang',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _validations = [];
                      _currentStep = ImportStep.upload;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Upload Ulang'),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _currentStep = ImportStep.confirm),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Lanjutkan Import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Step 3: Confirm
  // ──────────────────────────────────────────────────────────────────

  Widget _buildConfirmStep() {
    final validRows = _validations.where((v) => v.isValid).toList();

    // Group by outlet for preview
    final grouped = <String, List<String>>{};
    for (final v in validRows) {
      final outletName = v.resolvedOutletName ?? v.row.gerai;
      grouped.putIfAbsent(outletName, () => []).add(v.row.nama);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary card
                AppCard(
                  child: Column(
                    children: [
                      const Icon(Icons.groups, size: 40, color: AppColors.accent),
                      const SizedBox(height: 8),
                      Text(
                        'Anda akan mengimpor ${validRows.length} karyawan ke ${grouped.length} outlet',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Grouped list preview
                ...grouped.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...entry.value.map((name) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline,
                                          size: 16,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () =>
                          setState(() => _currentStep = ImportStep.preview),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _executeImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Konfirmasi Import'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Step 4: Result
  // ──────────────────────────────────────────────────────────────────

  Widget _buildResultStep() {
    final result = _importResult;
    if (result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.check_circle, size: 72, color: AppColors.success),
          const SizedBox(height: 16),
          Text(
            '${result.totalImported} karyawan berhasil diimpor!',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Grouped result
          ...result.employeesByOutlet.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${entry.value.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...entry.value.map((name) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/admin/employees'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Karyawan'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
