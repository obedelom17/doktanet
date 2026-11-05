import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../common.dart';
import '../i18n.dart';
import '../session.dart';
import '../theme.dart';
import '../photos.dart';
import 'chat.dart';
import 'thread.dart';

class PatientHome extends StatelessWidget {
  const PatientHome({super.key});
  @override
  Widget build(BuildContext context) => const Shell(title: "Espace patient", tabs: [
        TabDef("Accueil", Icons.home_rounded, _Dashboard()),
        TabDef("Médecins", Icons.medical_services_outlined, _Doctors()),
        TabDef("Pharmacies", Icons.local_pharmacy_outlined, PharmacyList()),
        TabDef("Assistant", Icons.chat_bubble_outline_rounded, ChatPage(), narrow: true),
        TabDef("Profil", Icons.person_outline, _PatientProfile(), narrow: true),
      ]);
}

// ---------- Accueil ----------
class _Dashboard extends StatelessWidget {
  const _Dashboard();

  Widget _quick(BuildContext c, int i, IconData icon, Gradient g, String label, int tab) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AppCard(
            index: i,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            onTap: () => ShellScope.of(c)?.go(tab),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              IconBadge(icon, gradient: g),
              const SizedBox(height: 10),
              Text(tr(label),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: cDark, fontSize: 14)),
            ]),
          ),
        ),
      );

  Widget _mini(int i, IconData icon, int value, String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AppCard(
            index: i,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(children: [
              Icon(icon, color: cMid, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CountUp(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cDark)),
                  Text(tr(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: cMuted, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Load<List<dynamic>>(
        load: () async => [await Api.get('/appointments'), await Api.get('/prescriptions'), await Api.get('/orders'), await Api.get('/reminders')],
        builder: (c, d, reload) {
          final appts = d[0] as List, rx = d[1] as List, orders = d[2] as List, rem = d[3] as List;
          final upcoming = appts.where((a) => a['status'] == 'scheduled' || a['status'] == 'in_progress').length;
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: HeroList(
              hero: PhotoHero(
                photo: Photos.consult,
                kicker: tr("Bonjour,"),
                title: '${session.user?['full_name'] ?? ''}',
                subtitle: tr("Prenez soin de votre santé, où que vous soyez."),
                actions: [
                  HeroPill(icon: Icons.medical_services_rounded, label: tr("Prendre rendez-vous"), filled: true, onTap: () => ShellScope.of(c)?.go(1)),
                  HeroPill(icon: Icons.chat_bubble_rounded, label: tr("Assistant"), onTap: () => ShellScope.of(c)?.go(3)),
                ],
                panel: nextApptPanel(appts, forDoctor: false),
              ),
              children: [
              Row(children: [
                _quick(c, 1, Icons.medical_services_rounded, kBrandGradient, "Médecins", 1),
                _quick(c, 2, Icons.local_pharmacy_rounded, kGoldGradient, "Pharmacies", 2),
                _quick(c, 3, Icons.chat_bubble_rounded, kBrandGradient, "Assistant", 3),
              ]),
              Row(children: [
                _mini(4, Icons.event_available_rounded, upcoming, "À venir"),
                _mini(5, Icons.description_rounded, rx.length, "Ordonnances"),
                _mini(6, Icons.shopping_bag_rounded, orders.length, "Commandes"),
              ]),
              sectionTitle("Rendez-vous", icon: Icons.event_note_rounded),
              if (appts.isEmpty) const Empty("Aucun rendez-vous. Onglet Médecins pour en prendre un.", icon: Icons.event_busy_outlined),
              ResponsiveGrid(children: [for (var i = 0; i < appts.length; i++) _ApptCard(appts[i], reload, i)]),
              sectionTitle("Ordonnances", icon: Icons.description_rounded),
              if (rx.isEmpty) const Empty("Aucune ordonnance.", icon: Icons.description_outlined),
              ResponsiveGrid(children: [for (var i = 0; i < rx.length; i++) _RxCard(rx[i], reload, i)]),
              sectionTitle("Commandes en pharmacie", icon: Icons.local_pharmacy_rounded),
              if (orders.isEmpty) const Empty("Aucune commande.", icon: Icons.shopping_bag_outlined),
              ResponsiveGrid(children: [for (var i = 0; i < orders.length; i++) _OrderCard(orders[i], reload, i)]),
              sectionTitle("Rappels de prise", icon: Icons.alarm_rounded),
              if (rem.isEmpty) const Empty("Aucun rappel. Demandez à l'assistant d'en créer un.", icon: Icons.alarm_off_outlined),
              ResponsiveGrid(children: [for (var i = 0; i < rem.length; i++)
                AppCard(
                  index: i,
                  child: Row(children: [
                    const IconBadge(Icons.alarm_rounded, gradient: kGoldGradient),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${rem[i]['medication']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cDark)),
                        Text(
                          tr("Heures : {h} - jusqu'au {d}", {
                            'h': (rem[i]['times'] as List).join(', '),
                            'd': rem[i]['end_date'].toString().substring(0, 10),
                          }),
                          style: const TextStyle(color: cMuted),
                        ),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => guard(c, () async {
                        await Api.post('/reminders/${rem[i]['id']}/delete');
                        reload();
                      }),
                    ),
                  ]),
                )]),
              const SizedBox(height: 20),
            ]),
          );
        },
      );
}

class _ApptCard extends StatelessWidget {
  final dynamic a;
  final VoidCallback reload;
  final int i;
  const _ApptCard(this.a, this.reload, this.i);
  @override
  Widget build(BuildContext context) {
    final active = a['status'] == 'scheduled' || a['status'] == 'in_progress';
    return AppCard(
      index: i,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialsAvatar('${a['doctor_name']}', userId: '${a['doctor_id']}', ver: int.tryParse('${a['doctor_avatar_v']}') ?? 0),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr ${a['doctor_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cDark)),
              Text('${a['specialty']}', style: const TextStyle(color: cMid, fontWeight: FontWeight.w600)),
            ]),
          ),
          chip('${a['status']}'),
        ]),
        InfoRow(Icons.schedule_rounded, fmtDt(a['starts_at'])),
        if (a['status'] != 'cancelled')
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.forum_outlined),
              onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadPage(apptId: '${a['id']}', title: 'Dr ${a['doctor_name']}')));
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
        if (active)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.videocam_rounded),
                onPressed: () => openRoom(context, a['id']),
                label: Text(tr("Rejoindre")),
              ),
              OutlinedButton(
                onPressed: () => guard(context, () async {
                  await Api.post('/appointments/${a['id']}/status', {'status': 'cancelled'});
                  reload();
                }),
                child: Text(tr("Annuler")),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _RxCard extends StatelessWidget {
  final dynamic r;
  final VoidCallback reload;
  final int i;
  const _RxCard(this.r, this.reload, this.i);
  @override
  Widget build(BuildContext context) => AppCard(
        index: i,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBadge(Icons.description_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr("Ordonnance {c}", {'c': r['code']}),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cDark)),
                Text('Dr ${r['doctor_name']} - ${fmtDt(r['created_at'])}', style: const TextStyle(color: cMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cBg, borderRadius: BorderRadius.circular(14)),
            child: Text(itemsText(r['items']), style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => openPrint(r['id']),
              label: Text(tr("Ouvrir / PDF")),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => Scaffold(
                            appBar: gradientAppBar(tr("Choisir une pharmacie")),
                            body: pageWrap(PharmacyList(rxId: '${r['id']}')))));
                if (ok == true) reload();
              },
              label: Text(tr("Envoyer à une pharmacie")),
            ),
          ]),
        ]),
      );
}

