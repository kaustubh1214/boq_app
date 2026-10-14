import 'package:flutter/material.dart';

import 'data.dart';
import 'format.dart';
import 'widgets.dart';

class SiteShell extends StatefulWidget {
  const SiteShell({super.key});

  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  int tab = 0;

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final pages = [SiteHome(go: go), const SiteRequests(), const SiteConsumption()];
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Tower A · Site User'),
        actions: [
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: s.logout),
        ],
      ),
      body: pages[tab],
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              backgroundColor: gold,
              foregroundColor: ink,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewRequestScreen())),
              icon: const Icon(Icons.add),
              label: const Text('New request'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: go,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Badge(label: Text('${s.toReceive}'), isLabelVisible: s.toReceive > 0, child: const Icon(Icons.local_shipping_outlined)),
            selectedIcon: Badge(label: Text('${s.toReceive}'), isLabelVisible: s.toReceive > 0, child: const Icon(Icons.local_shipping)),
            label: 'Requests',
          ),
          const NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Consumption'),
        ],
      ),
    );
  }
}

class SiteHome extends StatelessWidget {
  const SiteHome({super.key, required this.go});
  final ValueChanged<int> go;

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('Hello, ${DemoStore.siteUserName.split(' ').first}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const Text('Here is what needs you today.', style: TextStyle(color: mutedText)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: [
            StatCard(label: 'To receive', value: '${s.toReceive}', icon: Icons.local_shipping_outlined, hot: s.toReceive > 0, onTap: () => go(1)),
            StatCard(label: 'Waiting for store', value: '${s.myPending}', icon: Icons.hourglass_empty, onTap: () => go(1)),
          ],
        ),
        const SectionTitle('QUICK ACTIONS'),
        _Action(
          icon: Icons.add_shopping_cart,
          title: 'Request material',
          subtitle: 'Pick materials and quantities, change units if needed',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewRequestScreen())),
        ),
        _Action(
          icon: Icons.fact_check_outlined,
          title: 'Log today’s consumption',
          subtitle: 'Record what was used on site',
          onTap: () => go(2),
        ),
        if (s.toReceive > 0)
          _Action(
            icon: Icons.inventory_2_outlined,
            title: '${s.toReceive} delivery waiting for you',
            subtitle: 'Confirm what arrived',
            onTap: () => go(1),
            hot: true,
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, required this.onTap, this.hot = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardBox().copyWith(border: Border.all(color: hot ? gold : hairline, width: hot ? 1.5 : 1)),
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

class SiteRequests extends StatelessWidget {
  const SiteRequests({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final list = s.siteReqs;
    if (list.isEmpty) return const Empty('No requests yet.\nTap New request to raise one.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final r in list)
          ReqCard(
            req: r,
            actions: _actions(context, s, r),
          ),
      ],
    );
  }

  Widget? _actions(BuildContext context, DemoStore s, Req r) {
    switch (r.status) {
      case ReqStatus.issued:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              s.receive(r);
              toast(context, '${r.no} received. Site stock updated.');
            },
            icon: const Icon(Icons.done_all),
            label: const Text('Received all OK'),
          ),
        );
      case ReqStatus.pending:
        return Row(
          children: [
            TextButton(
              onPressed: () {
                s.cancel(r);
                toast(context, '${r.no} cancelled');
              },
              child: const Text('Cancel request'),
            ),
          ],
        );
      case ReqStatus.received:
      case ReqStatus.rejected:
        return Row(
          children: [
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewRequestScreen(from: r))),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Repeat'),
            ),
          ],
        );
    }
  }
}

class _Draft {
  Mat? mat;
  String unit = '';
  final TextEditingController qty = TextEditingController();
}

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key, this.from});
  final Req? from;

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final rows = <_Draft>[];

  @override
  void initState() {
    super.initState();
    final from = widget.from;
    if (from == null) {
      rows.add(_Draft());
    } else {
      for (final l in from.lines) {
        rows.add(_Draft()
          ..mat = l.mat
          ..unit = l.unit
          ..qty.text = q(l.qty).replaceAll(',', ''));
      }
    }
  }

  @override
  void dispose() {
    for (final r in rows) {
      r.qty.dispose();
    }
    super.dispose();
  }

  Future<void> pick(_Draft d) async {
    final m = await pickMaterial(context, Scope.read(context).mats);
    if (m == null) return;
    setState(() {
      d.mat = m;
      d.unit = m.unit; // default unit, changeable below
    });
  }

  void submit() {
    final lines = <Line>[];
    for (final d in rows) {
      final v = double.tryParse(d.qty.text.trim());
      if (d.mat == null || v == null || v <= 0) {
        toast(context, 'Choose a material and enter a quantity on every line');
        return;
      }
      lines.add(Line(d.mat!, v, d.unit));
    }
    final store = Scope.read(context);
    final r = store.createRequest(lines);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${r.no} sent to the store'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Undo', onPressed: () => store.cancel(r)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Site: Tower A', style: TextStyle(color: mutedText)),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) _lineCard(i),
          OutlinedButton.icon(
            onPressed: () => setState(() => rows.add(_Draft())),
            icon: const Icon(Icons.add),
            label: const Text('Add another material'),
          ),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: submit,
            child: const Text('Send to store'),
          ),
        ),
      ),
    );
  }

  Widget _lineCard(int i) {
    final d = rows[i];
    final qty = double.tryParse(d.qty.text.trim());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => pick(d),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Material',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(d.mat?.name ?? 'Tap to choose'),
                  ),
                ),
              ),
              if (rows.length > 1)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    rows.removeAt(i).qty.dispose();
                  }),
                ),
            ],
          ),
          if (d.mat != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: d.qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            UnitChips(mat: d.mat!, value: d.unit, onChanged: (u) => setState(() => d.unit = u)),
            const SizedBox(height: 6),
            Text(unitHint(d.mat!, d.unit, qty), style: const TextStyle(color: mutedText, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- consumption

class SiteConsumption extends StatelessWidget {
  const SiteConsumption({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final mats = s.mats.where((m) => m.site > 0).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Stock at Tower A', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Text('Tap Log use to record what was consumed today.', style: TextStyle(color: mutedText)),
        const SizedBox(height: 10),
        if (mats.isEmpty) const Empty('Nothing in stock at site.'),
        for (final m in mats)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: cardBox(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${q(m.site)} ${m.unit} on site', style: const TextStyle(color: mutedText, fontSize: 13)),
                    ],
                  ),
                ),
                OutlinedButton(onPressed: () => _logUse(context, m), child: const Text('Log use')),
              ],
            ),
          ),
        const SectionTitle('LOGGED RECENTLY'),
        if (s.used.isEmpty) const Empty('Nothing logged yet.'),
        for (final e in s.used.take(8))
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

  Future<void> _logUse(BuildContext context, Mat m) async {
    final store = Scope.read(context);
    final qty = TextEditingController();
    var unit = m.unit;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(m.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${q(m.site)} ${m.unit} available on site', style: const TextStyle(color: mutedText)),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Quantity used', border: const OutlineInputBorder(), errorText: error),
                onChanged: (_) => setS(() => error = null),
              ),
              const SizedBox(height: 10),
              UnitChips(mat: m, value: unit, onChanged: (u) => setS(() => unit = u)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(qty.text.trim()) ?? 0;
                final err = store.consume(m, v, unit);
                if (err != null) {
                  setS(() => error = err);
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    qty.dispose();
    if (ok == true && context.mounted) toast(context, 'Consumption saved');
  }
}
