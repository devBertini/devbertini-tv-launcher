import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/notifications_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/notifications_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  testWidgets('the notifications panel is titled in the app language', (tester) async {
    final notifications = MockNotificationsService();
    final apps = MockAppsService();
    final settings = MockSettingsService();
    when(settings.themes).thenReturn('modern');
    when(notifications.notifications).thenReturn(const []);
    when(notifications.hidePersistentNotifications).thenReturn(false);
    when(notifications.hasPermission).thenReturn(true);
    when(apps.applications).thenReturn(const []);
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationsService>.value(value: notifications),
        ChangeNotifierProvider<AppsService>.value(value: apps),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: const MaterialApp(
        locale: Locale('pt'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: NotificationsPanel(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
  });
}
