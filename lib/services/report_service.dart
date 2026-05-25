// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/activity_models.dart';
import 'activity_service.dart';
import 'currency_service.dart';
import 'user_service.dart';

class ReportService {
  final _activityService = ActivityService();
  final _currencyService = CurrencyService();
  final _userService = UserService();

  Future<void> downloadMaintenanceReport() async {
    final users = await _userService.getAllUsers();
    final rows = <List<String>>[];

    for (final user in users.where((item) => item.isApproved)) {
      final licenses = await _userService.getUserLicenses(user.id);
      final privileges = await _userService.getUserPrivileges(user.id);
      if (licenses.isEmpty && privileges.isEmpty) {
        continue;
      }

      final status = await _currencyService.getMaintenanceCurrency(user.id);
      final lastActivity = await _activityService.getLastValidatedMaintenance(
        user.id,
      );
      final privilegesByHelicopter = <int, List<String>>{};
      for (final privilege in privileges) {
        privilegesByHelicopter.putIfAbsent(
          privilege.helicopterTypeId,
          () => [],
        );
        privilegesByHelicopter[privilege.helicopterTypeId]!.add(
          privilege.privilegeName,
        );
      }

      final licenseHelicopters = <int>{};
      for (final license in licenses) {
        licenseHelicopters.add(license.helicopterTypeId);
        rows.add([
          user.cognome,
          user.nome,
          user.numeroLicenza ?? '-',
          user.orgUnitName,
          license.helicopterCode,
          license.licenseName,
          (privilegesByHelicopter[license.helicopterTypeId] ?? const ['-'])
              .join(', '),
          _formatDate(lastActivity?.activityDate),
          _formatDate(status.expiryDate),
          status.statusText,
        ]);
      }

      for (final entry in privilegesByHelicopter.entries) {
        if (licenseHelicopters.contains(entry.key)) {
          continue;
        }
        final privilege = privileges.firstWhere(
          (item) => item.helicopterTypeId == entry.key,
        );
        rows.add([
          user.cognome,
          user.nome,
          user.numeroLicenza ?? '-',
          user.orgUnitName,
          privilege.helicopterCode,
          '-',
          entry.value.join(', '),
          _formatDate(lastActivity?.activityDate),
          _formatDate(status.expiryDate),
          status.statusText,
        ]);
      }
    }

    await _downloadPdf(
      title: 'Report manutenzione AVES',
      headers: const [
        'Cognome',
        'Nome',
        'N. Licenza',
        'U.O.',
        'Elicottero',
        'Tipo Licenza',
        'Privilegi',
        'Ultima Att.',
        'Scadenza',
        'Stato',
      ],
      rows: rows,
      fileName:
          'report_manutenzione_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Future<void> downloadCrewReport() async {
    final users = await _userService.getAllUsers();
    final rows = <List<String>>[];

    for (final user in users.where((item) => item.isApproved)) {
      final assignments = await _userService.getUserCrewAssignments(user.id);
      if (assignments.isEmpty) {
        continue;
      }
      final tobCapabilities = await _userService.getUserTobCapabilities(
        user.id,
      );
      final flightActivities = await _activityService.getUserFlightActivities(
        user.id,
      );
      FlightActivity? lastFlight;
      for (final activity in flightActivities) {
        if (activity.isValidated) {
          lastFlight = activity;
          break;
        }
      }
      final flightStatus = assignments.any((item) => item.crewType == 'T')
          ? await _currencyService.getFlightCurrency(user.id)
          : null;

      for (final assignment in assignments) {
        if (assignment.crewType == 'T') {
          rows.add([
            user.cognome,
            user.nome,
            user.numeroLicenza ?? '-',
            user.orgUnitName,
            'T',
            assignment.helicopterCode,
            '-',
            '-',
            _formatDate(lastFlight?.activityDate),
            flightStatus?.statusText ?? 'NESSUN DATO',
          ]);
          continue;
        }

        final capsForHelicopter = tobCapabilities
            .where(
              (item) => item.helicopterTypeId == assignment.helicopterTypeId,
            )
            .toList();

        if (capsForHelicopter.isEmpty) {
          rows.add([
            user.cognome,
            user.nome,
            user.numeroLicenza ?? '-',
            user.orgUnitName,
            'TOB',
            assignment.helicopterCode,
            assignment.fascia ?? '-',
            '-',
            '-',
            'NESSUN DATO',
          ]);
          continue;
        }

        for (final capability in capsForHelicopter) {
          final status = await _currencyService.getTobCapabilityCurrencyStatus(
            user.id,
            capability.helicopterTypeId,
            capability.tobCapabilityId,
            capability.capabilityName,
          );
          final lastActivity = await _activityService
              .getLastValidatedTobActivity(
                user.id,
                capability.tobCapabilityId,
                helicopterTypeId: capability.helicopterTypeId,
              );
          rows.add([
            user.cognome,
            user.nome,
            user.numeroLicenza ?? '-',
            user.orgUnitName,
            'TOB',
            assignment.helicopterCode,
            assignment.fascia ?? '-',
            capability.capabilityName,
            _formatDate(lastActivity?.activityDate),
            status.statusText,
          ]);
        }
      }
    }

    await _downloadPdf(
      title: 'Report equipaggi AVES',
      headers: const [
        'Cognome',
        'Nome',
        'N. Licenza',
        'U.O.',
        'Tipo Eq.',
        'Elicottero',
        'Fascia',
        'Cap. TOB',
        'Ultima Att.',
        'Stato',
      ],
      rows: rows,
      fileName:
          'report_volo_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Future<void> _downloadPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required String fileName,
  }) async {
    final pdf = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Generato il $generatedAt'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows.isEmpty
                ? [List<String>.filled(headers.length, '-')]
                : rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
