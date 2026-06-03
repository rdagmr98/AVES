// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:math' show pi;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/activity_models.dart';
import '../models/user_models.dart';
import 'activity_service.dart';
import 'currency_service.dart';
import 'p66_service.dart';
import 'user_service.dart';

pw.Widget _matrixHeaderCell(
  String text, {
  required double height,
  required bool rotate,
}) {
  return pw.Container(
    height: height,
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(2),
    child: rotate
        ? pw.Transform.rotateBox(
            angle: pi / 2,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
          )
        : pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
  );
}

pw.Widget _matrixDataCell(
  String text, {
  pw.Alignment align = pw.Alignment.center,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    alignment: align,
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 7),
      maxLines: 2,
      overflow: pw.TextOverflow.clip,
    ),
  );
}

pw.Widget _matrixFilledCell() {
  return pw.Container(
    decoration: const pw.BoxDecoration(color: PdfColors.black),
  );
}

pw.Widget _matrixEmptyCell() {
  return pw.Container(
    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
    alignment: pw.Alignment.center,
  );
}

class ReportService {
  final _activityService = ActivityService();
  final _currencyService = CurrencyService();
  final _p66Service = P66Service();
  final _userService = UserService();

  String _qualificationLabel(UserProfile user) {
    final quals = <String>[];
    if (user.isTi == true) quals.add('TI');
    if (user.isEtp == true) quals.add('ETP');
    return quals.isEmpty ? '-' : quals.join(', ');
  }

