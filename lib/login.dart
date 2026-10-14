import 'package:flutter/material.dart';

import 'data.dart';
import 'widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.read(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/logo.webp', height: 64, fit: BoxFit.contain)),
                  const SizedBox(height: 24),
                  const Text(
                    'BOQ & Material Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text('AV Group Private Limited', textAlign: TextAlign.center, style: TextStyle(color: mutedText)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'Demo build: sample data stored on this phone only. No server is used, and changes reset when you tap Reset.',
                      style: TextStyle(color: Color(0xFF8A5A00), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Sign in as', style: TextStyle(fontWeight: FontWeight.w700, color: mutedText)),
                  const SizedBox(height: 8),
                  _RoleCard(
                    icon: Icons.warehouse_outlined,
                    title: 'Store Manager',
                    subtitle: 'Central store: approve & issue, stock, inward (GRN)',
                    onTap: () => s.login(Role.storeManager),
                  ),
                  const SizedBox(height: 10),
                  _RoleCard(
                    icon: Icons.engineering_outlined,
                    title: 'Site User · Tower A',
                    subtitle: 'Request material, receive deliveries, log daily use',
                    onTap: () => s.login(Role.siteUser),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      s.reset();
                      toast(context, 'Demo data reset');
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset demo data'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardBox(),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: const Color(0xFFF4E3B5), child: Icon(icon, color: ink)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: mutedText, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: mutedText),
          ],
        ),
      ),
    );
  }
}
