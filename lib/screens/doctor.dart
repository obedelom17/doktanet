import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';
import '../i18n.dart';
import '../session.dart';
import '../theme.dart';
import 'package:intl/intl.dart';
import '../photos.dart';
import 'chat.dart';
import 'thread.dart';

class DoctorHome extends StatelessWidget {
  const DoctorHome({super.key});
  @override
  Widget build(BuildContext context) => const Shell(title: "Médecin", tabs: [
        TabDef("Agenda", Icons.event_note_outlined, _Agenda()),
        TabDef("Disponibilités", Icons.schedule_rounded, _Availability(), narrow: true),
        TabDef("Congés", Icons.beach_access_outlined, _Blocks(), narrow: true),
        TabDef("Assistant", Icons.chat_bubble_outline_rounded, ChatPage(), narrow: true),
        TabDef("Profil", Icons.person_outline, _DoctorProfile(), narrow: true),
      ]);
}

class _Agenda extends StatelessWidget {
  const _Agenda();

  Future<void> _notes(BuildContext context, dynamic a, VoidCallback reload) async {
    final ctl = TextEditingController(text: '${a['notes'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr("Notes de consultation")),
        content: SizedBox(width: 400, child: TextField(controller: ctl, minLines: 4, maxLines: 8, decoration: const InputDecoration())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Annuler"))),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Enregistrer"))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(context, () async {
      await Api.post('/appointments/${a['id']}/status', {'notes': ctl.text});
      reload();
    });
  }

  Future<void> _record(BuildContext context, dynamic a) async {
    await guard(context, () async {
      final r = await Api.get('/doctor/patients/${a['patient_id']}/record');
      if (!context.mounted) return;
      final p = r['patient'] ?? {};
      final rx = r['prescriptions'] as List;
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(tr("Dossier - {n}", {'n': p['full_name']})),
          content: SizedBox(
            width: 420,
            child: ListView(shrinkWrap: true, children: [
              Text(tr("Naissance : {b}", {'b': p['birth_date'] ?? '-'})),
              Text(tr("Allergies : {a}", {'a': p['allergies'] ?? '-'})),
              Text(tr("Antécédents : {a}", {'a': p['antecedents'] ?? '-'})),
              sectionTitle("Ordonnances passées"),
              if (rx.isEmpty) Text(tr("Aucune")),
              for (final x in rx)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${fmtDt(x['created_at'])} - Dr ${x['doctor_name']}\n${itemsText(x['items'])}'),
                ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(tr("Fermer")))],
        ),
      );
    });
  }

  Widget _card(BuildContext c, dynamic a, int i, VoidCallback reload) => AppCard(
        index: i,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialsAvatar('${a['patient_name']}'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['patient_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cDark)),
                Text(fmtDt(a['starts_at']), style: const TextStyle(color: cMuted)),
              ]),
            ),
            chip('${a['status']}'),
          ]),
          if ((a['notes'] ?? '').toString().isNotEmpty) InfoRow(Icons.sticky_note_2_outlined, tr("Notes : {n}", {'n': a['notes']})),
          if (a['status'] != 'cancelled')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.forum_outlined),
                onPressed: () async {
                    await Navigator.push(c, MaterialPageRoute(builder: (_) => ThreadPage(apptId: '${a['id']}', title: '${a['patient_name']}')));
                    reload();
                },
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr("Messages"), style: TextStyle(fontWeight: (int.tryParse('${a['unread']}') ?? 0) > 0 ? FontWeight.w800 : null)),
                  if ((int.tryParse('${a['unread']}') ?? 0) > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(12)),
                      child: Text('${a['unread']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
            ),
          if (a['status'] == 'scheduled' || a['status'] == 'in_progress')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam_rounded),
                  onPressed: () async {
                    await guard(c, () async {
                      await Api.post('/appointments/${a['id']}/status', {'status': 'in_progress'});
                    });
                    if (c.mounted) await openRoom(c, '${a['id']}');
                    reload();
                  },
                  label: Text(tr("Lancer")),
                ),
                OutlinedButton.icon(icon: const Icon(Icons.folder_shared_outlined), onPressed: () => _record(c, a), label: Text(tr("Dossier"))),
                OutlinedButton.icon(icon: const Icon(Icons.edit_note_rounded), onPressed: () => _notes(c, a, reload), label: Text(tr("Notes"))),
                OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  onPressed: () async {
                    await Navigator.push(c, MaterialPageRoute(builder: (_) => RxForm(a)));
                    reload();
                  },
                  label: Text(tr("Ordonnance")),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.task_alt_rounded),
                  onPressed: () => guard(c, () async {
                    await Api.post('/appointments/${a['id']}/status', {'status': 'done'});
                    reload();
                  }),
                  label: Text(tr("Terminer")),
                ),
              ]),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Load<List<dynamic>>(
        load: () async => (await Api.get('/appointments')) as List,
        builder: (c, appts, reload) => RefreshIndicator(
          onRefresh: () async => reload(),
          child: HeroList(
            hero: PhotoHero(
              photo: Photos.doctor,
              kicker: tr("Bonjour,"),
              title: 'Dr ${session.user?['full_name'] ?? ''}',
              subtitle: tr("{n} rendez-vous dans votre agenda.", {'n': appts.length}),
              actions: [
                HeroPill(icon: Icons.schedule_rounded, label: tr("Disponibilités"), filled: true, onTap: () => ShellScope.of(c)?.go(1)),
                HeroPill(icon: Icons.chat_bubble_rounded, label: tr("Assistant"), onTap: () => ShellScope.of(c)?.go(3)),
              ],
              panel: nextApptPanel(appts, forDoctor: true),
            ),
            children: [
            sectionTitle("Rendez-vous", icon: Icons.event_note_rounded),
            if (appts.isEmpty) const Empty("Aucun rendez-vous.", icon: Icons.event_busy_outlined),
            ResponsiveGrid(children: [for (var i = 0; i < appts.length; i++) _card(c, appts[i], i, reload)]),
            const SizedBox(height: 20),
          ]),
        ),
      );
}

