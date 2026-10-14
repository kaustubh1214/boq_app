import 'package:flutter/widgets.dart';

import 'format.dart';

enum Role { siteUser, storeManager }

enum ReqStatus { pending, issued, received, rejected }

/// A material with its base unit, alternate units and demo stock figures.
class Mat {
  Mat(
    this.code,
    this.name,
    this.unit, {
    this.alts = const {},
    required this.reorder,
    required this.central,
    required this.site,
    required this.rate,
  });

  final String code;
  final String name;
  final String unit; // base unit
  final Map<String, double> alts; // alternate unit -> base units in 1 of it
  final double reorder;
  double central; // central store stock (base unit)
  double site; // stock at Tower A (base unit)
  double rate; // weighted-average Rs per base unit

  List<String> get units => [unit, ...alts.keys];
  double factor(String u) => u == unit ? 1.0 : (alts[u] ?? 1.0);
  bool get low => reorder > 0 && central <= reorder;
}

class Line {
  const Line(this.mat, this.qty, this.unit);
  final Mat mat;
  final double qty;
  final String unit;
  double get base => qty * mat.factor(unit);
  String get text => '${q(qty)} $unit';
}

class Req {
  Req({
    required this.id,
    required this.site,
    required this.by,
    required this.date,
    required this.lines,
    this.status = ReqStatus.pending,
    this.note,
  });

  final int id;
  final String site;
  final String by;
  final DateTime date;
  final List<Line> lines;
  ReqStatus status;
  String? note;
  List<double> issuedBase = [];

  String get no => 'RFQ-${id.toString().padLeft(4, '0')}';
}

class LogEntry {
  LogEntry(this.when, this.title, this.detail);
  final DateTime when;
  final String title;
  final String detail;
}

/// In-memory demo "backend": all rules run locally, nothing leaves the phone.
class DemoStore extends ChangeNotifier {
  DemoStore() {
    reset();
  }

  static const siteName = 'Tower A';
  static const siteUserName = 'Vikas Shinde';

  Role? role;
  late List<Mat> mats;
  late List<Req> reqs;
  late List<LogEntry> used;
  late List<LogEntry> inward;
  int _next = 6;

  void reset() {
    role = null;
    final cem = Mat('CEM-OPC53', 'Cement OPC 53 Grade', 'kg', alts: {'Bag': 50, 'MT': 1000}, reorder: 5000, central: 18000, site: 2400, rate: 7.2);
    final t12 = Mat('STL-TMT12', 'TMT Bar Fe500D 12mm', 'kg', alts: {'MT': 1000}, reorder: 2000, central: 6500, site: 1200, rate: 61.5);
    final t8 = Mat('STL-TMT8', 'TMT Bar Fe500D 8mm', 'kg', alts: {'MT': 1000}, reorder: 1000, central: 800, site: 300, rate: 63.5);
    final agg = Mat('AGG-20', 'Aggregate 20mm', 'CUM', reorder: 40, central: 120, site: 18, rate: 1450);
    final sand = Mat('SND-RIVER', 'River Sand', 'CUM', reorder: 30, central: 25, site: 10, rate: 1800);
    final aac = Mat('BLK-AAC', 'AAC Block 600x200x150', 'Nos', alts: {'Pallet': 120}, reorder: 2000, central: 9000, site: 1500, rate: 52);
    final wire = Mat('ELE-WIRE25', 'FR Copper Wire 2.5 sqmm', 'RMT', alts: {'Coil': 90}, reorder: 0, central: 1800, site: 200, rate: 24);
    final cpvc = Mat('PLB-CPVC1', 'CPVC Pipe 1 inch', 'RMT', alts: {'Length': 3}, reorder: 0, central: 600, site: 80, rate: 95);
    mats = [cem, t12, t8, agg, sand, aac, wire, cpvc];

    final now = DateTime.now();
    final r1 = Req(id: 1, site: siteName, by: siteUserName, date: now.subtract(const Duration(days: 5)), lines: [Line(cem, 40, 'Bag')], status: ReqStatus.received)
      ..issuedBase = [2000];
    final r2 = Req(id: 2, site: siteName, by: siteUserName, date: now.subtract(const Duration(days: 1)), lines: [Line(t12, 500, 'kg'), Line(t8, 200, 'kg')]);
    final r3 = Req(id: 3, site: 'Tower B', by: 'Amit Rao', date: now.subtract(const Duration(hours: 20)), lines: [Line(aac, 800, 'Nos'), Line(sand, 10, 'CUM')]);
    final r4 = Req(id: 4, site: siteName, by: siteUserName, date: now.subtract(const Duration(hours: 3)), lines: [Line(t8, 1500, 'kg')]);
    final r5 = Req(id: 5, site: siteName, by: siteUserName, date: now.subtract(const Duration(days: 2)), lines: [Line(cem, 20, 'Bag'), Line(agg, 5, 'CUM')], status: ReqStatus.issued)
      ..issuedBase = [1000, 5];
    reqs = [r1, r2, r3, r4, r5];
    used = [LogEntry(now.subtract(const Duration(days: 1)), 'Cement OPC 53 Grade', '300 kg used')];
    inward = [LogEntry(now.subtract(const Duration(days: 3)), 'TMT Bar Fe500D 12mm', '+8,000 kg · Shree Steels')];
    _next = 6;
    notifyListeners();
  }

