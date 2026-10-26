/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 *
 * The profiles panel the Vitrine rail opens: pick a profile, add one, and rename, recolour or delete the one
 * selected.
 */

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A profile's round avatar: its colour and the first letter of its name.
class ProfileAvatar extends StatelessWidget {
  final LauncherProfile profile;
  final double size;
  final bool focused;

  const ProfileAvatar({super.key, required this.profile, this.size = 64, this.focused = false});

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: profile.colour,
        shape: BoxShape.circle,
        // A cream ring marks the focus; no glow, which lights a hazy block on the Mini LED panel.
        border: Border.all(color: focused ? palette.focusFill : Colors.transparent, width: size * 0.05),
      ),
      alignment: Alignment.center,
      child: Text(
        profile.initial,
        style: TextStyle(fontSize: size * 0.44, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0),
      ),
    );
  }
}

/// The profiles panel, in the middle of the screen.
class CinematicProfilesPanel extends StatefulWidget {
  const CinematicProfilesPanel({super.key});

  @override
  State<CinematicProfilesPanel> createState() => _CinematicProfilesPanelState();
}

class _CinematicProfilesPanelState extends State<CinematicProfilesPanel> {
  String? _selectedId;
  String? _opening;

  Future<String?> _askName({String initial = ''}) => showDialog<String>(
        context: context,
        barrierColor: const Color(0x99000000),
        builder: (_) => _NameDialog(initial: initial),
      );

  Future<void> _add(ProfilesController profiles) async {
    final name = await _askName();
    if (name == null || name.trim().isEmpty) return;
    final profile = await profiles.create(name);
    if (mounted) setState(() => _selectedId = profile.id);
  }

