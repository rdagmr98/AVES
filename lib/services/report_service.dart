// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:math' show pi;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/activity_models.dart';
import '../models/reference_models.dart';
import '../models/user_models.dart';
import 'activity_service.dart';
import 'currency_history.dart';
import 'currency_service.dart';
import 'p66_service.dart';
import 'useful_days.dart';
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
            // Wrap width post-rotation is the cell height, not its (narrow)
            // column width — without this the text wraps every 2-3 chars.
            child: pw.SizedBox(
              width: height - 4,
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
              ),
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
  return pw.Container(color: PdfColors.black, alignment: pw.Alignment.center);
}

pw.Widget _matrixEmptyCell() {
  return pw.Container(
    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
    alignment: pw.Alignment.center,
  );
}

class ReportService {
  final _currencyService = CurrencyService();
  final _p66Service = P66Service();
  final _userService = UserService();
  final _activityService = ActivityService();

  String _qualificationLabel(UserProfile user) {
    final quals = <String>[];
    if (user.isTi == true) quals.add('TI');
    if (user.isEtp == true) quals.add('ETP');
    return quals.isEmpty ? '-' : quals.join(', ');
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
      final qualifications = _qualificationLabel(user);
      // 3 h a semestre per T, TOB e MTB, come la dashboard.
      final flightStatus = await _currencyService.getFlightCurrency(user.id);
      final mtbStatus = assignments.any((item) => item.crewType == 'MTB')
          ? await _currencyService.getMtbCurrency(
              user.id,
              assignments,
              user.isTi,
            )
          : null;

      for (final assignment in assignments) {
        List<String> row(String requisito, CurrencyStatus? status) => [
          user.cognome,
          user.nome,
          user.numeroLicenza ?? '-',
          user.orgUnitName,
          qualifications,
          assignment.crewType,
          assignment.helicopterCode,
          assignment.fascia ?? '-',
          requisito,
          _formatDate(status?.lastActivityDate),
          status?.statusText ?? 'NESSUN DATO',
        ];
        rows.add(row('3 h a semestre', flightStatus));
        if (assignment.crewType == 'T') continue;
        if (assignment.crewType == 'MTB') {
          rows.add(row('Poligono', mtbStatus));
          continue;
        }

        // TOB: base (fascia) e capacità sull'elicottero, come la dashboard.
        rows.add(
          row(
            'Base TOB',
            await _currencyService.getTobBaseCurrency(
              user.id,
              assignment.fascia,
            ),
          ),
        );
        for (final capability in tobCapabilities.where(
          (c) => c.helicopterTypeId == assignment.helicopterTypeId,
        )) {
          rows.add(
            row(
              capability.capabilityName,
              await _currencyService.getTobCapabilityCurrencyStatus(
                user.id,
                capability.helicopterTypeId,
                capability.tobCapabilityId,
                capability.capabilityName,
                fascia: assignment.fascia,
              ),
            ),
          );
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
        'Requisito',
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
    List<int>? helicopterTypeIds,
    int? licenseTypeId,
  }) async {
    final users = await _userService.getAllUsers();
    final allPrivilegeTypes = await _userService.getPrivilegeTypes();
    allPrivilegeTypes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Collect user data: include all users with at least one license
    final userDataList = <_MatrixUserData>[];
    for (final user in users.where((u) => u.isApprovedMaint)) {
      if (orgUnitId != null && user.orgUnitId != orgUnitId) continue;
      final licenses = await _userService.getUserLicenses(user.id);
      final privileges = await _userService.getUserPrivileges(user.id);
      // Keep users with a license OR a privilege (matches dashboard logic) —
      // a maintainer can hold GO privileges without a separate license record.
      if (licenses.isEmpty && privileges.isEmpty) continue;
      if (licenseTypeId != null &&
          !licenses.any((l) => l.licenseTypeId == licenseTypeId)) {
        continue;
      }
      // Keep if user has a license OR privilege for one of the filtered helicopters
      if (helicopterTypeIds != null &&
          helicopterTypeIds.isNotEmpty &&
          !licenses.any(
            (l) => helicopterTypeIds.contains(l.helicopterTypeId),
          ) &&
          !privileges.any(
            (p) => helicopterTypeIds.contains(p.helicopterTypeId),
          )) {
        continue;
      }
      // GO status per (helicopter, privilege) — the matrix cell must reflect
      // currency, not just structural privilege assignment.
      final perPrivilegeCurrency = await _currencyService
          .getPerPrivilegeCurrency(user.id);
      final goPairs = perPrivilegeCurrency
          .where((p) => !p.status.isExpired)
          .map(
            (p) =>
                '${p.helicopterTypeId}_${p.privilegeTypeId}_${p.licenseTypeId}',
          )
          .toSet();
      userDataList.add(
        _MatrixUserData(
          user: user,
          licenses: licenses,
          privileges: privileges,
          goPairs: goPairs,
        ),
      );
    }

    // Collect helicopters from licenses (not just privileges)
    final helicopterMap = <int, String>{};
    for (final data in userDataList) {
      for (final l in data.licenses) {
        helicopterMap[l.helicopterTypeId] = l.helicopterCode;
      }
      for (final p in data.privileges) {
        helicopterMap[p.helicopterTypeId] = p.helicopterCode;
      }
    }
    if (helicopterTypeIds != null && helicopterTypeIds.isNotEmpty) {
      helicopterMap.removeWhere((id, _) => !helicopterTypeIds.contains(id));
    }
    final sortedHelicopterIds = helicopterMap.keys.toList()
      ..sort((a, b) => helicopterMap[a]!.compareTo(helicopterMap[b]!));

    const headerHeight = 110.0;
    const nameColWidth = 110.0;
    const licColWidth = 45.0;
    const numColWidth = 55.0;
    const privColWidth = 24.0;

    final pdf = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final filterInfo = [
      if (orgUnitId != null) 'U.O. filtrato',
      if (licenseTypeId != null) 'Tipo licenza filtrato',
    ].join(', ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'Matrice Privilegi CSL',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Generato il $generatedAt'),
            if (filterInfo.isNotEmpty) pw.Text('Filtri: $filterInfo'),
            pw.SizedBox(height: 16),
          ];

          var isFirstHelicopter = true;
          for (final heliId in sortedHelicopterIds) {
            final heliCode = helicopterMap[heliId]!;

            // Build table rows: all users with a license or privilege for this heli
            final tableRows = <_MatrixRow>[];
            for (final data in userDataList) {
              final licForHeli = data.licenses
                  .where((l) => l.helicopterTypeId == heliId)
                  .toList();
              final privsForHeli = data.privileges
                  .where((p) => p.helicopterTypeId == heliId)
                  .toList();
              if (licForHeli.isEmpty && privsForHeli.isEmpty) continue;
              Set<int> goIds(int? cat) => {
                for (final p in privsForHeli)
                  if (catCovers(p.licenseTypeId, cat) &&
                      data.goPairs.contains(
                        '${p.helicopterTypeId}_${p.privilegeTypeId}_${p.licenseTypeId}',
                      ))
                    p.privilegeTypeId,
              };
              void addRow(String license, int? cat) => tableRows.add(
                _MatrixRow(
                  name: data.user.fullName,
                  license: license.isEmpty ? '-' : license,
                  licenseNumber: data.user.numeroLicenza ?? '-',
                  goPrivilegeIds: goIds(cat),
                ),
              );
              // Privilegi per categoria (B1.3, B2): una riga per licenza,
              // come nell'Annesso; altrimenti una riga sola.
              if (privsForHeli.any((p) => p.licenseTypeId != null)) {
                for (final l in licForHeli) {
                  addRow(l.licenseCode, l.licenseTypeId);
                }
              } else {
                addRow(
                  licForHeli.map((l) => l.licenseCode).toSet().join(', '),
                  null,
                );
              }
            }

            if (tableRows.isEmpty) continue;

            // Ogni elicottero inizia su una pagina nuova (tranne il primo).
            if (!isFirstHelicopter) {
              widgets.add(pw.NewPage());
            }
            isFirstHelicopter = false;

            // Helicopter section header
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                ),
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
                // _matrixFilledCell/_matrixEmptyCell hanno altezza propria 0
                // (Container senza child): senza "full" l'allineamento di
                // default (top) le lascia a 0px e il nero della cella "GO"
                // non si vede mai, per nessun utente/privilegio.
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
                columnWidths: {
                  0: const pw.FixedColumnWidth(nameColWidth),
                  1: const pw.FixedColumnWidth(licColWidth),
                  2: const pw.FixedColumnWidth(numColWidth),
                  for (var i = 0; i < allPrivilegeTypes.length; i++)
                    i + 3: const pw.FixedColumnWidth(privColWidth),
                },
                children: [
                  pw.TableRow(
                    repeat: true,
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
                      ...allPrivilegeTypes.map(
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
                        ...allPrivilegeTypes.map(
                          (pt) => row.goPrivilegeIds.contains(pt.id)
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
              pw.Text('Nessun dato disponibile per i filtri selezionati.'),
            );
          }

          return widgets;
        },
      ),
    );