class _OrderCard extends StatelessWidget {
  final dynamic o;
  final VoidCallback reload;
  final int i;
  const _OrderCard(this.o, this.reload, this.i);

  Future<void> _pay(BuildContext context) async {
    final phone = TextEditingController();
    String provider = 'T-Money';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text(tr("Payer {t} FCFA", {'t': o['total']})),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: provider,
              decoration: InputDecoration(labelText: tr("Opérateur")),
              items: const [
                DropdownMenuItem(value: 'T-Money', child: Text('T-Money')),
                DropdownMenuItem(value: 'Flooz', child: Text('Flooz')),
              ],
              onChanged: (v) => setS(() => provider = v ?? 'T-Money'),
            ),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr("Numéro mobile money"))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Annuler"))),
            ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Payer"))),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(context, () async {
      final r = await Api.post('/orders/${o['id']}/pay', {'phone': phone.text.trim(), 'provider': provider});
      if (context.mounted) toast(context, r['status'] == 'paid' ? tr("Paiement confirmé") : tr("Paiement en attente de confirmation"));
      reload();
    });
  }

  @override
  Widget build(BuildContext context) => AppCard(
        index: i,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBadge(Icons.local_pharmacy_rounded, gradient: kGoldGradient),
            const SizedBox(width: 14),
            Expanded(child: Text('${o['pharmacy_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cDark))),
            chip('${o['status']}'),
          ]),
          const SizedBox(height: 6),
          Text(tr("Ordonnance {c} - {t} FCFA", {'c': o['code'], 't': o['total']}), style: const TextStyle(color: cMuted)),
          const SizedBox(height: 6),
          Row(children: [chip('${o['payment_status']}')]),
          if (o['status'] == 'ready')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: cMid),
                const SizedBox(width: 8),
                Text(tr("Votre commande est prête."), style: const TextStyle(fontWeight: FontWeight.w800, color: cMid)),
              ]),
            ),
          if ((o['advice'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr("Conseil du pharmacien : {a}", {'a': o['advice']}))),
          if (o['payment_status'] != 'paid' && o['status'] != 'cancelled')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.phone_android_rounded),
                onPressed: () => _pay(context),
                label: Text(tr("Payer par mobile money")),
              ),
            ),
        ]),
      );
}

