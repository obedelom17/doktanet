import 'install.dart';
import 'pattern.dart';
import 'screens/account.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'api.dart';
import 'i18n.dart';
import 'session.dart';
import 'theme.dart';

String fmtDt(dynamic iso) => DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse('$iso').toLocal());
String fmtHm(dynamic iso) => DateFormat('HH:mm').format(DateTime.parse('$iso').toLocal());

/// Affiche un message déjà traduit (utiliser tr(...) à l'appel).
void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

Future<void> guard(BuildContext c, Future<void> Function() f) async {
  try {
    await f();
  } on ApiException catch (e) {
    if (c.mounted) toast(c, tr(e.message));
  } catch (e) {
    if (c.mounted) toast(c, tr("Erreur : {e}", {'e': e}));
  }
}

String itemsText(dynamic items) => (items as List)
    .map((e) => '${e['name']} - ${e['dosage'] ?? ''} ${e['duration'] ?? ''}'.trim())
    .join('\n');

const statusFr = {
  'scheduled': 'Planifié',
  'in_progress': 'En cours',
  'done': 'Terminé',
  'cancelled': 'Annulé',
  'sent': 'Envoyée',
  'preparing': 'En préparation',
  'ready': 'Prête',
  'delivered': 'Délivrée',
  'unpaid': 'Non payé',
  'pending': 'En attente',
  'paid': 'Payé',
  'open': 'Ouvert',
  'resolved': 'Résolu',
};

Color _statusColor(String s) {
  switch (s) {
    case 'done':
    case 'ready':
    case 'delivered':
    case 'paid':
    case 'resolved':
      return cOk;
    case 'cancelled':
    case 'unpaid':
      return Colors.red.shade700;
    case 'in_progress':
    case 'preparing':
      return cTeal;
    default:
      return const Color(0xFFB77700);
  }
}

// ---------------------------------------------------------------------------
// Petits éléments de texte / formulaire
// ---------------------------------------------------------------------------

Widget chip(String s) {
  final col = _statusColor(s);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: col.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(tr(statusFr[s] ?? s), style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12.5)),
    ]),
  );
}

Widget sectionTitle(String t, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(children: [
        const DiamondTrio(),
        const SizedBox(width: 8),
        if (icon != null) ...[Icon(icon, color: cMid, size: 22), const SizedBox(width: 8)],
        Expanded(
          child: Text(tr(t), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cDark)),
        ),
      ]),
    );

class Empty extends StatelessWidget {
  final String text;
  final IconData icon;
  const Empty(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Reveal(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cMid.withOpacity(0.18)),
          ),
          child: Row(children: [
            Icon(icon, color: cMid.withOpacity(0.7), size: 30),
            const SizedBox(width: 14),
            Expanded(child: Text(tr(text), style: const TextStyle(color: cMuted, fontSize: 15))),
          ]),
        ),
      );
}

Widget tf(TextEditingController c, String label,
        {TextInputType? type, int lines = 1, bool obscure = false, IconData? icon}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        obscureText: obscure,
        minLines: lines,
        maxLines: obscure ? 1 : lines,
        decoration: InputDecoration(
          labelText: tr(label),
          prefixIcon: icon == null ? null : Icon(icon, color: cMid),
        ),
      ),
    );

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoRow(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: cMid),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: cMuted, fontSize: 14.5))),
        ]),
      );
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final double size;
  const IconBadge(this.icon, {super.key, this.gradient = kBrandGradient, this.size = 46});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [BoxShadow(color: cMid.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      );
}

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  /// Photo de profil : id de l'utilisateur et version (avatar_v). Sans photo (ver 0), initiales.
  final String? userId;
  final int ver;
  const InitialsAvatar(this.name, {super.key, this.size = 48, this.userId, this.ver = 0});
  @override
  Widget build(BuildContext context) {
    final initials = _initials(context);
    if (userId == null || ver <= 0) return initials;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: cMid.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipOval(
        child: Image.network(
          Api.avatarUrl(userId!, ver),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initials,
          loadingBuilder: (c, child, p) => p == null ? child : initials,
        ),
      ),
    );
  }

  Widget _initials(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final ini = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts[0][0] : '${parts[0][0]}${parts[1][0]}').toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: cMid.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Text(ini, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

// ---------------------------------------------------------------------------
// Animations
// ---------------------------------------------------------------------------

/// Apparition en fondu + glissement, avec décalage selon l'index (effet cascade).
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final double dy;
  const Reveal({super.key, required this.child, this.index = 0, this.delay = Duration.zero, this.dy = 24});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final d = widget.delay + Duration(milliseconds: math.min(widget.index, 10) * 70);
    if (d == Duration.zero) {
      _c.forward();
    } else {
      _t = Timer(d, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _a.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.dy), child: child),
        ),
      );
}