  Future<void> downloadMaintenanceReport() async {
    final users = await _userService.getAllUsers();
    final rows = <List<String>>[];

    for (final user in users.where((item) => item.isApprovedMaint)) {
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
          _formatDate(lastActivity?.effectiveDate),
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
          _formatDate(lastActivity?.effectiveDate),
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

    for (final user in users.where((item) => item.isApprovedCrew)) {
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
      final qualifications = _qualificationLabel(user);
      final flightStatus = assignments.any((item) => item.crewType == 'T')
          ? await _currencyService.getFlightCurrency(user.id)
          : null;
      final mdbStatus = assignments.any((item) => item.crewType == 'MDB')
          ? await _currencyService.getMdbCurrency(user.id, assignments)
          : null;

      for (final assignment in assignments) {
        if (assignment.crewType == 'T') {
          rows.add([
            user.cognome,
            user.nome,
            user.numeroLicenza ?? '-',
            user.orgUnitName,
            qualifications,
            'T',
            assignment.helicopterCode,
            '-',
            '-',
            _formatDate(lastFlight?.activityDate),
            flightStatus?.statusText ?? 'NESSUN DATO',
          ]);
          continue;
        }

        if (assignment.crewType == 'MDB') {
          rows.add([
            user.cognome,
            user.nome,
            user.numeroLicenza ?? '-',
            user.orgUnitName,
            qualifications,
            'MDB',
            assignment.helicopterCode,
            assignment.fascia ?? '-',
            '-',
            _formatDate(lastFlight?.activityDate),
            mdbStatus?.statusText ?? 'NESSUN DATO',
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
            qualifications,
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
            qualifications,
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
        'Qualifiche',
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

  Future<void> downloadP66Report() async {
    final rows = await _p66Service.getAllP66Data();
    await _downloadPdf(
      title: 'Report P-66 AVES',
      headers: const [
        'Cognome',
        'Nome',
        'Tipo Licenza',
        'N. Licenza',
        'Mesi Attività 24m',
        'Seminari',
        'Stato P-66',
        'Dettaglio',
        'Mesi coperti',
      ],
      rows: rows
          .map(
            (row) => [
              row.user.cognome,
              row.user.nome,
              row.licenseTypes,
              row.licenseNumber,
              '${row.monthCount}',
              row.seminarStatusText,
              row.statusText,
              row.statusReason,
              row.coveredMonths.join(', '),
            ],
          )
          .toList(growable: false),
      fileName:
          'report_p66_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Future<void> downloadPrivilegeMatrix({
    int? orgUnitId,
    int? helicopterTypeId,
    int? licenseTypeId,
  }) async {
    final users = await _userService.getAllUsers();
    final allPrivilegeTypes = await _userService.getPrivilegeTypes();
    allPrivilegeTypes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Collect user data
    final userDataList = <_MatrixUserData>[];
    for (final user in users.where((u) => u.isApprovedMaint)) {
      if (orgUnitId != null && user.orgUnitId != orgUnitId) continue;
      final licenses = await _userService.getUserLicenses(user.id);
      if (licenses.isEmpty) continue;
      if (licenseTypeId != null &&
          !licenses.any((l) => l.licenseTypeId == licenseTypeId)) {
        continue;
      }
      final privileges = await _userService.getUserPrivileges(user.id);
      if (helicopterTypeId != null &&
          !privileges.any((p) => p.helicopterTypeId == helicopterTypeId)) {
        continue;
      }
      userDataList.add(
        _MatrixUserData(user: user, licenses: licenses, privileges: privileges),
      );
    }

    // Collect helicopters present in data
    final helicopterMap = <int, String>{};
    for (final data in userDataList) {
      for (final p in data.privileges) {
        helicopterMap[p.helicopterTypeId] = p.helicopterCode;
      }
    }
    if (helicopterTypeId != null) {
      helicopterMap.removeWhere((id, _) => id != helicopterTypeId);
    }
    final sortedHelicopterIds = helicopterMap.keys.toList()
      ..sort((a, b) => helicopterMap[a]!.compareTo(helicopterMap[b]!));

    const headerHeight = 90.0;
    const nameColWidth = 110.0;
    const licColWidth = 70.0;
    const numColWidth = 60.0;
    const privColWidth = 22.0;

    final pdf = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final filterInfo = [
      if (orgUnitId != null) 'U.O. filtrato',
      if (helicopterTypeId != null) 'Elicottero filtrato',
      if (licenseTypeId != null) 'Tipo licenza filtrato',
    ].join(', ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'Matrice Privilegi CSL',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Generato il $generatedAt'),
            if (filterInfo.isNotEmpty) pw.Text('Filtri: $filterInfo'),
            pw.SizedBox(height: 16),
          ];

          for (final heliId in sortedHelicopterIds) {
            final heliCode = helicopterMap[heliId]!;

            // Privilege codes actually present for this helicopter
            final privCodesForHeli = <String>{};
            for (final data in userDataList) {
              for (final p
                  in data.privileges.where(
                    (p) => p.helicopterTypeId == heliId,
                  )) {
                privCodesForHeli.add(p.privilegeCode.toUpperCase());
              }
            }

            final privTypesForHeli = allPrivilegeTypes
                .where((pt) => privCodesForHeli.contains(pt.code.toUpperCase()))
                .toList();

            if (privTypesForHeli.isEmpty) continue;

            // Build table rows for this helicopter
            final tableRows = <_MatrixRow>[];
            for (final data in userDataList) {
              final privs = data.privileges
                  .where((p) => p.helicopterTypeId == heliId)
                  .toList();
              if (privs.isEmpty) continue;
              final licForHeli = data.licenses
                  .where((l) => l.helicopterTypeId == heliId)
                  .toList();
              final licStr = licForHeli
                  .map((l) => l.licenseCode)
                  .toSet()
                  .join(', ');
              final privSet = privs
                  .map((p) => p.privilegeCode.toUpperCase())
                  .toSet();
              tableRows.add(
                _MatrixRow(
                  name: data.user.fullName,
                  license: licStr.isEmpty ? '-' : licStr,
                  licenseNumber: data.user.numeroLicenza ?? '-',
                  privilegeSet: privSet,
                ),
              );
            }

            if (tableRows.isEmpty) continue;

            // Helicopter section header
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                child: pw.Text(
                  'Elicottero: $heliCode',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(nameColWidth),
                  1: const pw.FixedColumnWidth(licColWidth),
                  2: const pw.FixedColumnWidth(numColWidth),
                  for (var i = 0; i < privTypesForHeli.length; i++)
                    i + 3: const pw.FixedColumnWidth(privColWidth),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                    ),
                    children: [
                      _matrixHeaderCell(
                        'Nome',
                        height: headerHeight,
                        rotate: false,
                      ),
                      _matrixHeaderCell(
                        'Lic.',
                        height: headerHeight,
                        rotate: false,
                      ),
                      _matrixHeaderCell(
                        'N° Lic.',
                        height: headerHeight,
                        rotate: false,
                      ),
                      ...privTypesForHeli.map(
                        (pt) => _matrixHeaderCell(
                          pt.name,
                          height: headerHeight,
                          rotate: true,
                        ),
                      ),
                    ],
                  ),
                  ...tableRows.map(
                    (row) => pw.TableRow(
                      children: [
                        _matrixDataCell(
                          row.name,
                          align: pw.Alignment.centerLeft,
                        ),
                        _matrixDataCell(row.license),
                        _matrixDataCell(row.licenseNumber),
                        ...privTypesForHeli.map(
                          (pt) =>
                              row.privilegeSet.contains(pt.code.toUpperCase())
                              ? _matrixFilledCell()
                              : _matrixEmptyCell(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 24));
          }

          if (sortedHelicopterIds.isEmpty) {
            widgets.add(
              pw.Text(
                'Nessun dato disponibile per i filtri selezionati.',
              ),
            );
          }

          return widgets;
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'matrice_privilegi_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
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

class _MatrixUserData {
  const _MatrixUserData({
    required this.user,
    required this.licenses,
    required this.privileges,
  });

  final UserProfile user;
  final List<UserLicense> licenses;
  final List<UserPrivilege> privileges;
}

class _MatrixRow {
  const _MatrixRow({
    required this.name,
    required this.license,
    required this.licenseNumber,
    required this.privilegeSet,
  });

  final String name;
  final String license;
  final String licenseNumber;
  final Set<String> privilegeSet;
}
