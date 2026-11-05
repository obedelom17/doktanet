import 'package:flutter/material.dart';
import '../api.dart';
import '../common.dart';
import '../i18n.dart';
import '../install.dart';
import '../session.dart';
import '../theme.dart';

/// Mon compte : 2FA (TOTP), mot de passe, signalement d'un problème.
class AccountPage extends StatefulWidget {
  final bool forced;
  const AccountPage({super.key, this.forced = false});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final code = TextEditingController();
  final cur = TextEditingController();
  final nw = TextEditingController();
  final reason = TextEditingController();
  String? secret;

  bool get enabled => session.user?['totp_enabled'] == true;

  String _group(String s) =>
      [for (var i = 0; i < s.length; i += 4) s.substring(i, i + 4 > s.length ? s.length : i + 4)].join(' ');

  Future<void> _changePhoto() => guard(context, () async {
        final img = await pickAvatarDataUrl();
        if (img == null) return;
        await Api.post('/me/avatar', {'image': img});
        await session.refresh();
        if (mounted) {
          setState(() {});
          toast(context, tr("Photo mise à jour"));
        }
      });

  Future<void> _removePhoto() => guard(context, () async {
        await Api.post('/me/avatar/delete');
        await session.refresh();
        if (mounted) setState(() {});
      });

  Future<void> _setup() => guard(context, () async {
        final r = await Api.post('/me/2fa/setup');
        if (mounted) setState(() => secret = '${r['secret']}');
      });

  Future<void> _enable() => guard(context, () async {
        await Api.post('/me/2fa/enable', {'code': code.text.trim()});
        code.clear();
        secret = null;
        await session.refresh();
        if (mounted) {
          setState(() {});
          toast(context, tr("2FA activée"));
        }
      });

  Future<void> _disable() async {
    final pw = TextEditingController();
    final cd = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr("Désactiver la 2FA")),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tf(pw, "Mot de passe actuel", obscure: true),
            tf(cd, "Code 2FA (6 chiffres)", type: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr("Annuler"))),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("Désactiver"))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await guard(context, () async {
      await Api.post('/me/2fa/disable', {'password': pw.text, 'code': cd.text.trim()});
      await session.refresh();
      if (mounted) {
        setState(() {});
        toast(context, tr("2FA désactivée"));
      }
    });
  }

  Future<void> _changePassword() => guard(context, () async {
        await Api.post('/me/password', {'current': cur.text, 'next': nw.text});
        cur.clear();
        nw.clear();
        if (mounted) toast(context, tr("Mot de passe modifié"));
      });

  Future<void> _report() => guard(context, () async {
        await Api.post('/reports', {'reason': reason.text.trim()});
        reason.clear();
        if (mounted) toast(context, tr("Signalement envoyé"));
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: gradientAppBar(tr("Mon compte")),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE2EFF4), cBg]),
          ),
          child: pageWrap(
            ListView(padding: const EdgeInsets.all(16), children: [
              if (widget.forced)
                AppCard(
                  child: Text(
                    tr("L'authentification à deux facteurs est obligatoire pour votre rôle. Activez-la pour continuer."),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: cDark),
                  ),
                ),
              if (session.user?['role'] == 'doctor' || session.user?['role'] == 'pharmacy') ...[
                sectionTitle("Photo de profil", icon: Icons.account_circle_outlined),
                AppCard(
                  child: Row(children: [
                    InitialsAvatar('${session.user?['full_name']}',
                        size: 72, userId: '${session.user?['id']}', ver: int.tryParse('${session.user?['avatar_v']}') ?? 0),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        PrimaryButton("Changer la photo", icon: Icons.photo_camera_outlined, expand: false, onPressed: _changePhoto),
                        if ((int.tryParse('${session.user?['avatar_v']}') ?? 0) > 0)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _removePhoto,
                            label: Text(tr("Supprimer")),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ],
              sectionTitle("Application", icon: Icons.install_mobile_rounded),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Ajoutez DoktaNet à votre écran d'accueil pour y accéder en un geste, en plein écran.")),
                  const SizedBox(height: 12),
                  PrimaryButton("Installer l'application", icon: Icons.download_rounded, onPressed: openInstallPrompt),
                ]),
              ),
              sectionTitle("Authentification à deux facteurs", icon: Icons.shield_outlined),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(enabled ? Icons.verified_user_rounded : Icons.gpp_maybe_outlined, color: enabled ? cMid : cAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(enabled ? tr("2FA activée") : tr("2FA désactivée"),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: cDark)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (enabled && !widget.forced)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _disable,
                      label: Text(tr("Désactiver la 2FA")),
                    ),
                  if (!enabled && secret == null) PrimaryButton("Activer la 2FA", icon: Icons.shield_outlined, onPressed: _setup),
                  if (!enabled && secret != null) ...[
                    Text(tr("Dans votre application d'authentification (Google Authenticator, Authy...), ajoutez un compte avec cette clé :")),
                    const SizedBox(height: 10),
                    SelectableText(
                      _group(secret!),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: cDark),
                    ),
                    const SizedBox(height: 14),
                    tf(code, "Code à 6 chiffres", type: TextInputType.number, icon: Icons.pin_outlined),
                    PrimaryButton("Confirmer et activer", icon: Icons.check_circle_outline, onPressed: _enable),
                  ],
                ]),
              ),
              sectionTitle("Mot de passe", icon: Icons.lock_outline),
              AppCard(
                child: Column(children: [
                  tf(cur, "Mot de passe actuel", obscure: true),
                  tf(nw, "Nouveau mot de passe (8 caractères min.)", obscure: true),
                  PrimaryButton("Changer le mot de passe", icon: Icons.save_outlined, onPressed: _changePassword),
                ]),
              ),
              sectionTitle("Signaler un problème", icon: Icons.flag_outlined),
              AppCard(
                child: Column(children: [
                  tf(reason, "Décrivez le problème", lines: 4),
                  PrimaryButton("Envoyer le signalement", icon: Icons.send_rounded, onPressed: _report),
                ]),
              ),
              if (widget.forced) TextButton(onPressed: session.logout, child: Text(tr("Déconnexion"))),
            ]),
          ),
        ),
      );
}
