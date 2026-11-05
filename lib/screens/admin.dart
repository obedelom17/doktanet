import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';
import '../i18n.dart';
import '../theme.dart';
import 'chat.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});
  @override
  Widget build(BuildContext context) => const Shell(title: "Administration", tabs: [
        TabDef("Validation", Icons.verified_user_outlined, _Pending()),
        TabDef("Comptes", Icons.manage_accounts_outlined, _Users()),
        TabDef("Litiges", Icons.flag_outlined, _Reports()),
        TabDef("Statistiques", Icons.bar_chart_rounded, _Stats()),
        TabDef("Assistant", Icons.chat_bubble_outline_rounded, ChatPage(), narrow: true),
      ]);
}

class _Pending extends StatelessWidget {
  const _Pending();

  Widget _card(BuildContext c, dynamic u, int i, VoidCallback reload) {
    final doctor = u['role'] == 'doctor';
    return AppCard(
      index: i,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialsAvatar('${u['full_name']}'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u['full_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cDark)),
              Text(doctor ? tr("Médecin") : tr("Pharmacien"),
                  style: const TextStyle(color: cMid, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        InfoRow(Icons.mail_outline, '${u['email']} - ${u['phone'] ?? ''}'),
        if (doctor)
          InfoRow(Icons.badge_outlined, tr("N° d'ordre : {n} - {s}", {'n': u['order_number'], 's': u['specialty']})),
        if (!doctor)
          InfoRow(Icons.storefront_outlined, tr("{n} - Licence : {l}", {'n': u['pharmacy_name'], 'l': u['license_number']})),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => guard(c, () async {
              await Api.post('/admin/users/${u['id']}/validate', {'approve': true});
              reload();
            }),
            label: Text(tr("Valider")),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => guard(c, () async {
              await Api.post('/admin/users/${u['id']}/validate', {'approve': false});
              reload();
            }),
            label: Text(tr("Refuser")),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Load<List<dynamic>>(
        load: () async => (await Api.get('/admin/pending')) as List,
        builder: (c, list, reload) => RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            sectionTitle("Comptes à valider", icon: Icons.verified_user_outlined),
            if (list.isEmpty) const Empty("Aucun compte en attente.", icon: Icons.task_alt_rounded),
            ResponsiveGrid(children: [for (var i = 0; i < list.length; i++) _card(c, list[i], i, reload)]),
          ]),
        ),
      );
}

class _Stats extends StatelessWidget {
  const _Stats();

  Widget _tile(int i, IconData icon, Gradient g, String label, dynamic value) => SizedBox(
        width: 208,
        child: AppCard(
          index: i,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(icon, gradient: g),
            const SizedBox(height: 14),
            CountUp(num.tryParse('$value') ?? 0,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: cDark)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: cMuted, fontSize: 14)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Load<dynamic>(
        load: () => Api.get('/admin/stats'),
        builder: (c, s, reload) => RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            sectionTitle("Statistiques", icon: Icons.insights_rounded),
            Wrap(spacing: 14, children: [
              _tile(0, Icons.videocam_rounded, kBrandGradient, tr("Consultations terminées"), s['consultations']),
              _tile(1, Icons.payments_rounded, kGoldGradient, tr("Chiffre d'affaires brut (FCFA)"), s['gross']),
              _tile(2, Icons.percent_rounded, kBrandGradient,
                  tr("Commission {p} % (FCFA)", {'p': s['commission_pct']}), s['commission']),
              _tile(3, Icons.groups_rounded, kBrandGradient, tr("Patients"), s['patients']),
              _tile(4, Icons.medical_services_rounded, kBrandGradient, tr("Médecins actifs"), s['doctors']),
              _tile(5, Icons.local_pharmacy_rounded, kGoldGradient, tr("Pharmacies actives"), s['pharmacies']),
              _tile(6, Icons.receipt_long_rounded, kBrandGradient, tr("Commandes"), s['orders']),
            ]),
          ]),
        ),
      );
}

String _roleLabel(String r) {
  switch (r) {
    case 'doctor':
      return tr("Médecin");
    case 'pharmacy':
      return tr("Pharmacien");
    case 'admin':
      return tr("Administrateur");
    default:
      return tr("Patient");
  }
}

class _Users extends StatefulWidget {
  const _Users();
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  final qc = TextEditingController();
  int version = 0;