/// Carte blanche arrondie : légère élévation au survol, ondulation au clic.
class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Gradient? gradient;
  final int index;
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.index = 0,
  });
  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);
    return Reveal(
      index: widget.index,
      child: MouseRegion(
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 14),
          transform: Matrix4.translationValues(0, hover ? -4 : 0, 0),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? Colors.white : null,
            borderRadius: r,
            border: Border.all(color: hover ? cMid.withOpacity(0.4) : cDark.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: cDark.withOpacity(hover ? 0.16 : 0.07),
                blurRadius: hover ? 28 : 16,
                offset: Offset(0, hover ? 12 : 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: r,
            child: InkWell(
              borderRadius: r,
              onTap: widget.onTap,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton principal dégradé : grossit au survol, s'enfonce au clic.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool gold;
  final bool expand;
  const PrimaryButton(this.label,
      {super.key, this.onPressed, this.icon, this.busy = false, this.gold = false, this.expand = true});
  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool hover = false, down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final fg = widget.gold ? cDark : Colors.white;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => down = true) : null,
        onTapUp: (_) => setState(() => down = false),
        onTapCancel: () => setState(() => down = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: down ? 0.97 : (hover && enabled ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: enabled || widget.busy ? (widget.gold ? kGoldGradient : kBrandGradient) : null,
              color: enabled || widget.busy ? null : Colors.black12,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: (widget.gold ? cAccent : cMid).withOpacity(hover ? 0.5 : 0.3),
                        blurRadius: hover ? 26 : 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, color: fg, size: 20),
                if (widget.busy || widget.icon != null) const SizedBox(width: 10),
                Text(tr(widget.label), style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compteur animé (0 -> valeur).
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle? style;
  const CountUp(this.value, {super.key, this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 1300),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(NumberFormat.decimalPattern('fr').format(v.round()), style: style),
      );
}

/// Pastille qui pulse (indicateur « en ligne »).
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, this.color = cMint, this.size = 10});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size * 2.4,
        height: widget.size * 2.4,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(alignment: Alignment.center, children: [
            Container(
              width: widget.size * (1 + 1.4 * _c.value),
              height: widget.size * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.45 * (1 - _c.value))),
            ),
            Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ]),
        ),
      );
}

/// Trois points qui rebondissent (« l'assistant écrit »).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 9,
              height: 9,
              transform: Matrix4.translationValues(0, -6 * math.max(0.0, math.sin((_c.value * 2 * math.pi) - i * 0.9)), 0),
              decoration: const BoxDecoration(color: cMid, shape: BoxShape.circle),
            ),
        ]),
      );
}

