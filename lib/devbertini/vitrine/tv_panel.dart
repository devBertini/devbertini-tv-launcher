/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 */

import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/vitrine/focus.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/tv_input.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/widgets/app_card_keys.dart';
import 'package:flauncher/widgets/settings/inputs_panel.dart';
import 'package:flauncher/widgets/side_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The rail's TV (docs/devbertini/DESIGN-VITRINE.md, "Remote"): the devices plugged in over HDMI-CEC with their
/// state, then the TV's own functions that left the home (Entradas, Imagem, Som, Modo jogo, Painel rápido, Energia),
/// in a side panel on the right. Only a TV with inputs of its own has the rail's TV item; the box has none.
class VitrineTvPanel extends StatelessWidget {
  const VitrineTvPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final devices = context.select<TvInputsService?, List<TvInput>>((inputs) => inputs?.devices ?? const []);
    final label = vitrineText(15, weight: 600, line: 18, color: t.ink);
    return SidePanelDialog(
      width: 384,
      // On the left, where the rail that opens it is.
      isRightSide: false,
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 32, 8),
          children: [
            Text('TV', style: vitrineText(26, weight: 500, line: 32, tracking: -0.5, color: t.ink)),
            if (devices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(pt ? 'Aparelhos' : 'Devices', style: label),
              const SizedBox(height: 8),
              for (final (index, device) in devices.indexed)
                VitrinePanelRow(
                  key: ValueKey('device:${device.id}'),
                  icon: Icons.sports_esports_rounded,
                  title: device.label,
                  detail: device.on ? (pt ? 'Ligado' : 'On') : (pt ? 'Em espera' : 'Standby'),
                  autofocus: index == 0,
                  onPressed: () {
                    devBertiniStartLaunch();
                    context.read<TvInputsService>().switchInput(device.id);
                    Navigator.of(context).maybePop();
                  },
                ),
            ],
            const SizedBox(height: 20),
            Text(pt ? 'Ajustes da TV' : 'TV settings', style: label),
            const SizedBox(height: 8),
            for (final (index, control) in TvControl.all.indexed)
              VitrinePanelRow(
                key: ValueKey('control:${control.id}'),
                icon: control.icon,
                title: pt ? control.labelPt : control.labelEn,
                autofocus: devices.isEmpty && index == 0,
                onPressed: () => _open(context, control),
              ),
          ],
        ),
      ),
    );
  }

  /// Entradas opens the inputs panel over this one; the other functions are the TV's own screens, so the panel
  /// closes first and the TV draws them over the home.
  void _open(BuildContext context, TvControl control) {
    if (control.id == 'inputs') {
      showDialog(context: context, builder: (_) => const InputsPanel());
      return;
    }
    final apps = context.read<AppsService>();
    Navigator.of(context).maybePop();
    apps.launchTvControl(control.id);
  }
}

/// One row of a Vitrine side panel: icon, title and, when given, a detail on the right. Focused it takes the plate
/// colour and the accent ring (no scale: a row is as wide as the panel); OK calls [onPressed].
class VitrinePanelRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final bool autofocus;
  final VoidCallback onPressed;

  const VitrinePanelRow({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.autofocus = false,
    required this.onPressed,
  });

  @override
  State<VitrinePanelRow> createState() => _VitrinePanelRowState();
}

class _VitrinePanelRowState extends State<VitrinePanelRow> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && AppCardKeys.validationKeys.contains(event.logicalKey)) {
      widget.onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        label: widget.title,
        child: Focus(
          autofocus: widget.autofocus,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: VitrineFocusFrame(
              focused: _focused,
              radius: 10,
              scale: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _focused ? t.plate : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 18, color: _focused ? t.ink : t.ink2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: vitrineText(14, weight: _focused ? 600 : 500, color: t.ink),
                      ),
                    ),
                    if (widget.detail != null)
                      Text(widget.detail!, style: vitrineText(12, weight: 500, color: t.ink2)),
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