    await _save(
      pdf,
      'matrice_privilegi_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  /// Allegato D-P3-02 del MdQ (Em. 1): registro giornate lavorative utili già
  /// compilato con le attività validate; restano da apporre le firme dei
  /// tecnici, del Capo Squadra / Capo Linea e il visto del Capo Sezione.
  Future<void> downloadUsefulDaysRegister({
    required DateTime from,
    required DateTime to,
    OrgUnit? unit,
  }) async {
    final users = await _userService.getAllUsers();
    final acts = <MaintenanceActivity>[];
    for (final u in users.where(
      (u) => unit == null || u.orgUnitId == unit.id,
    )) {
      acts.addAll(await _activityService.getUserMaintenanceActivities(u.id));
    }
    final rows = usefulDayRows(acts, from, to);
    final df = DateFormat('dd/MM/yyyy');
    final signer = unit == null
        ? 'IL CAPO SQUADRA / IL CAPO LINEA'
        : unit.code == 'LINEA'
        ? 'IL CAPO LINEA'
        : 'IL CAPO SQUADRA';
    pw.Widget sign(String title) => pw.Column(
      children: [
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 30),
        pw.Container(width: 200, height: 0.6, color: PdfColors.black),
      ],
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Allegato D-P3-02 · Registro giornate lavorative utili',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'U.O.: ${unit?.name ?? 'tutte'}    '
                'Periodo: ${df.format(from)} - ${df.format(to)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${ctx.pageNumber} di ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              'N.',
              'Data',
              'Cognome Nome',
              'Certificato / abilitazione',
              'Task svolto',
              'C.I.P. / OdL / WO',
              'Firma',
            ],
            data: [
              for (var i = 0; i < rows.length; i++)
                [
                  '${i + 1}',
                  df.format(rows[i].day),
                  rows[i].name,
                  [
                    if (rows[i].licenseNumber.isNotEmpty)
                      'Lic. ${rows[i].licenseNumber}',
                    ...rows[i].qualifications,
                  ].join('\n'),
                  rows[i].tasks.join('; '),
                  rows[i].orders.join(', '),
                  '',
                ],
              // ponytail: righe vuote per chi non ha registrato nell'app.
              for (var i = 0; i < 6; i++)
                ['${rows.length + i + 1}', '', '', '', '', '', ''],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellHeight: 26,
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: const {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(0.45),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1.75),
              3: pw.FlexColumnWidth(1.55),
              4: pw.FlexColumnWidth(2.4),
              5: pw.FlexColumnWidth(1.2),
              6: pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              sign(signer),
              sign('VISTO\nIL CAPO SEZIONE MANTENIMENTO'),
            ],
          ),
        ],
      ),
    );
    final unitCode = unit == null ? '' : '_${unit.code}';
    await _save(
      pdf,
      'registro_D-P3-02$unitCode'
      '_${DateFormat('yyyyMMdd').format(from)}'
      '_${DateFormat('yyyyMMdd').format(to)}.pdf',
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
            // Default IntrinsicColumnWidth misura ogni cella senza wrap: una
            // colonna con testo lungo (es. lista "Privilegi") gonfia la somma
            // e fa scalare proporzionalmente TUTTE le colonne, spezzando anche
            // gli header brevi carattere per carattere. Flex uniforme evita lo shrink.
            defaultColumnWidth: const pw.FlexColumnWidth(),
          ),
        ],
      ),
    );

    await _save(pdf, fileName);
  }

  Future<void> _save(pw.Document pdf, String fileName) async {
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
    required this.goPairs,
  });

  final UserProfile user;
  final List<UserLicense> licenses;
  final List<UserPrivilege> privileges;
  // Set of 'helicopterTypeId_privilegeTypeId' pairs currently in currency (GO).
  final Set<String> goPairs;
}

class _MatrixRow {
  const _MatrixRow({
    required this.name,
    required this.license,
    required this.licenseNumber,
    required this.goPrivilegeIds,
  });

  final String name;
  final String license;
  final String licenseNumber;
  final Set<int> goPrivilegeIds;
}
