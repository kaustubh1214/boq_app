import 'package:flutter/material.dart';

import 'data.dart';
import 'format.dart';
import 'widgets.dart';

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int tab = 0;

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final pages = [ManagerHome(go: go), const ManagerRequests(), const ManagerStock(), const ManagerInward()];
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Central Store · Store Manager'),
        actions: [
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: s.logout),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: go,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(
            icon: Badge(label: Text('${s.pendingCount}'), isLabelVisible: s.pendingCount > 0, child: const Icon(Icons.assignment_outlined)),
            selectedIcon: Badge(label: Text('${s.pendingCount}'), isLabelVisible: s.pendingCount > 0, child: const Icon(Icons.assignment)),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Badge(label: Text('${s.lowCount}'), isLabelVisible: s.lowCount > 0, child: const Icon(Icons.inventory_2_outlined)),
            selectedIcon: Badge(label: Text('${s.lowCount}'), isLabelVisible: s.lowCount > 0, child: const Icon(Icons.inventory_2)),
            label: 'Stock',
          ),
          const NavigationDestination(icon: Icon(Icons.move_to_inbox_outlined), selectedIcon: Icon(Icons.move_to_inbox), label: 'Inward'),
        ],
      ),
    );
  }
}

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key, required this.go});
  final ValueChanged<int> go;

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final value = s.mats.fold<double>(0, (a, m) => a + m.central * m.rate);
    final inTransit = s.reqs.where((r) => r.status == ReqStatus.issued).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Today at the central store', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const Text('Numbers in gold need your action.', style: TextStyle(color: mutedText)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: [
            StatCard(label: 'Requests to approve', value: '${s.pendingCount}', icon: Icons.assignment_outlined, hot: s.pendingCount > 0, onTap: () => go(1)),
            StatCard(label: 'Low stock items', value: '${s.lowCount}', icon: Icons.warning_amber_outlined, hot: s.lowCount > 0, onTap: () => go(2)),
            StatCard(label: 'Issued, in transit', value: '$inTransit', icon: Icons.local_shipping_outlined),
            StatCard(label: 'Stock value', value: rupees(value), icon: Icons.account_balance_wallet_outlined, onTap: () => go(2)),
          ],
        ),
        const SectionTitle('QUICK ACTIONS'),
        _Tile(icon: Icons.done_all, title: 'Approve & issue requests', subtitle: 'One tap: approve, create issue note, dispatch', onTap: () => go(1)),
        _Tile(icon: Icons.move_to_inbox_outlined, title: 'Receive material (GRN)', subtitle: 'Enter bags, tonnes or kg, stock is converted', onTap: () => go(3)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardBox(),
          child: Row(
            children: [
              Icon(icon, color: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(color: mutedText, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ requests

class ManagerRequests extends StatefulWidget {
  const ManagerRequests({super.key});

  @override
  State<ManagerRequests> createState() => _ManagerRequestsState();
}

class _ManagerRequestsState extends State<ManagerRequests> {
  final selected = <int>{};

  Future<void> issueOne(Req r) async {
    final s = Scope.read(context);
    final short = s.shortages(r);
    if (short.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Central stock is short'),
          content: Text('${short.join('\n')}\n\nIssue only what is available?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Issue available')),
          ],
        ),
      );
      if (go != true) return;
    }
    s.approveAndIssue(r);
    selected.remove(r.id);
    if (mounted) toast(context, '${r.no} approved and issued to ${r.site}');
  }

  Future<void> rejectOne(Req r) async {
    final s = Scope.read(context);
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${r.no}?'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (go != true) return;
    s.reject(r, text.isEmpty ? 'Not approved' : text);
    selected.remove(r.id);
    if (mounted) toast(context, '${r.no} rejected');
  }

  void bulkIssue(List<Req> pending) {
    final s = Scope.read(context);
    var done = 0;
    var short = 0;
    for (final r in pending.where((r) => selected.contains(r.id))) {
      if (s.shortages(r).isNotEmpty) short++;
      s.approveAndIssue(r);
      done++;
    }
    selected.clear();
    toast(context, '$done issued${short > 0 ? ' ($short with partial stock)' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final pending = s.reqs.where((r) => r.status == ReqStatus.pending).toList()..sort((a, b) => a.date.compareTo(b.date));
    final done = s.reqs.where((r) => r.status != ReqStatus.pending).toList()..sort((a, b) => b.date.compareTo(a.date));
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, selected.isEmpty ? 24 : 90),
          children: [
            Row(
              children: [
                const Expanded(child: Text('To approve', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                if (pending.length > 1)
                  TextButton(
                    onPressed: () => setState(() {
                      if (selected.length == pending.length) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll(pending.map((r) => r.id));
                      }
                    }),
                    child: Text(selected.length == pending.length ? 'Clear' : 'Select all'),
                  ),
              ],
            ),
            if (pending.isEmpty) const Empty('All caught up. No requests waiting.'),
            for (final r in pending)
              ReqCard(
                req: r,
                warning: s.shortages(r).isEmpty ? null : 'Stock short: ${s.shortages(r).join('; ')}',
                leading: Checkbox(
                  value: selected.contains(r.id),
                  onChanged: (v) => setState(() => v == true ? selected.add(r.id) : selected.remove(r.id)),
                ),
                actions: Row(
                  children: [
                    TextButton(onPressed: () => rejectOne(r), child: const Text('Reject')),
                    const Spacer(),
                    FilledButton.icon(onPressed: () => issueOne(r), icon: const Icon(Icons.done_all, size: 18), label: const Text('Approve & issue')),
                  ],
                ),
              ),
            const SectionTitle('RECENT'),
            if (done.isEmpty) const Empty('Nothing yet.'),
            for (final r in done.take(10)) ReqCard(req: r),
          ],
        ),
        if (selected.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: gold, foregroundColor: ink),
              onPressed: () => bulkIssue(pending),
              icon: const Icon(Icons.done_all),
              label: Text('Approve & issue ${selected.length} selected'),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------- stock

class ManagerStock extends StatefulWidget {
  const ManagerStock({super.key});

  @override
  State<ManagerStock> createState() => _ManagerStockState();
}

class _ManagerStockState extends State<ManagerStock> {
  String filter = '';

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final list = s.mats.where((m) => '${m.name} ${m.code}'.toLowerCase().contains(filter.toLowerCase())).toList();
    final value = s.mats.fold<double>(0, (a, m) => a + m.central * m.rate);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Central stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Text(rupees(value), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search material', border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 10),
        for (final m in list)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: cardBox(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${m.code} · avg ${rupees(m.rate)}/${m.unit}', style: const TextStyle(color: mutedText, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${q(m.central)} ${m.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (m.low) const Pill('Low stock', Color(0xFFC53030)),
                  ],
                ),
              ],
            ),
          ),
        if (list.isEmpty) const Empty('No material matches'),
      ],
    );
  }
}