/// Courbe d'électrocardiogramme animée (identité visuelle santé).
class EcgPainter extends CustomPainter {
  final double t;
  final Color color;
  EcgPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    const beats = 3;
    final seg = w / beats;
    final path = Path()..moveTo(0, h * 0.5);
    for (var i = 0; i < beats; i++) {
      final x = seg * i;
      path.lineTo(x + seg * 0.22, h * 0.5);
      path.lineTo(x + seg * 0.30, h * 0.40);
      path.lineTo(x + seg * 0.37, h * 0.5);
      path.lineTo(x + seg * 0.43, h * 0.5);
      path.lineTo(x + seg * 0.47, h * 0.88);
      path.lineTo(x + seg * 0.53, h * 0.04);
      path.lineTo(x + seg * 0.58, h * 0.62);
      path.lineTo(x + seg * 0.62, h * 0.5);
      path.lineTo(x + seg * 0.76, h * 0.5);
      path.lineTo(x + seg * 0.84, h * 0.36);
      path.lineTo(x + seg * 0.92, h * 0.5);
      path.lineTo(x + seg, h * 0.5);
    }
    final metric = path.computeMetrics().first;
    final len = metric.length;
    final head = len * t;
    final tail = math.max(0.0, head - len * 0.4);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(metric.extractPath(tail, head), stroke);
    final tangent = metric.getTangentForOffset(head);
    if (tangent != null) {
      canvas.drawCircle(tangent.position, 9, Paint()..color = color.withOpacity(0.25));
      canvas.drawCircle(tangent.position, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(EcgPainter old) => old.t != t;
}

class _BlobPainter extends CustomPainter {
  final double t;
  _BlobPainter(this.t);

  void _blob(Canvas canvas, Size s, double fx, double fy, double r, Color c, double phase) {
    final cx = s.width * (fx + 0.08 * math.sin(t * 2 * math.pi + phase));
    final cy = s.height * (fy + 0.08 * math.cos(t * 2 * math.pi + phase));
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..shader = RadialGradient(colors: [c.withOpacity(0.55), c.withOpacity(0)]).createShader(rect),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = math.max(size.width, size.height);
    _blob(canvas, size, 0.15, 0.15, m * 0.45, cMint, 0);
    _blob(canvas, size, 0.9, 0.35, m * 0.4, cTeal, 2);
    _blob(canvas, size, 0.4, 0.95, m * 0.5, cAccent, 4);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

/// Fond dégradé avec halos lumineux qui flottent lentement.
class AnimatedBackdrop extends StatefulWidget {
  final Widget child;
  final Gradient gradient;
  const AnimatedBackdrop({super.key, required this.child, this.gradient = kHeroGradient});
  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: widget.gradient),
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _BlobPainter(_c.value)),
            ),
          ),
          widget.child,
        ]),
      );
}

/// Bandeau d'accueil avec ECG animé.
class HeroBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const HeroBanner({super.key, required this.title, required this.subtitle, this.trailing});
  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Reveal(
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: kHeroGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: cDark.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(painter: _BlobPainter(_c.value)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 70,
              child: Opacity(
                opacity: 0.55,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(painter: EcgPainter(_c.value, cMint)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 56),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(widget.subtitle, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85))),
                  ]),
                ),
                if (widget.trailing != null) widget.trailing!,
              ]),
            ),
          ]),
        ),
      );
}

class LogoMark extends StatelessWidget {
  final double size;
  final bool onDark;
  const LogoMark({super.key, this.size = 36, this.onDark = true});
  @override
  Widget build(BuildContext context) => Image.asset(
        onDark ? 'assets/images/logo_white.png' : 'assets/images/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      );
}

// ---------------------------------------------------------------------------
// Sélecteur de langue FR / EN (un seul clic, toute l'application)
// ---------------------------------------------------------------------------

class LangToggle extends StatelessWidget {
  final bool onDark;
  const LangToggle({super.key, this.onDark = true});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: l10n,
        builder: (context, _) {
          final en = l10n.en;
          final off = onDark ? Colors.white : cDark;
          return Tooltip(
            message: en ? 'Passer en français' : 'Switch to English',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: l10n.toggle,
                child: Container(
                  width: 92,
                  height: 36,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: onDark ? Colors.white.withOpacity(0.18) : cDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      alignment: en ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 43,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: kGoldGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Row(children: [
                      Expanded(
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: en ? off : cDark),
                            child: const Text('FR'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: en ? cDark : off),
                            child: const Text('EN'),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          );
        },
      );
}

// ---------------------------------------------------------------------------
// Chargement (squelettes animés) et erreurs
// ---------------------------------------------------------------------------

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox();
  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: cMid.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: 0.45 + 0.55 * _c.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: cMid.withOpacity(0.12), shape: BoxShape.circle)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _bar(160, 14),
                  const SizedBox(height: 10),
                  _bar(double.infinity, 11),
                  const SizedBox(height: 6),
                  _bar(110, 11),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: const [_SkeletonBox(), _SkeletonBox(), _SkeletonBox(), _SkeletonBox()],
      );
}

