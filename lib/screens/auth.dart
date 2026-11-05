import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';
import '../i18n.dart';
import '../session.dart';
import '../install.dart';
import '../photos.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool reg = false, busy = false, consent = false, showPwd = false, need2fa = false;
  String role = 'patient';
  String? photo;
  final _c = <String, TextEditingController>{};
  TextEditingController c(String k) => _c.putIfAbsent(k, () => TextEditingController());

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    await guard(context, () async {
      if (!reg) {
        final needs = await session.login(c('email').text.trim(), c('password').text,
            code: need2fa ? c('code').text.trim() : null);
        if (needs && mounted) setState(() => need2fa = true);
        return;
      }
      if (!consent) throw ApiException('Consentement requis');
      await session.register({
        'role': role,
        'email': c('email').text.trim(),
        'password': c('password').text,
        'full_name': c('name').text.trim(),
        'phone': c('phone').text.trim(),
        'consent': true,
        'order_number': c('order').text.trim(),
        'specialty': c('specialty').text.trim(),
        'city': c('city').text.trim(),
        'fee': int.tryParse(c('fee').text.trim()) ?? 5000,
        'pharmacy_name': c('pname').text.trim(),
        'license_number': c('license').text.trim(),
        'address': c('address').text.trim(),
        if (photo != null) 'avatar': photo,
      });
    });
    if (mounted) setState(() => busy = false);
  }

  // ---- Panneau d'accueil (identité visuelle) ----
  Widget _hero({required bool compact}) {
    final feats = <List<Object>>[
      [Icons.videocam_rounded, "Consultation vidéo ou audio, même en 3G"],
      [Icons.description_rounded, "Ordonnance numérique signée par le médecin"],
      [Icons.local_pharmacy_rounded, "Pharmacies partenaires près de chez vous"],
      [Icons.chat_bubble_rounded, "Assistant IA pour vous orienter"],
      [Icons.phone_android_rounded, "Paiement par T-Money et Flooz"],
    ];
    return Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Reveal(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoMark(size: 52),
              SizedBox(width: 14),
              Text('DoktaNet',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
            ],
          ),
        ),
        SizedBox(height: compact ? 12 : 30),
        Reveal(
          index: 1,
          child: Text(
            tr("Consultez un médecin, recevez vos médicaments."),
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: compact ? 20 : 38,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 14),
          Reveal(
            index: 2,
            child: Text(
              tr("La santé connectée au Togo : un médecin à portée de main, où que vous soyez."),
              style: TextStyle(fontSize: 17, height: 1.4, color: Colors.white.withOpacity(0.82)),
            ),
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < feats.length; i++)
            Reveal(
              index: 3 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Icon(feats[i][0] as IconData, color: cMint, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(tr(feats[i][1] as String),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _roleTile(String value, IconData icon, String label) {
    final sel = role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => role = value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: sel ? kBrandGradient : null,
              color: sel ? null : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? Colors.transparent : cDark.withOpacity(0.14)),
              boxShadow: sel ? [BoxShadow(color: cMid.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))] : null,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(
                scale: sel ? 1.15 : 1,
                duration: const Duration(milliseconds: 250),
                child: Icon(icon, color: sel ? Colors.white : cMid, size: 26),
              ),
              const SizedBox(height: 6),
              Text(tr(label),
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : cDark)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _form() => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: cDark.withOpacity(0.18), blurRadius: 40, offset: const Offset(0, 18))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(reg),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reg ? tr("Créer mon compte") : tr("Bon retour !"),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: cDark)),
                const SizedBox(height: 4),
                Text(
                  reg ? tr("Rejoignez DoktaNet en quelques secondes.") : tr("Connectez-vous pour accéder à vos soins."),
                  style: const TextStyle(color: cMuted, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (reg) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    _roleTile('patient', Icons.favorite_rounded, "Patient"),
                    _roleTile('doctor', Icons.medical_services_rounded, "Médecin"),
                    _roleTile('pharmacy', Icons.local_pharmacy_rounded, "Pharmacien"),
                  ]),
                ),
                tf(c('name'), "Nom complet", icon: Icons.person_outline),
              ],
              tf(c('email'), "Email", type: TextInputType.emailAddress, icon: Icons.mail_outline),
              if (reg) tf(c('phone'), "Téléphone", type: TextInputType.phone, icon: Icons.phone_outlined),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: c('password'),
                  obscureText: !showPwd,
                  onSubmitted: (_) {
                    if (!busy) submit();
                  },
                  decoration: InputDecoration(
                    labelText: tr("Mot de passe (8 caractères min.)"),
                    prefixIcon: const Icon(Icons.lock_outline, color: cMid),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => showPwd = !showPwd),
                      icon: Icon(showPwd ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                ),
              ),
              if (!reg && need2fa)
                tf(c('code'), "Code 2FA (6 chiffres)", type: TextInputType.number, icon: Icons.shield_outlined),
              if (reg && (role == 'doctor' || role == 'pharmacy'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    photo == null
                        ? const CircleAvatar(radius: 32, backgroundColor: Color(0xFFE3EEF3), child: Icon(Icons.person_outline, size: 32, color: cMid))
                        : CircleAvatar(radius: 32, backgroundImage: MemoryImage(base64Decode(photo!.split(',').last))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(tr(photo == null ? "Ajouter une photo de profil" : "Changer la photo")),
                        onPressed: () => guard(context, () async {
                          final img = await pickAvatarDataUrl();
                          if (img != null && mounted) setState(() => photo = img);
                        }),
                      ),
                    ),
                  ]),
                ),
              if (reg && role == 'doctor') ...[
                tf(c('order'), "Numéro d'ordre des médecins", icon: Icons.badge_outlined),
                tf(c('specialty'), "Spécialité (ex : Médecine générale)", icon: Icons.medical_information_outlined),
                tf(c('city'), "Ville", icon: Icons.location_city_outlined),
                tf(c('fee'), "Tarif consultation (FCFA)", type: TextInputType.number, icon: Icons.payments_outlined),
              ],
              if (reg && role == 'pharmacy') ...[
                tf(c('pname'), "Nom de la pharmacie", icon: Icons.storefront_outlined),
                tf(c('license'), "Licence d'exploitation", icon: Icons.verified_outlined),
                tf(c('city'), "Ville", icon: Icons.location_city_outlined),
                tf(c('address'), "Adresse", icon: Icons.place_outlined),
              ],
              if (reg)
                CheckboxListTile(
                  value: consent,
                  onChanged: (v) => setState(() => consent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: cMid,
                  title: Text(tr("Je consens au traitement de mes données personnelles (loi n°2019-014)."),
                      style: const TextStyle(fontSize: 14)),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            reg ? "Créer mon compte" : "Se connecter",
            icon: reg ? Icons.rocket_launch_rounded : Icons.login_rounded,
            busy: busy,
            onPressed: submit,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => reg = !reg),
            child: Text(reg ? tr("J'ai déjà un compte") : tr("Créer un compte")),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 900;
          if (wide) {
            return Scaffold(
              body: Row(children: [
                Expanded(
                  flex: 5,
                  child: PhotoBackdrop(
                    overlay: 0.72,
                    child: Stack(children: [
                      const Positioned(left: 0, right: 0, bottom: 0, height: 110, child: _EcgStrip()),
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(64, 40, 48, 120),
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _hero(compact: false)),
                        ),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    color: cBg,
                    child: Stack(children: [
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Reveal(dy: 40, child: _form()),
                          ),
                        ),
                      ),
                      const Positioned(top: 18, right: 18, child: Row(mainAxisSize: MainAxisSize.min, children: [InstallButton(onDark: false), LangToggle(onDark: false)])),
                    ]),
                  ),
                ),
              ]),
            );
          }
          return Scaffold(
            body: Stack(children: [
              PhotoBackdrop(
                overlay: 0.55,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, (box.maxHeight * 0.06).clamp(36.0, 64.0).toDouble(), 20, 28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          _hero(compact: true),
                          SizedBox(height: reg ? 22 : (box.maxHeight * 0.2).clamp(22.0, 170.0).toDouble()),
                          Reveal(dy: 40, index: 2, child: _form()),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(top: 12, right: 12, child: SafeArea(child: Row(mainAxisSize: MainAxisSize.min, children: [InstallButton(), LangToggle()]))),
            ]),
          );
        },
      );
}

