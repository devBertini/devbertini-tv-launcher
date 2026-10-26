/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/actions.dart';
import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/cinematic.dart';
import 'package:flauncher/devbertini/devbertini_intro_gate.dart';
import 'package:flauncher/devbertini/screensaver.dart';
import 'package:flauncher/devbertini/tv_extras.dart';
import 'package:flauncher/devbertini/vitrine/material_theme.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'flauncher.dart';

class FLauncherApp extends StatelessWidget
{
  static const PrioritizedIntents _backIntents = PrioritizedIntents(orderedIntents: [
    DismissIntent(),
    BackIntent()
  ]);

  const FLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppsService appsService = context.read<AppsService>();
    LauncherState launcherState = context.read<LauncherState>();
    launcherState.refresh(appsService);

    // The Vitrine colours: the palette of the theme setting, drawn dark or light as Aparência says (Automático
    // follows the Modo noite hours, whether or not Modo noite dims the home).
    return Selector2<SettingsService, NightModeService?, (Locale?, String, Brightness)>(
      selector: (_, settings, nightMode) => (
        settings.appLocale,
        settings.themes,
        vitrineBrightness(settings.appearance, night: nightMode?.night ?? false),
      ),
      builder: (context, selected, _) {
        final (appLocale, theme, brightness) = selected;
        final palette = CinematicPalette.of(theme);
        final tokens = VitrineTokens.of(palette, brightness);

        return MaterialApp(
      locale: appLocale,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): _backIntents,
        const SingleActivator(LogicalKeyboardKey.gameButtonB): _backIntents,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonSelect): const ActivateIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        BackIntent: BackAction(context),
        DirectionalFocusIntent: SoundFeedbackDirectionalFocusAction(context)
      },
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'FLauncher',
      theme: vitrineMaterialTheme(tokens),
      // Screen area: the whole launcher, panels included, shrunk inside black borders.
      builder: (context, child) => Selector<SettingsService, double>(
        selector: (_, settings) => settings.screenArea,
        builder: (context, area, _) => VitrineTheme(
          tokens: tokens,
          child: CinematicThemeScope(
            palette: palette,
            // The screensaver covers every page, panels included, so nothing stays lit above it.
            child: DevBertiniScreenArea(area: area, child: DevBertiniScreensaver(child: child!)),
          ),
        ),
      ),
      home: Builder(
        builder: (context) => PopScope(
          canPop: false,
          child: const DevBertiniIntroGate(child: FLauncher()),
          onPopInvokedWithResult: (didPop, _) {
            LauncherState launcherState = context.read<LauncherState>();
            launcherState.handleBackNavigation(context);
          }
        )
      ),
      );
    });
  }
}
