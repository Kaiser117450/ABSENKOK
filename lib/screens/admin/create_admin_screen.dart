import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/admin_onboarding_service.dart';

enum _ScreenState { form, loading, success }

class CreateAdminScreen extends StatefulWidget {
  const CreateAdminScreen({super.key});

  @override
  State<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<CreateAdminScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _service = AdminOnboardingService();

  _ScreenState _screenState = _ScreenState.form;
  CreateAdminAccountRole _selectedRole = CreateAdminAccountRole.kepalaGerai;
  List<Map<String, dynamic>> _outlets = [];
  final Set<String> _selectedOutletIds = <String>{};
  bool _loadingOutlets = true;
  bool _passwordVisible = false;
  CreateUserResult? _creationResult;

  late final AnimationController _successAnimCtrl;
  late final Animation<Offset> _bannerSlideAnim;

  @override
  void initState() {
    super.initState();
    _successAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bannerSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _successAnimCtrl,
      curve: Curves.easeOutBack,
    ));
    _loadOutlets();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _successAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOutlets() async {
    try {
      final outlets = await _service.getOutlets();
      if (mounted) {
        setState(() {
          _outlets = outlets;
          _loadingOutlets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingOutlets = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _screenState = _ScreenState.loading);

    try {
      final result = await _service.createUser(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        role: _selectedRole,
        outletIds: _selectedOutletIds.toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _creationResult = result;
        _screenState = _ScreenState.success;
        _passwordVisible = false;
      });
      _successAnimCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _screenState = _ScreenState.form);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _successAnimCtrl.reset();
    setState(() {
      _screenState = _ScreenState.form;
      _selectedRole = CreateAdminAccountRole.kepalaGerai;
      _selectedOutletIds.clear();
      _creationResult = null;
      _passwordVisible = false;
    });
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return iso;
    }
  }

  Future<void> _copyCredentials() async {
    final result = _creationResult!;
    final outletSummary = _outletSummaryForIds(result.outletIds);
    final text = 'Akses Aplikasi ABSENKOK\n'
        'Role: ${result.role.label}\n'
        'Email: ${result.email}\n'
        'Password: ${result.password}\n'
        'Gerai: $outletSummary\n'
        'Dibuat: ${_formatTimestamp(result.createdAt)}';

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kredensial disalin'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final result = _creationResult!;
    final outletSummary = _outletSummaryForIds(result.outletIds);
    final message = 'Akses Aplikasi ABSENKOK\n\n'
        'Role: ${result.role.label}\n'
        'Gerai: $outletSummary\n'
        'Email: ${result.email}\n'
        'Password: ${result.password}\n\n'
        'Silakan login di aplikasi dan segera ganti password Anda.';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('whatsapp://send?text=$encodedMessage');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      await Share.share(message, subject: 'Kredensial ABSENKOK');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp tidak tersedia, menggunakan share biasa'),
          ),
        );
      }
    }
  }

  Future<void> _generatePdfAuditTrail() async {
    final result = _creationResult!;
    final outletSummary = _outletSummaryForIds(result.outletIds);
    final outletIdSummary = result.outletIds.join(', ');
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');
    final adminEmail =
        Supabase.instance.client.auth.currentUser?.email ?? 'Unknown';

    final primaryColor = PdfColor.fromHex('#DC2626');
    final textPrimary = PdfColor.fromHex('#111827');
    final textSecondary = PdfColor.fromHex('#6B7280');
    final textMuted = PdfColor.fromHex('#9CA3AF');

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // === HEADER ===
              pw.Text(
                'Audit Trail — Pembuatan Akun ${result.role.label}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'ABSENKOK Attendance System',
                style: pw.TextStyle(fontSize: 14, color: textSecondary),
              ),
              pw.SizedBox(height: 12),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 24),

              // === ACCOUNT DETAILS ===
              _pdfSectionLabel('Detail Akun', textPrimary),
              pw.SizedBox(height: 8),
              _pdfFieldRow('Nama', result.name, textSecondary, textPrimary),
              _pdfFieldRow('Email', result.email, textSecondary, textPrimary),
              _pdfFieldRow(
                  'Password', result.password, textSecondary, textPrimary),
              _pdfFieldRow(
                  'Role', result.role.label, textSecondary, textPrimary),
              pw.SizedBox(height: 20),

              // === OUTLET ASSIGNMENT ===
              _pdfSectionLabel('Penugasan Gerai', textPrimary),
              pw.SizedBox(height: 8),
              _pdfFieldRow(
                  'Nama Gerai', outletSummary, textSecondary, textPrimary),
              _pdfFieldRow(
                  'Outlet ID', outletIdSummary, textSecondary, textPrimary),
              pw.SizedBox(height: 20),

              // === METADATA ===
              _pdfSectionLabel('Metadata', textPrimary),
              pw.SizedBox(height: 8),
              _pdfFieldRow(
                  'Dibuat oleh', adminEmail, textSecondary, textPrimary),
              _pdfFieldRow('Dibuat pada', _formatTimestamp(result.createdAt),
                  textSecondary, textPrimary),
              _pdfFieldRow('Dokumen dicetak', '${dateFormat.format(now)} WIB',
                  textSecondary, textPrimary),

              pw.Spacer(),

              // === FOOTER ===
              pw.Divider(color: textMuted),
              pw.SizedBox(height: 4),
              pw.Text(
                'Dokumen ini digenerate otomatis oleh sistem ABSENKOK',
                style: pw.TextStyle(fontSize: 10, color: textMuted),
              ),
            ],
          );
        },
      ),
    );

    final fileName =
        'audit_trail_${result.name.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
  }

  pw.Widget _pdfSectionLabel(String text, PdfColor color) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    );
  }

  pw.Widget _pdfFieldRow(
      String label, String value, PdfColor labelColor, PdfColor valueColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 12, color: labelColor),
            ),
          ),
          pw.Text(': ', style: pw.TextStyle(fontSize: 12, color: labelColor)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 14, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _outletNamesForIds(Iterable<String> outletIds) {
    final outletNameById = <String, String>{
      for (final outlet in _outlets)
        if (outlet['id'] is String && outlet['name'] is String)
          outlet['id'] as String: outlet['name'] as String,
    };

    return outletIds
        .map((id) => outletNameById[id] ?? id)
        .toList(growable: false);
  }

  String _outletSummaryForIds(Iterable<String> outletIds) {
    final names = _outletNamesForIds(outletIds);
    if (names.isEmpty) {
      return '-';
    }
    return names.join(', ');
  }

  void _changeRole(CreateAdminAccountRole role) {
    setState(() {
      _selectedRole = role;
      if (role == CreateAdminAccountRole.kepalaGerai &&
          _selectedOutletIds.length > 1) {
        final firstOutletId = _selectedOutletIds.first;
        _selectedOutletIds
          ..clear()
          ..add(firstOutletId);
      }
    });
  }

  void _selectSingleOutlet(String outletId) {
    setState(() {
      _selectedOutletIds
        ..clear()
        ..add(outletId);
    });
  }

  void _toggleSupervisorOutlet(String outletId, bool selected) {
    setState(() {
      if (selected) {
        _selectedOutletIds.add(outletId);
      } else {
        _selectedOutletIds.remove(outletId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _screenState == _ScreenState.success
              ? 'Akun Berhasil Dibuat'
              : 'Buat Akun Operasional',
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _screenState == _ScreenState.loading
            ? _buildLoadingState()
            : _screenState == _ScreenState.success
                ? _buildSuccessState()
                : _buildFormState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      key: ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Membuat akun...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return SegmentedButton<CreateAdminAccountRole>(
      segments: const [
        ButtonSegment<CreateAdminAccountRole>(
          value: CreateAdminAccountRole.kepalaGerai,
          icon: Icon(Icons.storefront_outlined),
          label: Text('Kepala Gerai'),
        ),
        ButtonSegment<CreateAdminAccountRole>(
          value: CreateAdminAccountRole.areaSupervisor,
          icon: Icon(Icons.manage_accounts_outlined),
          label: Text('Area Supervisor'),
        ),
      ],
      selected: {_selectedRole},
      onSelectionChanged: (roles) => _changeRole(roles.first),
    );
  }

  Widget _buildOutletAssignmentSelector() {
    if (_loadingOutlets) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_selectedRole == CreateAdminAccountRole.kepalaGerai) {
      return DropdownButtonFormField<String>(
        initialValue:
            _selectedOutletIds.isEmpty ? null : _selectedOutletIds.first,
        decoration: const InputDecoration(
          labelText: 'Pilih Gerai',
          hintText: 'Pilih satu gerai yang ditugaskan',
          prefixIcon: Icon(Icons.store_outlined),
        ),
        items: _outlets
            .map((outlet) => DropdownMenuItem<String>(
                  value: outlet['id'] as String,
                  child: Text(outlet['name'] as String),
                ))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          _selectSingleOutlet(value);
        },
        validator: (value) {
          if (value == null) return 'Pilih gerai terlebih dahulu';
          return null;
        },
      );
    }

    return FormField<Set<String>>(
      initialValue: _selectedOutletIds,
      validator: (_) {
        if (_selectedOutletIds.isEmpty) {
          return 'Pilih minimal satu gerai';
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Gerai Area Supervisor',
                prefixIcon: const Icon(Icons.store_mall_directory_outlined),
                errorText: field.errorText,
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              ),
              child: Column(
                children: _outlets.map((outlet) {
                  final outletId = outlet['id'] as String;
                  final selected = _selectedOutletIds.contains(outletId);
                  return CheckboxListTile(
                    value: selected,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      outlet['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (value) {
                      _toggleSupervisorOutlet(outletId, value ?? false);
                      field.didChange(_selectedOutletIds);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Supervisor hanya bisa membuka dashboard, karyawan, laporan, dan jadwal untuk gerai yang dipilih.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormState() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_add,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Buat Akun Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buat akun Kepala Gerai atau Area Supervisor. Password akan digenerate otomatis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Nama Lengkap
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                hintText: 'Masukkan nama kepala gerai',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Nama minimal 2 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'contoh@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email tidak boleh kosong';
                }
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRegex.hasMatch(v.trim())) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildRoleSelector(),
            const SizedBox(height: 16),

            _buildOutletAssignmentSelector(),
            const SizedBox(height: 28),

            // Submit button
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('Buat Akun'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    final result = _creationResult!;

    return SingleChildScrollView(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success banner
          SlideTransition(
            position: _bannerSlideAnim,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.success, width: 4),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Akun Berhasil Dibuat ✓',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kredensial siap untuk dibagikan kepada ${result.role.label} baru.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Credentials card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Akun',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _credentialRow('Nama', result.name),
                  const SizedBox(height: 8),
                  _credentialRow('Email', result.email),
                  const SizedBox(height: 8),
                  _credentialRow('Role', result.role.label),
                  const SizedBox(height: 8),
                  _passwordRow(result.password),
                  const SizedBox(height: 8),
                  _credentialRow(
                    'Gerai',
                    _outletSummaryForIds(result.outletIds),
                  ),
                  const SizedBox(height: 8),
                  _credentialRow('Dibuat', _formatTimestamp(result.createdAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          TextButton.icon(
            onPressed: _copyCredentials,
            icon: const Icon(Icons.copy),
            label: const Text('Salin Kredensial'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _shareViaWhatsApp,
            icon: const Icon(Icons.message, color: Colors.white),
            label: const Text(
              'Kirim via WhatsApp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _generatePdfAuditTrail,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Cetak Audit Trail'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.add),
            label: const Text('Buat Akun Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Text(': ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordRow(String password) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 72,
          child: Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Text(': ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            _passwordVisible ? password : '•' * password.length,
            style: TextStyle(
              fontSize: _passwordVisible ? 14 : 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
              letterSpacing: _passwordVisible ? 1.5 : 2,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _passwordVisible ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