class Load<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback) builder;
  const Load({super.key, required this.load, required this.builder});
  @override
  State<Load<T>> createState() => _LoadState<T>();
}

class _LoadState<T> extends State<Load<T>> {
  late Future<T> f = widget.load();
  void reload() => setState(() => f = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const SkeletonList();
          }
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Reveal(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off_rounded, size: 56, color: cMid.withOpacity(0.6)),
                    const SizedBox(height: 12),
                    Text(tr('${s.error}'), textAlign: TextAlign.center, style: const TextStyle(color: cMuted)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr("Réessayer")),
                    ),
                  ]),
                ),
              ),
            );
          }
          return widget.builder(c, s.data as T, reload);
        },
      );
}

// ---------------------------------------------------------------------------
// Coque de navigation (barre du haut, onglets, rail sur grand écran)
// ---------------------------------------------------------------------------

class TabDef {
  final String label;
  final IconData icon;
  final Widget page;
  /// true : page de formulaire/discussion, centrée et limitée à 860 px ; false : pleine largeur.
  final bool narrow;
  const TabDef(this.label, this.icon, this.page, {this.narrow = false});
}

/// Permet à un écran enfant de changer d'onglet : ShellScope.of(context)?.go(1)
class ShellScope extends InheritedWidget {
  final void Function(int) go;
  const ShellScope({super.key, required this.go, required super.child});
  static ShellScope? of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ShellScope>();
  @override
  bool updateShouldNotify(ShellScope old) => false;
}

class Shell extends StatefulWidget {
  final String title;
  final List<TabDef> tabs;
  const Shell({super.key, required this.title, required this.tabs});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  int unread = 0;
  Timer? _unreadTimer;
  void go(int v) => setState(() => i = v);

  @override
  void initState() {
    super.initState();
    _checkUnread();
    _unreadTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkUnread());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    web.document.title = 'DoktaNet';
    super.dispose();
  }

  Future<void> _checkUnread() async {
    try {
      final r = await Api.get('/me/unread');
      final n = int.tryParse('${r['count']}') ?? 0;
      if (!mounted) return;
      if (n > unread) toast(context, tr("Nouveau message reçu. Ouvrez Messages dans votre rendez-vous."));
      web.document.title = n > 0 ? '($n) DoktaNet' : 'DoktaNet';
      if (n != unread) setState(() => unread = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 840;
    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(i),
        child: widget.tabs[i].narrow
            ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: widget.tabs[i].page))
            : widget.tabs[i].page,
      ),
    );
    final body = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2EFF4), cBg],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: WaxPainter(color: cMid, opacity: 0.045, cell: 150))),
          ),
        ),
        ShellScope(go: go, child: page),
      ]),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(6), child: KenteBar()),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
        titleSpacing: 16,
        title: Row(children: [
          const LogoMark(size: 38),
          const SizedBox(width: 12),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('DoktaNet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(tr(widget.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
            ]),
          ),
        ]),
        actions: [
          const InstallButton(),
          const LangToggle(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr("Mon compte"),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage())),
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
          IconButton(
            tooltip: tr("Déconnexion"),
            onPressed: session.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: i,
                onDestinationSelected: go,
                backgroundColor: Colors.white,
                indicatorColor: cMid.withOpacity(0.16),
                selectedIconTheme: const IconThemeData(color: cMid),
                selectedLabelTextStyle: const TextStyle(color: cMid, fontWeight: FontWeight.w700),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final t in widget.tabs)
                    NavigationRailDestination(icon: Icon(t.icon), label: Text(tr(t.label))),
                ],
              ),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: i,
              onDestinationSelected: go,
              destinations: [
                for (final t in widget.tabs) NavigationDestination(icon: Icon(t.icon), label: tr(t.label)),
              ],
            ),
    );
  }
}

