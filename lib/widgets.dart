import 'package:flutter/material.dart';

import 'data.dart';
import 'format.dart';

const gold = Color(0xFFE0A526);
const ink = Color(0xFF211F1B);
const paper = Color(0xFFFAF9F6);
const hairline = Color(0xFFE6E3DC);
const mutedText = Color(0xFF6F6B63);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.light).copyWith(
    primary: ink,
    onPrimary: Colors.white,
    secondary: gold,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFF4E3B5),
    ),
  );
}

class BrandTitle extends StatelessWidget {
  const BrandTitle(this.subtitle, {super.key});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/logo.webp', height: 28, fit: BoxFit.contain),
        const SizedBox(width: 10),
        Expanded(
          child: Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: mutedText)),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final ReqStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReqStatus.pending => ('Pending store', const Color(0xFFB7791F)),
      ReqStatus.issued => ('Issued · to receive', const Color(0xFF2B6CB0)),
      ReqStatus.received => ('Received', const Color(0xFF2F855A)),
      ReqStatus.rejected => ('Rejected', const Color(0xFFC53030)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.hot = false, this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final bool hot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: hot ? gold : hairline, width: hot ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: hot ? gold : mutedText),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: mutedText, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: mutedText, letterSpacing: 0.4)),
    );
  }
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: mutedText))),
    );
  }
}

BoxDecoration cardBox() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: hairline),
    );

class UnitChips extends StatelessWidget {
  const UnitChips({super.key, required this.mat, required this.value, required this.onChanged});
  final Mat mat;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final u in mat.units) ChoiceChip(label: Text(u), selected: u == value, onSelected: (_) => onChanged(u)),
      ],
    );
  }
}

/// Shows "1 Bag = 50 kg" style hints and the converted quantity.
String unitHint(Mat m, String unit, double? qty) {
  if (unit == m.unit) return 'Default unit: ${m.unit}';
  final f = m.factor(unit);
  final eq = '1 $unit = ${q(f)} ${m.unit}';
  if (qty == null || qty <= 0) return eq;
  return '$eq  •  ${q(qty)} $unit = ${q(qty * f)} ${m.unit}';
}

Future<Mat?> pickMaterial(BuildContext context, List<Mat> mats) {
  return showModalBottomSheet<Mat>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MatSheet(mats),
  );
}

class _MatSheet extends StatefulWidget {
  const _MatSheet(this.mats);
  final List<Mat> mats;

  @override
  State<_MatSheet> createState() => _MatSheetState();
}

class _MatSheetState extends State<_MatSheet> {
  String filter = '';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final list = widget.mats.where((m) => '${m.name} ${m.code}'.toLowerCase().contains(filter.toLowerCase())).toList();
    return SizedBox(
      height: (mq.size.height - mq.viewInsets.bottom) * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, mq.viewInsets.bottom),
        child: Column(
          children: [
            TextField(
              autofocus: false,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search material', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => filter = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Empty('No material matches')
                  : ListView(
                      children: [
                        for (final m in list)
                          ListTile(
                            title: Text(m.name),
                            subtitle: Text('${m.code} · ${m.unit}'),
                            onTap: () => Navigator.pop(context, m),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only request card shared by both roles; [actions] is shown at the bottom.
class ReqCard extends StatelessWidget {
  const ReqCard({super.key, required this.req, this.actions, this.warning, this.leading});
  final Req req;
  final Widget? actions;
  final String? warning;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) leading!,
              Expanded(child: Text(req.no, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              StatusChip(req.status),
            ],
          ),
          const SizedBox(height: 2),
          Text('${req.site} · ${req.by} · ${ago(req.date)}', style: const TextStyle(color: mutedText, fontSize: 13)),
          const SizedBox(height: 8),
          for (final l in req.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(l.mat.name)),
                  Text(l.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (req.note != null && req.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Note: ${req.note}', style: const TextStyle(color: mutedText, fontSize: 13)),
            ),
          if (warning != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(8)),
              child: Text(warning!, style: const TextStyle(color: Color(0xFF8A5A00), fontSize: 13)),
            ),
          if (actions != null) ...[const SizedBox(height: 10), actions!],
        ],
      ),
    );
  }
}

void toast(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action));
}