/// Bande ECG animée en bas du panneau d'accueil.
class _EcgStrip extends StatefulWidget {
  const _EcgStrip();
  @override
  State<_EcgStrip> createState() => _EcgStripState();
}

class _EcgStripState extends State<_EcgStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.6,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: EcgPainter(_c.value, cMint)),
        ),
      );
}

class PendingScreen extends StatelessWidget {
  final String status;
  const PendingScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'rejected';
    return Scaffold(
      body: Stack(children: [
        PhotoBackdrop(
          photos: const [Photos.team],
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Reveal(
                  dy: 40,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: cDark.withOpacity(0.25), blurRadius: 40, offset: const Offset(0, 18))],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.5, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        builder: (context, v, child) => Transform.scale(scale: v, child: child),
                        child: IconBadge(
                          rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                          gradient: rejected
                              ? const LinearGradient(colors: [Color(0xFFD64545), Color(0xFFEF8354)])
                              : kGoldGradient,
                          size: 76,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        rejected
                            ? tr("Votre inscription a été refusée. Contactez l'équipe DoktaNet.")
                            : tr("Compte en attente de validation par l'administrateur."),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cDark),
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton("Actualiser", icon: Icons.refresh_rounded, onPressed: () => guard(context, session.refresh)),
                      const SizedBox(height: 6),
                      TextButton(onPressed: session.logout, child: Text(tr("Déconnexion"))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(top: 12, right: 12, child: SafeArea(child: Row(mainAxisSize: MainAxisSize.min, children: [InstallButton(), LangToggle()]))),
      ]),
    );
  }
}
