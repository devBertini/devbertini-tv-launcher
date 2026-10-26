/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 *
 * The launcher's settings (the gear) and the network panel (the Wi-Fi icon) in the DevBertini look:
 * true black, grouped, each row saying what it holds, the focused row cream with black text.
 */

import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/devbertini_intro.dart';
import 'package:flauncher/devbertini/vitrine/appearance_page.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/accessibility_page.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/display_settings_page.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/notifications_settings_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

/// The first page of the gear's panel: five groups, each a line saying what it holds; OK opens the group,
/// Back returns. It fits the screen without scrolling.
class CinematicSettingsPage extends StatelessWidget {
  const CinematicSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    void open(String title, List<Widget> tiles) => navigator.push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 160),
            reverseTransitionDuration: const Duration(milliseconds: 120),
            pageBuilder: (_, _, _) => _SettingsGroupPage(title: title, tiles: tiles),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
    return _SettingsColumn(
      title: 'Configurações',
      children: [
        DevBertiniTile(
          icon: Icons.apps_rounded,
          title: 'Aplicativos',
          subtitle: 'Ordem, ocultos e categorias',
          autofocus: true,
          onPressed: () => navigator.pushNamed(ApplicationsPanelPage.routeName),
        ),
        DevBertiniTile(
          icon: Icons.home_outlined,
          title: 'Tela inicial',
          subtitle: 'Aparência, clima, modo noite',
          onPressed: () => open('Tela inicial', [
            _AppearanceTile(
              onPressed: () => navigator.push(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 160),
                  reverseTransitionDuration: const Duration(milliseconds: 120),
                  pageBuilder: (_, _, _) => const VitrineAppearancePage(),
                  transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
                ),
              ),
            ),
            DevBertiniTile(
              icon: Icons.view_agenda_outlined,
              title: _pt(context) ? 'Seções' : 'Sections',
              subtitle: _pt(context) ? 'Linhas e categorias da tela inicial' : 'Rows and categories of the home',
              onPressed: () => navigator.pushNamed(LauncherSectionsPanelPage.routeName),
            ),
            const _ScreenAreaTile(),
            const _ContinueWatchingTile(),
            const _WeatherTile(),
            const _NightModeTile(),
          ]),
        ),
        DevBertiniTile(
          icon: Icons.nights_stay_outlined,
          title: 'Protetor e energia',
          subtitle: 'Protetor de tela, desligar em',
          onPressed: () => open('Protetor e energia', const [_ScreensaverTile(autofocus: true), _SleepTimerTile()]),
        ),
        DevBertiniTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notificações',
          subtitle: 'Avisos e o que aparece',
          onPressed: () => navigator.pushNamed(NotificationsSettingsPage.routeName),
        ),
        DevBertiniTile(
          icon: Icons.tune_rounded,
          title: 'Sistema e TV',
          subtitle: 'Início, idioma, backup, TV',
          onPressed: () => open('Sistema e TV', [
            DevBertiniTile(
              icon: Icons.power_settings_new_rounded,
              title: 'Início e botões',
              subtitle: 'Abrir ao ligar e botão Home',
              autofocus: true,
              onPressed: () => navigator.pushNamed(AccessibilityPage.routeName),
            ),
            DevBertiniTile(
              icon: Icons.language_rounded,
              title: 'Sistema',
              subtitle: 'Idioma, data e hora, botão Voltar, backup',
              onPressed: () => navigator.pushNamed(GeneralSettingsPage.routeName),
            ),
            DevBertiniTile(
              icon: Icons.settings_suggest_rounded,
              title: 'Configurações da TV',
              trailing: Icons.open_in_new_rounded,
              onPressed: () => context.read<AppsService>().openSettings(),
            ),
            DevBertiniTile(
              icon: Icons.info_outline_rounded,
              title: 'Sobre',
              subtitle: 'Código aberto, GPL-3.0',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && snapshot.hasData
                      ? LTvLauncherAboutDialog(packageInfo: snapshot.data!)
                      : Container(),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

bool _pt(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'pt';

/// "Aparência": says which theme and accent are in force; OK opens the Aparência page.
class _AppearanceTile extends StatelessWidget {
  final VoidCallback onPressed;

  const _AppearanceTile({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final pt = _pt(context);
    final appearance = context.select<SettingsService, String>((settings) => settings.appearance);
    final theme = context.select<SettingsService, String>((settings) => settings.themes);
    final mode = switch (appearance) {
      appearanceLight => pt ? 'Claro' : 'Light',
      appearanceAuto => pt ? 'Automático' : 'Automatic',
      _ => pt ? 'Escuro' : 'Dark',
    };
    return DevBertiniTile(
      icon: Icons.palette_outlined,
      title: pt ? 'Aparência' : 'Appearance',
      subtitle: '$mode, ${CinematicPalette.of(theme).name}',
      autofocus: true,
      onPressed: onPressed,
    );
  }
}

/// A page of the panel: the studio's mark and the title, then its rows.
class _SettingsColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(dimension: 26, child: DevBertiniMark()),
              const SizedBox(width: 12),
              Text(title, style: vitrineText(22, weight: 700, color: VitrineTheme.of(context).ink)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// A group opened from the first page; Back returns to it.
class _SettingsGroupPage extends StatelessWidget {
  final String title;
  final List<Widget> tiles;

  const _SettingsGroupPage({required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: _SettingsColumn(title: title, children: tiles),
      );
}

/// Screen area, adjusted in place with left and right like a console's display area setting.
class _ScreenAreaTile extends StatelessWidget {
  const _ScreenAreaTile();

  @override
  Widget build(BuildContext context) {
    final area = context.select<SettingsService, double>((settings) => settings.screenArea);
    void step(int direction) {
      final next = (((area * 100).round() + direction * 2) / 100).clamp(devBertiniMinScreenArea, 1.0);
      context.read<SettingsService>().setScreenArea(next);
    }

    return DevBertiniTile(
      icon: Icons.fit_screen_rounded,
      title: 'Área da tela',
      subtitle: 'Margem preta em volta',
      onPressed: () {},
      onKey: (event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          step(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          step(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      value: DevBertiniStepperValue('${(area * 100).round()}%'),
    );
  }
}

/// "Continuar assistindo" under the apps, on or off; OK, left or right switch it.
class _ContinueWatchingTile extends StatelessWidget {
  const _ContinueWatchingTile();

  @override
  Widget build(BuildContext context) {
    final on = context.select<SettingsService, bool>((settings) => settings.showContinueWatching);
    void toggle() => context.read<SettingsService>().setShowContinueWatching(!on);
    return DevBertiniTile(
      icon: Icons.play_circle_outline_rounded,
      title: 'Continuar assistindo',
      subtitle: 'O destaque do topo e a fileira',
      onPressed: toggle,
      onKey: (event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) {
          toggle();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      value: DevBertiniStepperValue(on ? 'Sim' : 'Não'),
    );
  }
}

/// A yes or no tile switched with OK, left or right.
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({required this.icon, required this.title, required this.subtitle, required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DevBertiniTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onPressed: () => onChanged(!on),
      onKey: (event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onChanged(!on);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      value: DevBertiniStepperValue(on ? 'Sim' : 'Não'),
    );
  }
}

class _NightModeTile extends StatelessWidget {
  const _NightModeTile();

  @override
  Widget build(BuildContext context) {
    final on = context.select<NightModeService, bool>((night) => night.enabled);
    return _ToggleTile(
      icon: Icons.bedtime_outlined,
      title: 'Modo noite',
      subtitle: 'Das 22h às 6h',
      on: on,
      onChanged: context.read<NightModeService>().setEnabled,
    );
  }
}

class _WeatherTile extends StatelessWidget {
  const _WeatherTile();

  @override
  Widget build(BuildContext context) {
    final on = context.select<OpenMeteoService, bool>((weather) => weather.enabled);
    final city = context.read<OpenMeteoService>().place?.city;
    return _ToggleTile(
      icon: Icons.wb_cloudy_outlined,
      title: 'Clima',
      subtitle: city == null ? 'Sem cidade nesta versão' : '$city, Open-Meteo',
      on: on,
      onChanged: context.read<OpenMeteoService>().setEnabled,
    );
  }
}

/// "Desligar em": left and right step through the minutes; the value turns into the standby time.
class _SleepTimerTile extends StatelessWidget {
  const _SleepTimerTile();

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<SleepTimerService>();
    final at = timer.at;
    void step(int direction) {
      final steps = SleepTimerService.steps;
      final index = steps.indexOf(timer.minutes);
      timer.set(steps[((index < 0 ? 0 : index) + direction).clamp(0, steps.length - 1)]);
    }

    return DevBertiniTile(
      icon: Icons.timer_outlined,
      title: 'Desligar em',
      subtitle: at == null ? 'Standby automático' : 'Às ${DateFormat('H:mm').format(at)}',
      onPressed: () => step(1),
      onKey: (event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          step(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          step(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      value: DevBertiniStepperValue(timer.minutes == 0 ? 'Não' : '${timer.minutes} min'),
    );
  }
}

/// The devBertini screensaver's wait, adjusted in place with left and right; OK opens the TV's own
/// screen settings.
class _ScreensaverTile extends StatelessWidget {
  final bool autofocus;

  const _ScreensaverTile({this.autofocus = false});

  static const List<int> _steps = [0, 2, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    final minutes = context.select<SettingsService, int>((settings) => settings.devBertiniSaverMinutes);
    void step(int direction) {
      final index = _steps.indexOf(minutes);
      final next = _steps[((index < 0 ? 2 : index) + direction).clamp(0, _steps.length - 1)];
      context.read<SettingsService>().setDevBertiniSaverMinutes(next);
    }

    return DevBertiniTile(
      icon: Icons.nights_stay_outlined,
      title: 'Protetor de tela',
      autofocus: autofocus,
      subtitle: 'Relógio devBertini no preto',
      onPressed: () => Navigator.of(context).pushNamed(DisplaySettingsPage.routeName),
      onKey: (event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          step(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          step(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      value: DevBertiniStepperValue(minutes == 0 ? 'Não' : '$minutes min'),
    );
  }
}

/// The network panel under the Wi-Fi icon: what the connection is doing, and the system's network page.
class CinematicNetworkPanel extends StatelessWidget {
  const CinematicNetworkPanel({super.key});

  static IconData iconFor(NetworkService network) {
    switch (network.networkType) {
      case NetworkType.Wired:
        return Icons.settings_ethernet_rounded;
      case NetworkType.Wifi:
        final level = network.wirelessNetworkSignalLevel;
        if (level <= 1) return Icons.wifi_1_bar_rounded;
        if (level == 2) return Icons.wifi_2_bar_rounded;
        return Icons.wifi_rounded;
      case NetworkType.Vpn:
        return Icons.vpn_key_outlined;
      case NetworkType.Cellular:
        return Icons.signal_cellular_alt_rounded;
      default:
        return Icons.wifi_off_rounded;
    }
  }

  static String _signal(int level) => switch (level) {
        >= 4 => 'Sinal excelente',
        3 => 'Sinal bom',
        2 => 'Sinal regular',
        _ => 'Sinal fraco',
      };

  static String _bytes(int bytes) {
    if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1).replaceAll('.', ',')} GB';
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).round()} MB';
    return '${(bytes / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final network = context.watch<NetworkService>();
    final connected = network.networkType != NetworkType.Unknown;
    final (title, detail) = switch (network.networkType) {
      NetworkType.Wifi => ('Wi-Fi conectado', _signal(network.wirelessNetworkSignalLevel)),
      NetworkType.Wired => ('Cabo de rede conectado', 'Ethernet'),
      NetworkType.Vpn => ('VPN ativa', 'Conexão protegida'),
      NetworkType.Cellular => ('Dados móveis', _signal(network.wirelessNetworkSignalLevel)),
      _ => ('Sem conexão', 'A TV não está em nenhuma rede'),
    };
    Widget info(String label, String value, {Color? dot}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(label, style: vitrineText(13, color: t.ink2)),
              const Spacer(),
              if (dot != null) ...[
                Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(value, style: vitrineText(13, color: t.ink)),
            ],
          ),
        );
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, top: 60),
        child: Material(
          color: t.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: t.panelEdge),
          ),
          child: Container(
            width: 290,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconFor(network), size: 26, color: connected ? t.ink : t.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: vitrineText(16, weight: 600, color: t.ink)),
                          Text(detail, style: vitrineText(12, color: t.ink2)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: t.panelEdge),
                const SizedBox(height: 6),
                info(
                  'Internet',
                  network.hasInternetAccess ? 'Funcionando' : 'Sem acesso',
                  dot: network.hasInternetAccess ? const Color(0xFF4ADE80) : t.gold,
                ),
                if (network.ipAddress != null) info('Endereço na rede', network.ipAddress!),
                if (network.hasUsageStatsPermission) info('Uso de dados hoje', _bytes(network.dailyDataUsage)),
                const SizedBox(height: 10),
                DevBertiniTile(
                  icon: iconFor(network),
                  title: 'Configurações de rede',
                  trailing: Icons.open_in_new_rounded,
                  autofocus: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (network.vpnActive || network.networkType == NetworkType.Vpn) {
                      network.openVpnSettings();
                    } else {
                      network.openWifiSettings();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}