  void login(Role r) {
    role = r;
    notifyListeners();
  }

  void logout() {
    role = null;
    notifyListeners();
  }

  // ---- counts that drive the badges
  List<Req> get siteReqs => reqs.where((r) => r.site == siteName).toList()..sort((a, b) => b.date.compareTo(a.date));
  int get pendingCount => reqs.where((r) => r.status == ReqStatus.pending).length;
  int get toReceive => siteReqs.where((r) => r.status == ReqStatus.issued).length;
  int get myPending => siteReqs.where((r) => r.status == ReqStatus.pending).length;
  int get lowCount => mats.where((m) => m.low).length;

  // ---- site user
  Req createRequest(List<Line> lines) {
    final r = Req(id: _next++, site: siteName, by: siteUserName, date: DateTime.now(), lines: lines);
    reqs.add(r);
    notifyListeners();
    return r;
  }

  void cancel(Req r) {
    if (r.status != ReqStatus.pending) return;
    reqs.remove(r);
    notifyListeners();
  }

  void receive(Req r) {
    for (var i = 0; i < r.lines.length; i++) {
      r.lines[i].mat.site += r.issuedBase[i];
    }
    r.status = ReqStatus.received;
    notifyListeners();
  }

  /// Returns an error message, or null when logged.
  String? consume(Mat m, double qty, String unit) {
    final b = qty * m.factor(unit);
    if (b <= 0) return 'Enter a quantity';
    if (b > m.site + 1e-9) return 'Only ${q(m.site)} ${m.unit} at site';
    m.site -= b;
    used.insert(0, LogEntry(DateTime.now(), m.name, '${q(qty)} $unit used'));
    notifyListeners();
    return null;
  }

  // ---- store manager
  List<String> shortages(Req r) => [
        for (final l in r.lines)
          if (l.base > l.mat.central) '${l.mat.name}: need ${q(l.base)} ${l.mat.unit}, have ${q(l.mat.central)}',
      ];

  /// Approve + create issue note + dispatch in one step (issues what is available).
  void approveAndIssue(Req r) {
    r.issuedBase = [];
    for (final l in r.lines) {
      final give = l.base > l.mat.central ? l.mat.central : l.base;
      l.mat.central -= give;
      r.issuedBase.add(give);
    }
    r.status = ReqStatus.issued;
    notifyListeners();
  }

  void reject(Req r, String reason) {
    r.status = ReqStatus.rejected;
    r.note = reason;
    notifyListeners();
  }

  void postGrn(Mat m, double qty, String unit, double? ratePerUnit, String supplier) {
    final b = qty * m.factor(unit);
    if (ratePerUnit != null && ratePerUnit > 0) {
      final perBase = ratePerUnit / m.factor(unit);
      m.rate = (m.central * m.rate + b * perBase) / (m.central + b);
    }
    m.central += b;
    final from = supplier.trim().isEmpty ? '' : ' · ${supplier.trim()}';
    inward.insert(0, LogEntry(DateTime.now(), m.name, '+${q(b)} ${m.unit}$from'));
    notifyListeners();
  }
}

/// Gives every screen access to the store and rebuilds it on change.
class Scope extends InheritedNotifier<DemoStore> {
  const Scope({super.key, required DemoStore store, required super.child}) : super(notifier: store);

  static DemoStore of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
  static DemoStore read(BuildContext c) => c.getInheritedWidgetOfExactType<Scope>()!.notifier!;
}