  Future<void> _open(ProfilesController profiles, LauncherProfile profile) async {
    if (profile.id == profiles.current.id) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _opening = profile.name);
    // Let the message show before the launcher restarts on the new profile.
    await Future.delayed(const Duration(milliseconds: 600));
    await profiles.switchTo(profile);
    if (mounted) setState(() => _opening = null);
  }

  Future<void> _delete(ProfilesController profiles, LauncherProfile profile) async {
    final sure = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (_) => _ConfirmDialog(text: 'Apagar o perfil ${profile.name}? A ordem dos apps e os ajustes dele somem.'),
    );
    if (sure == true) {
      await profiles.delete(profile);
      if (mounted) setState(() => _selectedId = profiles.current.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfilesController>();
    final palette = CinematicThemeScope.of(context);
    final selected = profiles.profiles.firstWhere(
      (p) => p.id == (_selectedId ?? profiles.current.id),
      orElse: () => profiles.current,
    );
    final canDelete = selected.id != mainProfileId && selected.id != profiles.current.id;
    // As wide as its avatars need (102 each, then the add tile), so the panel never ends half empty.
    final width = (56 + 102.0 * profiles.profiles.length + 84).clamp(480.0, 640.0);

    // On the left, where the rail's avatar that opens it sits, as every panel the rail opens.
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, top: 60),
        child: Material(
          color: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0x26FFFFFF))),
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: _opening != null
                ? SizedBox(
                    height: 150,
                    child: Center(
                      child: Text('Abrindo o perfil $_opening...',
                          style: const TextStyle(fontSize: 18, color: DevBertiniColors.ink)),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Perfis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: DevBertiniColors.ink)),
                      const SizedBox(height: 4),
                      const Text(
                        'Cada perfil guarda a ordem dos apps, a aparência e os ajustes.',
                        style: TextStyle(fontSize: 13, color: Color(0x99FFFFFF)),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 118,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          children: [
                            for (final profile in profiles.profiles)
                              _ProfileTile(
                                profile: profile,
                                current: profile.id == profiles.current.id,
                                autofocus: profile.id == profiles.current.id,
                                onFocus: () => setState(() => _selectedId = profile.id),
                                onPressed: () => _open(profiles, profile),
                              ),
                            _AddTile(onPressed: () => _add(profiles)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        selected.id == profiles.current.id ? '${selected.name}, em uso' : selected.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.caption),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ActionChip(
                            icon: Icons.edit_outlined,
                            label: 'Renomear',
                            onPressed: () async {
                              final name = await _askName(initial: selected.name);
                              if (name != null) await profiles.rename(selected, name);
                            },
                          ),
                          const SizedBox(width: 10),
                          _ActionChip(
                            icon: Icons.palette_outlined,
                            label: 'Trocar cor',
                            onPressed: () => profiles.nextColour(selected),
                          ),
                          if (canDelete) ...[
                            const SizedBox(width: 10),
                            _ActionChip(
                              icon: Icons.delete_outline_rounded,
                              label: 'Apagar',
                              onPressed: () => _delete(profiles, selected),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  final LauncherProfile profile;
  final bool current;
  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onPressed;

  const _ProfileTile({
    required this.profile,
    required this.current,
    required this.autofocus,
    required this.onFocus,
    required this.onPressed,
  });

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
        },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            if (focused) widget.onFocus();
          },
          child: HoverFocus(
            child: GestureDetector(
              onTap: widget.onPressed,
              child: SizedBox(
                width: 84,
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: _focused ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: ProfileAvatar(profile: widget.profile, size: 68, focused: _focused),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.current ? FontWeight.w700 : FontWeight.w500,
                        color: _focused ? palette.focusFill : DevBertiniColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddTile({required this.onPressed});

  @override
  State<_AddTile> createState() => _AddTileState();
}

class _AddTileState extends State<_AddTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: HoverFocus(
          child: GestureDetector(
            onTap: widget.onPressed,
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _focused ? palette.focusFill : Colors.transparent,
                      border: Border.all(color: _focused ? palette.focusFill : const Color(0x4DFFFFFF), width: 2),
                    ),
                    child: Icon(Icons.add_rounded, size: 30, color: _focused ? palette.focusInk : const Color(0xB3FFFFFF)),
                  ),
                  const SizedBox(height: 8),
                  Text('Novo perfil',
                      style: TextStyle(fontSize: 13, color: _focused ? palette.focusFill : const Color(0xB3FFFFFF))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  const _ActionChip({required this.icon, required this.label, required this.onPressed, this.autofocus = false});

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    final ink = _focused ? palette.focusInk : const Color(0xD9FFFFFF);
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: HoverFocus(
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _focused ? palette.focusFill : Colors.black,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _focused ? palette.focusFill : const Color(0x33FFFFFF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: ink),
                  const SizedBox(width: 6),
                  Text(widget.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a profile's name; the TV shows its own keyboard for the field.
class _NameDialog extends StatefulWidget {
  final String initial;

  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CinematicThemeScope.of(context);
    return Center(
      child: Material(
        color: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x26FFFFFF))),
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nome do perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DevBertiniColors.ink)),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                maxLength: 16,
                cursorColor: palette.focusFill,
                style: const TextStyle(fontSize: 16, color: DevBertiniColors.ink),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Por exemplo: Ana',
                  hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0x4DFFFFFF))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.focusFill, width: 2)),
                ),
                onSubmitted: (value) => Navigator.of(context).pop(value),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: _ActionChip(
                  icon: Icons.check_rounded,
                  label: 'Salvar',
                  onPressed: () => Navigator.of(context).pop(_text.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String text;

  const _ConfirmDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x26FFFFFF))),
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 15, color: DevBertiniColors.ink, height: 1.35)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // The focus starts on Cancelar, so a hurried OK does not delete.
                  _ActionChip(icon: Icons.close_rounded, label: 'Cancelar', autofocus: true, onPressed: () => Navigator.of(context).pop(false)),
                  const SizedBox(width: 10),
                  _ActionChip(icon: Icons.delete_outline_rounded, label: 'Apagar', onPressed: () => Navigator.of(context).pop(true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
