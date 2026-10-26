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

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/side_panel_dialog.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flauncher/widgets/settings/data_usage_period_page.dart';
import 'package:flauncher/widgets/settings/back_button_action_page.dart';
import 'package:flauncher/widgets/settings/date_time_format_page.dart';
import 'package:flauncher/widgets/settings/app_details_page.dart';
import 'package:flauncher/widgets/settings/accent_color_page.dart';
import 'package:flauncher/widgets/settings/misc_panel_page.dart';
import 'package:flauncher/widgets/settings/interface_settings_page.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flauncher/widgets/settings/screensaver_clock_style_page.dart';
import 'package:flauncher/widgets/settings/themes_page.dart';
import 'package:flauncher/widgets/settings/accessibility_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_page.dart';
import 'package:flauncher/widgets/settings/app_language_page.dart';
import 'package:flauncher/widgets/settings/blocked_notifications_page.dart';
import 'package:flauncher/widgets/settings/display_settings_page.dart';
import 'package:flauncher/widgets/settings/notifications_settings_page.dart';
import 'package:flauncher/widgets/settings/continue_watching_settings_page.dart';
import 'package:flauncher/widgets/settings/continue_watching_card_size_page.dart';
import 'package:flauncher/widgets/settings/continue_watching_max_items_page.dart';
import 'package:flauncher/widgets/settings/continue_watching_apps_page.dart';
import 'package:flauncher/models/app.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPanel extends StatefulWidget {
  final String? initialRoute;

  const SettingsPanel({super.key, this.initialRoute});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // The Vitrine looks (the cinematic themes) put the panel on the right, 384 wide, over the home dimmed by the
    // theme's own scrim; the older themes keep the dark scrim and the panel on the left.
    final cinematic = context.select<SettingsService, bool>((settings) => isCinematicTheme(settings.themes));
    // Back closes the page open inside the panel first; only on its first page does it close the panel.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final handled = await _navigatorKey.currentState!.maybePop();
        if (!handled && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: cinematic ? VitrineTheme.of(context).dim : Colors.black.withValues(alpha: 0.70), // Dim the background
        body: Stack(
          children: [
            // Tap outside to close
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
            // The side panel
            SidePanelDialog(
              width: cinematic ? 384 : 350,
              // On the left, where the rail that opens it is.
              isRightSide: false,
              child: Navigator(
                key: _navigatorKey,
                initialRoute: widget.initialRoute ?? SettingsPanelPage.routeName,
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case SettingsPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => SettingsPanelPage());
                    case GeneralSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => GeneralSettingsPage());
                    case InterfaceSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => InterfaceSettingsPage());
                    case WallpaperPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => WallpaperPanelPage());
                    case StatusBarPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => StatusBarPanelPage());
                    case GradientPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => GradientPanelPage());
                    case ApplicationsPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => ApplicationsPanelPage());
                    case LauncherSectionsPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => LauncherSectionsPanelPage());
                    case LauncherSectionPanelPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => LauncherSectionPanelPage(sectionIndex: settings.arguments as int?));
                    case DataUsagePeriodPage.routeName:
                      return _FastPageRoute(builder: (_) => DataUsagePeriodPage());
                    case BackButtonActionPage.routeName:
                      return _FastPageRoute(builder: (_) => BackButtonActionPage());
                    case DateTimeFormatPage.routeName:
                      return _FastPageRoute(builder: (_) => DateTimeFormatPage());
                    case MiscPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => MiscPanelPage());
                    case ScreensaverClockStylePage.routeName:
                      return _FastPageRoute(builder: (_) => const ScreensaverClockStylePage());
                    case ThemesPage.routeName:
                      return _FastPageRoute(builder: (_) => const ThemesPage());
                    case AccentColorPage.routeName:
                      return _FastPageRoute(builder: (_) => AccentColorPage());
                    case AccessibilityPage.routeName:
                      return _FastPageRoute(builder: (_) => const AccessibilityPage());
                    case BackupRestorePage.routeName:
                      return _FastPageRoute(builder: (_) => const BackupRestorePage());
                    case AppLanguagePage.routeName:
                      return _FastPageRoute(builder: (_) => const AppLanguagePage());
                    case BlockedNotificationsPage.routeName:
                      return _FastPageRoute(builder: (_) => const BlockedNotificationsPage());
                    case DisplaySettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => const DisplaySettingsPage());
                    case NotificationsSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => const NotificationsSettingsPage());
                    case ContinueWatchingSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => const ContinueWatchingSettingsPage());
                    case ContinueWatchingCardSizePage.routeName:
                      return _FastPageRoute(builder: (_) => const ContinueWatchingCardSizePage());
                    case ContinueWatchingMaxItemsPage.routeName:
                      return _FastPageRoute(builder: (_) => const ContinueWatchingMaxItemsPage());
                    case ContinueWatchingAppsPage.routeName:
                      return _FastPageRoute(builder: (_) => const ContinueWatchingAppsPage());
                    case AppDetailsPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => AppDetailsPage(application: settings.arguments as App));
                    default:
                      throw ArgumentError.value(settings.name, "settings.name", "Route not supported.");
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A snappy page route with zero transition delay for instant, glitch-free TV navigation.
class _FastPageRoute<T> extends PageRouteBuilder<T> {
  _FastPageRoute({required Widget Function(BuildContext) builder})
      : super(
          pageBuilder: (context, _, _) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}