  Future<void> _reset(BuildContext c, dynamic u) async {
    var reset2fa = false;
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text(tr("Réinitialiser le mot de passe")),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['full_name']} (${u['email']})'),
            CheckboxListTile(
              value: reset2fa,
              onChanged: (v) => setS(() => reset2fa = v ?? false),
              title: Text(tr("Réinitialiser aussi la 2FA")),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Annuler"))),
            ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Réinitialiser"))),
          ],
        ),
      ),
    );
    if (ok != true || !c.mounted) return;
    await guard(c, () async {
      final r = await Api.post('/admin/users/${u['id']}/reset-password', {'reset_2fa': reset2fa});
      if (!c.mounted) return;
      await showDialog<void>(
        context: c,
        builder: (d) => AlertDialog(
          title: Text(tr("Mot de passe temporaire")),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr("Communiquez-le à l'utilisateur. Il doit le changer dès la connexion.")),
            const SizedBox(height: 10),
            SelectableText('${r['temp_password']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cDark)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(tr("Fermer")))],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: tf(qc, "Rechercher (nom ou email)", icon: Icons.search)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IconButton.filled(onPressed: () => setState(() => version++), icon: const Icon(Icons.search)),
            ),
          ]),
        ),
        Expanded(
          child: Load<List<dynamic>>(
            key: ValueKey(version),
            load: () async => (await Api.get('/admin/users', {'q': qc.text.trim()})) as List,
            builder: (c, list, _) => ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              if (list.isEmpty) const Empty("Aucun compte trouvé."),
              ResponsiveGrid(children: [for (var i = 0; i < list.length; i++)
                AppCard(
                  index: i,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      InitialsAvatar('${list[i]['full_name']}'),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${list[i]['full_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cDark)),
                          Text(_roleLabel('${list[i]['role']}'), style: const TextStyle(color: cMid, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      chip(list[i]['status'] == 'active' ? 'done' : '${list[i]['status']}'),
                    ]),
                    InfoRow(Icons.mail_outline, '${list[i]['email']}'),
                    InfoRow(Icons.shield_outlined, list[i]['totp_enabled'] == true ? tr("2FA activée") : tr("2FA désactivée")),
                    const SizedBox(height: 10),
                    if (list[i]['role'] != 'admin')
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset_rounded),
                        onPressed: () => _reset(c, list[i]),
                        label: Text(tr("Réinitialiser le mot de passe")),
                      ),
                  ]),
                )]),
            ]),
          ),
        ),
      ]);
}

class _Reports extends StatelessWidget {
  const _Reports();

  Future<void> _resolve(BuildContext c, dynamic r, VoidCallback reload) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(tr("Marquer comme résolu")),
        content: SizedBox(width: 400, child: tf(note, "Note de résolution", lines: 3)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Annuler"))),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Résoudre"))),
        ],
      ),
    );
    if (ok != true || !c.mounted) return;
    await guard(c, () async {
      await Api.post('/admin/reports/${r['id']}/resolve', {'note': note.text.trim()});
      reload();
    });
  }

  @override
  Widget build(BuildContext context) => Load<List<dynamic>>(
        load: () async => (await Api.get('/admin/reports')) as List,
        builder: (c, list, reload) => RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            sectionTitle("Litiges", icon: Icons.flag_outlined),
            if (list.isEmpty) const Empty("Aucun signalement.", icon: Icons.task_alt_rounded),
            ResponsiveGrid(children: [for (var i = 0; i < list.length; i++)
              AppCard(
                index: i,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        tr("Signalé par {n} ({r})", {'n': list[i]['reporter_name'], 'r': _roleLabel('${list[i]['reporter_role']}')}),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: cDark),
                      ),
                    ),
                    chip('${list[i]['status']}'),
                  ]),
                  const SizedBox(height: 6),
                  Text('${list[i]['reason']}'),
                  if ((list[i]['admin_note'] ?? '').toString().isNotEmpty) InfoRow(Icons.sticky_note_2_outlined, '${list[i]['admin_note']}'),
                  if (list[i]['status'] == 'open')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => _resolve(c, list[i], reload),
                        label: Text(tr("Marquer comme résolu")),
                      ),
                    ),
                ]),
              )]),
          ]),
        ),
      );
}