// ---------- Médecins ----------
class _Doctors extends StatefulWidget {
  const _Doctors();
  @override
  State<_Doctors> createState() => _DoctorsState();
}

class _DoctorsState extends State<_Doctors> {
  final qc = TextEditingController(), cc = TextEditingController();
  int version = 0;

  @override
  void dispose() {
    qc.dispose();
    cc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        PhotoBanner(photo: Photos.team, title: tr("Trouvez votre médecin"), subtitle: tr("Des médecins validés par notre équipe, à portée de clic.")),
        Container(
          margin: EdgeInsets.fromLTRB(hPad(context), 16, hPad(context), 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: cDark.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: qc,
                onSubmitted: (_) => setState(() => version++),
                decoration: InputDecoration(labelText: tr("Nom ou spécialité"), prefixIcon: const Icon(Icons.search_rounded, color: cMid)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: cc,
                onSubmitted: (_) => setState(() => version++),
                decoration: InputDecoration(labelText: tr("Ville"), prefixIcon: const Icon(Icons.location_on_outlined, color: cMid)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: cMid, fixedSize: const Size(52, 52)),
              onPressed: () => setState(() => version++),
              icon: const Icon(Icons.search_rounded),
            ),
          ]),
        ),
        Expanded(
          child: Load<List<dynamic>>(
            key: ValueKey(version),
            load: () async => (await Api.get('/doctors', {'q': qc.text.trim(), 'city': cc.text.trim()})) as List,
            builder: (c, docs, _) => docs.isEmpty
                ? ListView(padding: const EdgeInsets.all(16), children: const [Empty("Aucun médecin trouvé.", icon: Icons.person_search_outlined)])
                : ListView(padding: EdgeInsets.fromLTRB(hPad(c), 12, hPad(c), 16), children: [
                    ResponsiveGrid(children: [for (var i = 0; i < docs.length; i++)
                      AppCard(
                        index: i,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            InitialsAvatar('${docs[i]['full_name']}', size: 54, userId: '${docs[i]['id']}', ver: int.tryParse('${docs[i]['avatar_v']}') ?? 0),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Dr ${docs[i]['full_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cDark)),
                                Text('${docs[i]['specialty']}', style: const TextStyle(color: cMid, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(gradient: kGoldGradient, borderRadius: BorderRadius.circular(14)),
                              child: Text('${docs[i]['fee']} FCFA', style: const TextStyle(fontWeight: FontWeight.w800, color: cDark, fontSize: 13)),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          InfoRow(Icons.location_on_outlined, '${docs[i]['city'] ?? ''}'),
                          InfoRow(Icons.workspace_premium_outlined,
                              tr("{y} ans d'expérience - {l}", {'y': docs[i]['experience_years'], 'l': docs[i]['languages']})),
                          if ((docs[i]['bio'] ?? '').toString().isNotEmpty) InfoRow(Icons.notes_rounded, '${docs[i]['bio']}'),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_month_rounded),
                            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => _BookingPage(docs[i]))),
                            label: Text(tr("Prendre rendez-vous")),
                          ),
                        ]),
                      )]),
                  ]),
          ),
        ),
      ]);
}