Future<void> openRoom(BuildContext c, String id) async {
  // iOS/Android bloquent window.open apres un await : on ouvre l'onglet
  // immediatement au clic, puis on lui donne l'adresse une fois connue.
  web.Window? pre;
  web.Window? preOpen() {
    try {
      return web.window.open('about:blank', '_blank');
    } catch (_) {
      return null;
    }
  }

  final audio = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(tr("Rejoindre la consultation")),
      content: Text(tr("Autorisez le micro et la caméra dans le navigateur. Connexion faible : choisissez Audio seul.")),
      actions: [
        TextButton(
          onPressed: () {
            pre = preOpen();
            Navigator.pop(d, true);
          },
          child: Text(tr("Audio seul")),
        ),
        ElevatedButton(
          onPressed: () {
            pre = preOpen();
            Navigator.pop(d, false);
          },
          child: Text(tr("Vidéo")),
        ),
      ],
    ),
  );
  if (audio == null || !c.mounted) {
    pre?.close();
    return;
  }
  await guard(c, () async {
    try {
      final r = await Api.post('/appointments/$id/room');
      var url = r['url'] as String;
      if (url.contains('meet.jit.si')) {
        // Reste dans le navigateur (pas d'appli a installer), saute la page de pre-connexion,
        // prenom pre-rempli : un seul clic pour entrer dans la meme salle.
        final name = '${session.user?['full_name'] ?? ''}'.trim();
        final dn = name.isEmpty ? '' : '&userInfo.displayName=${Uri.encodeComponent(jsonEncode(name))}';
        url += '#config.disableDeepLinking=true&config.prejoinConfig.enabled=false&config.prejoinPageEnabled=false'
            '&config.startWithAudioMuted=false$dn';
        if (audio) url += '&config.startAudioOnly=true&config.startWithVideoMuted=true';
      }
      if (pre != null) {
        pre!.location.href = url;
      } else {
        await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      }
    } catch (e) {
      pre?.close();
      rethrow;
    }
  });
}

/// Choisit une photo (galerie ou appareil photo), la reduit et la renvoie en data URL.
Future<String?> pickAvatarDataUrl() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 80);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (bytes.length > 280000) throw ApiException('Image trop lourde');
  final n = x.name.toLowerCase();
  final mt = (x.mimeType != null && x.mimeType!.startsWith('image/'))
      ? x.mimeType!
      : (n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
  return 'data:$mt;base64,${base64Encode(bytes)}';
}

Future<void> openPrint(String id) => launchUrl(Api.printUrl(id), webOnlyWindowName: '_blank');

/// Barre d'application dégradée pour les écrans secondaires.
PreferredSizeWidget gradientAppBar(String title) => AppBar(
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      actions: const [LangToggle(), SizedBox(width: 12)],
    );

/// Centre et limite la largeur du contenu sur grand écran.
Widget pageWrap(Widget child, {double maxWidth = 900}) =>
    Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));


/// Grille adaptative : 1 colonne sur mobile, 2, 3 ou 4 colonnes selon la largeur disponible.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTile;
  final double gap;
  const ResponsiveGrid({super.key, required this.children, this.minTile = 440, this.gap = 14});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        var cols = ((w + gap) / (minTile + gap)).floor();
        if (cols < 1) cols = 1;
        if (cols > 4) cols = 4;
        final tile = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 0,
          children: [for (final ch in children) SizedBox(width: tile, child: ch)],
        );
      });
}


/// Marge horizontale des pages : plus large sur grand écran.
double hPad(BuildContext context) => MediaQuery.of(context).size.width >= 840 ? 28.0 : 16.0;
