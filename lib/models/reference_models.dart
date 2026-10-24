class HelicopterType {
  final int id;
  final String code;
  final String name;
  final bool active;

  const HelicopterType({
    required this.id,
    required this.code,
    required this.name,
    this.active = true,
  });

  factory HelicopterType.fromJson(Map<String, dynamic> j) => HelicopterType(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    active: j['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'active': active,
  };
}

/// Ordine delle categorie: lettera decrescente, numero crescente
/// (C, B1.1-B1.4, B2, A1-A4).
int compareLicenseCode(String a, String b) {
  final byLetter = (b.isEmpty ? '' : b[0]).compareTo(a.isEmpty ? '' : a[0]);
  return byLetter != 0 ? byLetter : a.compareTo(b);
}

class LicenseType {
  final int id;
  final String code;
  final String name;

  const LicenseType({required this.id, required this.code, required this.name});

  factory LicenseType.fromJson(Map<String, dynamic> j) => LicenseType(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
  );
}

class PrivilegeType {
  final int id;
  final String code;
  final String name;
  final int sortOrder;

  const PrivilegeType({
    required this.id,
    required this.code,
    required this.name,
    this.sortOrder = 0,
  });

  factory PrivilegeType.fromJson(Map<String, dynamic> j) => PrivilegeType(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    sortOrder: j['sort_order'] as int? ?? 0,
  );
}

class TobCapability {
  final int id;
  final String code;
  final String name;

  const TobCapability({
    required this.id,
    required this.code,
    required this.name,
  });

  factory TobCapability.fromJson(Map<String, dynamic> j) => TobCapability(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
  );
}

class OrgUnit {
  final int id;
  final String code;
  final String name;

  const OrgUnit({required this.id, required this.code, required this.name});

  factory OrgUnit.fromJson(Map<String, dynamic> j) => OrgUnit(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
  );
}