class RxForm extends StatefulWidget {
  final dynamic appt;
  const RxForm(this.appt, {super.key});
  @override
  State<RxForm> createState() => _RxFormState();
}

class _RxFormState extends State<RxForm> {
  final rows = <List<TextEditingController>>[
    [TextEditingController(), TextEditingController(), TextEditingController()]
  ];
  final notes = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    for (final r in rows) {
      for (final x in r) {
        x.dispose();
      }
    }
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final items = <Map<String, String>>[];
    for (final r in rows) {
      if (r[0].text.trim().isNotEmpty) {
        items.add({'name': r[0].text.trim(), 'dosage': r[1].text.trim(), 'duration': r[2].text.trim()});
      }
    }
    if (items.isEmpty) {
      toast(context, tr("Ajoutez un médicament"));
      return;
    }
    setState(() => busy = true);
    await guard(context, () async {
      await Api.post('/prescriptions', {'appointment_id': widget.appt['id'], 'items': items, 'notes': notes.text.trim()});
      if (mounted) {
        toast(context, tr("Ordonnance signée et envoyée au patient"));
        Navigator.pop(context);
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: gradientAppBar(tr("Ordonnance - {n}", {'n': widget.appt['patient_name']})),
        body: pageWrap(
          ListView(padding: const EdgeInsets.all(16), children: [
            for (var i = 0; i < rows.length; i++)
              AppCard(
                index: 0,
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(gradient: kBrandGradient, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: tf(rows[i][0], "Médicament", icon: Icons.medication_outlined)),
                  ]),
                  Row(children: [
                    Expanded(child: tf(rows[i][1], "Posologie (ex : 1 cp x 3/jour)")),
                    const SizedBox(width: 8),
                    Expanded(child: tf(rows[i][2], "Durée (ex : 5 jours)")),
                  ]),
                ]),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => setState(() => rows.add([TextEditingController(), TextEditingController(), TextEditingController()])),
              label: Text(tr("Ajouter un médicament")),
            ),
            const SizedBox(height: 14),
            tf(notes, "Remarques", lines: 3, icon: Icons.notes_rounded),
            PrimaryButton("Signer et envoyer", icon: Icons.draw_rounded, busy: busy, onPressed: save),
            const SizedBox(height: 20),
          ]),
        ),
      );
}

class _Availability extends StatefulWidget {
  const _Availability();
  @override
  State<_Availability> createState() => _AvailabilityState();
}