// ------------------------------------------------------------------- inward

class ManagerInward extends StatefulWidget {
  const ManagerInward({super.key});

  @override
  State<ManagerInward> createState() => _ManagerInwardState();
}

class _ManagerInwardState extends State<ManagerInward> {
  Mat? mat;
  String unit = '';
  final qty = TextEditingController();
  final rate = TextEditingController();
  final supplier = TextEditingController();

  @override
  void dispose() {
    qty.dispose();
    rate.dispose();
    supplier.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final m = await pickMaterial(context, Scope.read(context).mats);
    if (m == null) return;
    setState(() {
      mat = m;
      unit = m.unit;
    });
  }

  void post() {
    final m = mat;
    final v = double.tryParse(qty.text.trim());
    if (m == null || v == null || v <= 0) {
      toast(context, 'Choose a material and enter the received quantity');
      return;
    }
    final before = m.central;
    Scope.read(context).postGrn(m, v, unit, double.tryParse(rate.text.trim()), supplier.text);
    toast(context, 'GRN posted: ${m.name} ${q(before)} → ${q(m.central)} ${m.unit}');
    setState(() {
      mat = null;
      unit = '';
      qty.clear();
      rate.clear();
      supplier.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final m = mat;
    final v = double.tryParse(qty.text.trim());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Receive material (GRN)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: cardBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: pick,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Material', border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down)),
                  child: Text(m?.name ?? 'Tap to choose'),
                ),
              ),
              if (m != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Received quantity', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                UnitChips(mat: m, value: unit, onChanged: (u) => setState(() => unit = u)),
                const SizedBox(height: 6),
                Text(unitHint(m, unit, v), style: const TextStyle(color: mutedText, fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Rate excl. GST (₹ per $unit)', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Supplier (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: post,
                    child: const Text('Post GRN'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SectionTitle('RECENT INWARD'),
        if (s.inward.isEmpty) const Empty('Nothing received yet.'),
        for (final e in s.inward.take(8))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.title),
            subtitle: Text(e.detail),
            trailing: Text(ago(e.when), style: const TextStyle(color: mutedText, fontSize: 12)),
          ),
      ],
    );
  }
}