class _BookingPage extends StatefulWidget {
  final dynamic doc;
  const _BookingPage(this.doc);
  @override
  State<_BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<_BookingPage> {
  DateTime date = DateTime.now();
  int version = 0;

  static const _days = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"];

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pick() async {
    final d = await showDatePicker(
        context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (d != null) setState(() { date = d; version++; });
  }

  Future<void> _book(String iso) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr("Confirmer le rendez-vous")),
        content: Text('Dr ${widget.doc['full_name']}\n${fmtDt(iso)}\n${widget.doc['fee']} FCFA'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Retour"))),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Confirmer"))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await guard(context, () async {
      await Api.post('/appointments', {'doctor_id': widget.doc['id'], 'starts_at': iso});
      if (mounted) {
        toast(context, tr("Rendez-vous confirmé"));
        Navigator.pop(context);
      }
    });
    if (mounted) setState(() => version++);
  }

  @override
  Widget build(BuildContext context) {
    final ds = DateFormat('yyyy-MM-dd').format(date);
    final today = DateTime.now();
    return Scaffold(
      appBar: gradientAppBar('Dr ${widget.doc['full_name']}'),
      body: pageWrap(ListView(padding: const EdgeInsets.all(16), children: [
        Reveal(
          child: AppCard(
            child: Row(children: [
              InitialsAvatar('${widget.doc['full_name']}', size: 56, userId: '${widget.doc['id']}', ver: int.tryParse('${widget.doc['avatar_v']}') ?? 0),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dr ${widget.doc['full_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cDark)),
                  Text('${widget.doc['specialty']} - ${widget.doc['fee']} FCFA', style: const TextStyle(color: cMid, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
        sectionTitle("Choisissez un jour", icon: Icons.calendar_today_rounded),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            itemBuilder: (context, k) {
              final day = DateTime(today.year, today.month, today.day).add(Duration(days: k));
              final sel = _same(day, date);
              return GestureDetector(
                onTap: () => setState(() { date = day; version++; }),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: 64,
                    margin: const EdgeInsets.only(right: 10, bottom: 6, top: 2),
                    decoration: BoxDecoration(
                      gradient: sel ? kBrandGradient : null,
                      color: sel ? null : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: sel ? Colors.transparent : cDark.withOpacity(0.12)),
                      boxShadow: sel ? [BoxShadow(color: cMid.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))] : null,
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(tr(_days[day.weekday % 7]),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white70 : cMuted)),
                      const SizedBox(height: 2),
                      Text('${day.day}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: sel ? Colors.white : cDark)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(tr("Date : {d}", {'d': DateFormat('dd/MM/yyyy').format(date)})),
          ),
        ),
        sectionTitle("Créneaux disponibles", icon: Icons.schedule_rounded),
        SizedBox(
          height: 380,
          child: Load<dynamic>(
            key: ValueKey(version),
            load: () => Api.get('/doctors/${widget.doc['id']}/slots', {'date': ds}),
            builder: (c, r, _) {
              final slots = (r['slots'] as List).cast<String>();
              if (slots.isEmpty) return ListView(children: const [Empty("Aucun créneau ce jour. Choisissez une autre date.", icon: Icons.event_busy_outlined)]);
              return SingleChildScrollView(
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  for (var k = 0; k < slots.length; k++)
                    Reveal(
                      index: k,
                      dy: 14,
                      child: ActionChip(
                        avatar: const Icon(Icons.access_time_rounded, size: 17, color: cMid),
                        label: Text(fmtHm(slots[k]), style: const TextStyle(fontSize: 16)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        onPressed: () => _book(slots[k]),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ])),
    );
  }
}

// ---------- Pharmacies ----------
class PharmacyList extends StatefulWidget {
  final String? rxId;
  const PharmacyList({super.key, this.rxId});
  @override
  State<PharmacyList> createState() => _PharmacyListState();
}

class _PharmacyListState extends State<PharmacyList> {
  final cc = TextEditingController();
  int version = 0;

  @override
  void dispose() {
    cc.dispose();
    super.dispose();
  }

  Future<bool> _order(String rxId, dynamic ph) async {
    var done = false;
    await guard(context, () async {
      final av = await Api.get('/pharmacies/${ph['id']}/availability', {'prescription_id': rxId});
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('${ph['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in (av['items'] as List))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(i['available'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 18, color: i['available'] == true ? cMid : Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(i['available'] == true
                        ? tr("Disponible - {n} ({p} FCFA)", {'n': i['name'], 'p': i['price']})
                        : tr("Indisponible - {n}", {'n': i['name']})),
                  ),
                ]),
              ),
            const SizedBox(height: 10),
            Text(tr("Total estimé : {t} FCFA", {'t': av['total']}), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Annuler"))),
            ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Envoyer et réserver"))),
          ],
        ),
      );
      if (ok == true) {
        await Api.post('/orders', {'prescription_id': rxId, 'pharmacy_id': ph['id']});
        done = true;
        if (mounted) toast(context, tr("Commande envoyée"));
      }
    });
    return done;
  }

  Future<void> _chooseRxThenOrder(dynamic ph) async {
    List rx = [];
    await guard(context, () async => rx = (await Api.get('/prescriptions')) as List);
    if (!mounted) return;
    if (rx.isEmpty) {
      toast(context, tr("Aucune ordonnance à envoyer."));
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(tr("Choisir une ordonnance")),
        children: [
          for (final r in rx)
            SimpleDialogOption(onPressed: () => Navigator.pop(d, '${r['id']}'), child: Text('${r['code']} - ${fmtDt(r['created_at'])}')),
        ],
      ),
    );
    if (id != null) await _order(id, ph);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        PhotoBanner(photo: Photos.pharmacy, title: tr("Vos pharmacies partenaires"), subtitle: tr("Vérifiez la disponibilité de vos médicaments avant de vous déplacer.")),
        Container(
          margin: EdgeInsets.fromLTRB(hPad(context), 16, hPad(context), 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: cDark.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: cc,
                onSubmitted: (_) => setState(() => version++),
                decoration: InputDecoration(labelText: tr("Ville"), prefixIcon: const Icon(Icons.location_on_outlined, color: cMid)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: cMid, fixedSize: const Size(52, 52)),
              onPressed: () => setState(() => version++),
              icon: const Icon(Icons.search_rounded),
            ),
          ]),
        ),
        Expanded(
          child: Load<List<dynamic>>(
            key: ValueKey(version),
            load: () async => (await Api.get('/pharmacies', {'city': cc.text.trim()})) as List,
            builder: (c, list, _) => list.isEmpty
                ? ListView(padding: const EdgeInsets.all(16), children: const [Empty("Aucune pharmacie partenaire.", icon: Icons.storefront_outlined)])
                : ListView(padding: EdgeInsets.fromLTRB(hPad(c), 12, hPad(c), 16), children: [
                    ResponsiveGrid(children: [for (var i = 0; i < list.length; i++)
                      AppCard(
                        index: i,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            ((int.tryParse('${list[i]['avatar_v']}') ?? 0) > 0)
                                ? InitialsAvatar('${list[i]['name']}', size: 52, userId: '${list[i]['id']}', ver: int.tryParse('${list[i]['avatar_v']}') ?? 0)
                                : const IconBadge(Icons.local_pharmacy_rounded, gradient: kGoldGradient, size: 52),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${list[i]['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cDark)),
                                Text('${list[i]['address'] ?? ''} ${list[i]['city'] ?? ''}'.trim(), style: const TextStyle(color: cMuted)),
                              ]),
                            ),
                          ]),
                          if (list[i]['phone'] != null) InfoRow(Icons.phone_outlined, tr("Tél : {p}", {'p': list[i]['phone']})),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.map_outlined),
                              onPressed: () {
                                final p = list[i];
                                final qy = p['lat'] != null ? '${p['lat']},${p['lng']}' : Uri.encodeComponent('${p['name']} ${p['address'] ?? ''} ${p['city'] ?? ''}');
                                launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$qy'), webOnlyWindowName: '_blank');
                              },
                              label: Text(tr("Voir sur la carte")),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(widget.rxId != null ? Icons.check_rounded : Icons.send_rounded),
                              onPressed: () async {
                                if (widget.rxId != null) {
                                  final ok = await _order(widget.rxId!, list[i]);
                                  if (ok && mounted) Navigator.pop(context, true);
                                } else {
                                  await _chooseRxThenOrder(list[i]);
                                }
                              },
                              label: Text(widget.rxId != null ? tr("Choisir") : tr("Envoyer une ordonnance")),
                            ),
                          ]),
                        ]),
                      )]),
                  ]),
          ),
        ),
      ]);
}

