import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../api.dart';
import '../common.dart';
import '../i18n.dart';
import '../session.dart';
import '../theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  static String? lastConv;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final msgs = <Map<String, String>>[];
  String? conv;
  bool busy = false;

  String get role => '${session.user?['role']}';

  List<String> get suggestions {
    switch (role) {
      case 'doctor':
        return ["Mon agenda des prochains jours", "Résume le dossier de mon prochain patient"];
      case 'pharmacy':
        return ["Commandes en attente", "Médicaments en stock faible"];
      case 'admin':
        return ["Statistiques de la plateforme", "Comptes en attente de validation"];
      default:
        return [
          "J'ai de la fièvre et mal à la tête depuis 2 jours",
          "Trouver un médecin généraliste",
          "Où trouver du paracétamol ?",
          "Explique-moi mon ordonnance",
          "Crée un rappel pour mon traitement",
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    conv = ChatPage.lastConv;
    if (conv != null) _open(conv!);
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _down() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _open(String id) async {
    await guard(context, () async {
      final r = (await Api.get('/chat/conversations/$id')) as List;
      msgs.clear();
      for (final m in r) {
        msgs.add({'role': '${m['role']}', 'content': '${m['content']}'});
      }
      conv = id;
      ChatPage.lastConv = id;
    });
    if (mounted) {
      setState(() {});
      _down();
    }
  }

  Future<void> _send([String? preset]) async {
    final t = (preset ?? input.text).trim();
    if (t.isEmpty || busy) return;
    input.clear();
    setState(() {
      msgs.add({'role': 'user', 'content': t});
      busy = true;
    });
    _down();
    await guard(context, () async {
      final body = <String, dynamic>{'message': t, 'lang': l10n.lang};
      if (conv != null) body['conversation_id'] = conv;
      final r = await Api.post('/chat', body);
      conv = '${r['conversation_id']}';
      ChatPage.lastConv = conv;
      msgs.add({'role': 'assistant', 'content': '${r['reply']}'});
    });
    if (mounted) {
      setState(() => busy = false);
      _down();
    }
  }

  void _new() {
    ChatPage.lastConv = null;
    setState(() {
      conv = null;
      msgs.clear();
    });
  }

  Future<void> _history() async {
    await guard(context, () async {
      final list = (await Api.get('/chat/conversations')) as List;
      if (!mounted) return;
      final id = await showDialog<String>(
        context: context,
        builder: (d) => SimpleDialog(
          title: Text(tr("Conversations")),
          children: [
            if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(tr("Aucune conversation."))),
            for (final c in list)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(d, '${c['id']}'),
                child: Text('${fmtDt(c['created_at'])} - ${c['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      );
      if (id != null) await _open(id);
    });
  }

  Widget _botAvatar() => Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(gradient: kBrandGradient, shape: BoxShape.circle),
        child: const Center(child: LogoMark(size: 20)),
      );

  Widget _markdown(String text) {
    const base = TextStyle(color: cInk, fontSize: 15.5, height: 1.4);
    return MarkdownBody(
      data: text.replaceAll('\r\n', '\n'),
      selectable: true,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: base,
        strong: base.copyWith(fontWeight: FontWeight.w800),
        em: base.copyWith(fontStyle: FontStyle.italic),
        h1: base.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: cDark),
        h2: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: cDark),
        h3: base.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700, color: cDark),
        listBullet: base,
        listIndent: 20,
        blockSpacing: 8,
        code: base.copyWith(fontFamily: 'monospace', backgroundColor: cDark.withOpacity(0.06)),
        tableHead: base.copyWith(fontWeight: FontWeight.w800),
        tableBody: base,
        tableBorder: TableBorder.all(color: cDark.withOpacity(0.2)),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        blockquoteDecoration: BoxDecoration(
          color: cDark.withOpacity(0.05),
          border: Border(left: BorderSide(color: cAccent, width: 3)),
        ),
      ),
    );
  }

  Widget _bubble(Map<String, String> m) {
    final u = m['role'] == 'user';
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: u ? kBrandGradient : null,
        color: u ? null : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(u ? 20 : 5),
          bottomRight: Radius.circular(u ? 5 : 20),
        ),
        border: u ? null : Border.all(color: cDark.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: cDark.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: u
          ? SelectableText(m['content'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.4))
          : _markdown(m['content'] ?? ''),
    );
    return Reveal(
      dy: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: u ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!u) ...[_botAvatar(), const SizedBox(width: 8)],
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }

  Widget _typing() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          _botAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cDark.withOpacity(0.08)),
            ),
            child: const TypingDots(),
          ),
        ]),
      );

  Widget _welcome() {
    final s = suggestions;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 10),
      const Reveal(child: Center(child: LogoMark(size: 84, onDark: false))),
      const SizedBox(height: 16),
      Reveal(
        index: 1,
        child: Text(tr("Comment puis-je vous aider ?"),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cDark)),
      ),
      const SizedBox(height: 18),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < s.length; i++)
          Reveal(
            index: 2 + i,
            child: ActionChip(
              avatar: const Icon(Icons.auto_awesome_rounded, size: 17, color: cAccent),
              label: Text(tr(s[i])),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              onPressed: () => _send(tr(s[i])),
            ),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final patient = role == 'patient';
    return Column(children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDE8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cAccent.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB3412D), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              patient
                  ? tr("Assistant IA : orientation et information, pas un diagnostic. Seul un médecin peut diagnostiquer et prescrire. Urgence : hôpital le plus proche.")
                  : tr("Assistant IA : vérifiez les informations avant toute décision."),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A2F1C)),
            ),
          ),
          IconButton(tooltip: tr("Historique"), onPressed: _history, icon: const Icon(Icons.history_rounded)),
          IconButton(tooltip: tr("Nouvelle conversation"), onPressed: _new, icon: const Icon(Icons.add_comment_outlined)),
        ]),
      ),
      Expanded(
        child: msgs.isEmpty
            ? _welcome()
            : ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
                for (final m in msgs) _bubble(m),
                if (busy) _typing(),
              ]),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: cDark.withOpacity(0.12), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: tr("Votre message"),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: cMid, fixedSize: const Size(48, 48)),
            onPressed: busy ? null : () => _send(),
            icon: const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    ]);
  }
}