class _AvailabilityState extends State<_Availability> {
  static const names = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"];
  static const order = [1, 2, 3, 4, 5, 6, 0];
  final on = List<bool>.filled(7, false);
  final s = List<TextEditingController>.generate(7, (_) => TextEditingController(text: '08:00'));
  final e = List<TextEditingController>.generate(7, (_) => TextEditingController(text: '17:00'));
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final x in s) {
      x.dispose();
    }
    for (final x in e) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await guard(context, () async {
      final rows = (await Api.get('/doctor/availability')) as List;
      for (final r in rows) {
        final w = r['weekday'] as int;
        on[w] = true;
        s[w].text = '${r['start']}';
        e[w].text = '${r['end']}';
      }
      ready = true;
    });
    if (mounted) setState(() {});
  }

  Widget _time(TextEditingController c, String label) => SizedBox(
        width: 92,
        child: TextField(
          controller: c,
          textAlign: TextAlign.center,
          decoration: InputDecoration(labelText: tr(label), isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SkeletonList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      sectionTitle("Disponibilités", icon: Icons.schedule_rounded),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(tr("Horaires de consultation (créneaux de 30 min, heure de Lomé)."), style: const TextStyle(color: cMuted)),
      ),
      for (var k = 0; k < order.length; k++)
        AppCard(
          index: k,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Expanded(
              child: SwitchListTile(
                value: on[order[k]],
                onChanged: (v) => setState(() => on[order[k]] = v),
                activeColor: cMid,
                title: Text(tr(names[order[k]]), style: const TextStyle(fontWeight: FontWeight.w700, color: cDark)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: on[order[k]]
                  ? Row(children: [
                      _time(s[order[k]], "Début"),
                      const SizedBox(width: 8),
                      _time(e[order[k]], "Fin"),
                    ])
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      PrimaryButton(
        "Enregistrer",
        icon: Icons.save_outlined,
        onPressed: () => guard(context, () async {
          final slots = [
            for (final w in order)
              if (on[w]) {'weekday': w, 'start': s[w].text.trim(), 'end': e[w].text.trim()}
          ];
          await Api.put('/doctor/availability', {'slots': slots});
          if (mounted) toast(context, tr("Disponibilités enregistrées"));
        }),
      ),
      const SizedBox(height: 20),
    ]);
  }
}

class _DoctorProfile extends StatefulWidget {
  const _DoctorProfile();
  @override
  State<_DoctorProfile> createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<_DoctorProfile> {
  final spec = TextEditingController(), city = TextEditingController(), fee = TextEditingController();
  final exp = TextEditingController(), lang = TextEditingController(), bio = TextEditingController();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    spec.dispose();
    city.dispose();
    fee.dispose();
    exp.dispose();
    lang.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await guard(context, () async {
      final m = await Api.get('/me');
      final p = (m['profile'] ?? {}) as Map;
      spec.text = '${p['specialty'] ?? ''}';
      city.text = '${p['city'] ?? ''}';
      fee.text = '${p['fee'] ?? 5000}';
      exp.text = '${p['experience_years'] ?? 0}';
      lang.text = '${p['languages'] ?? 'Français'}';
      bio.text = '${p['bio'] ?? ''}';
      ready = true;
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SkeletonList();
    final name = '${session.user?['full_name'] ?? ''}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Reveal(
        child: Row(children: [
          InitialsAvatar(name, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cDark)),
              Text('${session.user?['email'] ?? ''}', style: const TextStyle(color: cMuted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          tf(spec, "Spécialité", icon: Icons.medical_information_outlined),
          tf(city, "Ville", icon: Icons.location_city_outlined),
          tf(fee, "Tarif (FCFA)", type: TextInputType.number, icon: Icons.payments_outlined),
          tf(exp, "Années d'expérience", type: TextInputType.number, icon: Icons.workspace_premium_outlined),
          tf(lang, "Langues parlées", icon: Icons.translate_rounded),
          tf(bio, "Présentation", lines: 3, icon: Icons.notes_rounded),
          PrimaryButton(
            "Enregistrer",
            icon: Icons.save_outlined,
            onPressed: () => guard(context, () async {
              await Api.put('/doctor/profile', {
                'specialty': spec.text.trim(),
                'city': city.text.trim(),
                'fee': int.tryParse(fee.text.trim()) ?? 5000,
                'experience_years': int.tryParse(exp.text.trim()) ?? 0,
                'languages': lang.text.trim(),
                'bio': bio.text.trim(),
              });
              if (mounted) toast(context, tr("Profil enregistré"));
            }),
          ),
        ]),
      ),
    ]);
  }
}


class _Blocks extends StatelessWidget {
  const _Blocks();

  String _ds(DateTime d) => DateFormat('dd/MM/yyyy').format(d.toUtc());

  Future<void> _add(BuildContext c, VoidCallback reload) async {
    final r = await showDateRangePicker(
      context: c,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (r == null || !c.mounted) return;
    final f = DateFormat('yyyy-MM-dd');
    await guard(c, () async {
      await Api.post('/doctor/blocks', {'from': f.format(r.start), 'to': f.format(r.end), 'reason': ''});
      reload();
    });
  }

  @override
  Widget build(BuildContext context) => Load<List<dynamic>>(
        load: () async => (await Api.get('/doctor/blocks')) as List,
        builder: (c, list, reload) => ListView(padding: const EdgeInsets.all(16), children: [
          sectionTitle("Congés et indisponibilités", icon: Icons.beach_access_outlined),
          Text(tr("Les jours bloqués n'offrent plus de créneaux aux patients. Les rendez-vous déjà pris restent à annuler manuellement.")),
          const SizedBox(height: 12),
          PrimaryButton("Bloquer des jours", icon: Icons.event_busy_rounded, onPressed: () => _add(c, reload)),
          const SizedBox(height: 12),
          if (list.isEmpty) const Empty("Aucun jour bloqué.", icon: Icons.event_available_rounded),
          for (var i = 0; i < list.length; i++)
            AppCard(
              index: i,
              child: Row(children: [
                Expanded(
                  child: Text(
                    tr("Du {a} au {b}", {
                      'a': _ds(DateTime.parse('${list[i]['starts_at']}')),
                      'b': _ds(DateTime.parse('${list[i]['ends_at']}').subtract(const Duration(days: 1))),
                    }),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: cDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => guard(c, () async {
                    await Api.post('/doctor/blocks/${list[i]['id']}/delete');
                    reload();
                  }),
                ),
              ]),
            ),
        ]),
      );
}