// ---------- Profil ----------
class _PatientProfile extends StatefulWidget {
  const _PatientProfile();
  @override
  State<_PatientProfile> createState() => _PatientProfileState();
}

class _PatientProfileState extends State<_PatientProfile> {
  final name = TextEditingController(), phone = TextEditingController(), birth = TextEditingController();
  final allergies = TextEditingController(), antecedents = TextEditingController();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    birth.dispose();
    allergies.dispose();
    antecedents.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await guard(context, () async {
      final m = await Api.get('/me');
      final p = (m['profile'] ?? {}) as Map;
      name.text = '${m['full_name'] ?? ''}';
      phone.text = '${m['phone'] ?? ''}';
      birth.text = '${p['birth_date'] ?? ''}';
      allergies.text = '${p['allergies'] ?? ''}';
      antecedents.text = '${p['antecedents'] ?? ''}';
      ready = true;
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SkeletonList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Reveal(
        child: Row(children: [
          InitialsAvatar(name.text, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cDark)),
              Text('${session.user?['email'] ?? ''}', style: const TextStyle(color: cMuted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          tf(name, "Nom complet", icon: Icons.person_outline),
          tf(phone, "Téléphone", type: TextInputType.phone, icon: Icons.phone_outlined),
          tf(birth, "Date de naissance (JJ/MM/AAAA)", icon: Icons.cake_outlined),
          tf(allergies, "Allergies", lines: 2, icon: Icons.warning_amber_rounded),
          tf(antecedents, "Antécédents médicaux", lines: 3, icon: Icons.history_edu_outlined),
          PrimaryButton(
            "Enregistrer",
            icon: Icons.save_outlined,
            onPressed: () => guard(context, () async {
              await Api.put('/patient/profile', {
                'full_name': name.text.trim(),
                'phone': phone.text.trim(),
                'birth_date': birth.text.trim(),
                'allergies': allergies.text.trim(),
                'antecedents': antecedents.text.trim(),
              });
              await session.refresh();
              if (mounted) toast(context, tr("Profil enregistré"));
            }),
          ),
        ]),
      ),
    ]);
  }
}
