import 'package:flauncher/devbertini/profile_model.dart';
import 'package:flauncher/devbertini/profiles.dart';
import 'package:flauncher/devbertini/profiles_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Profiles extends ChangeNotifier implements ProfilesController {
  final LauncherProfile _main = LauncherProfile(id: mainProfileId, name: 'Bertini', color: 0);

  @override
  List<LauncherProfile> get profiles => [_main];

  @override
  LauncherProfile get current => _main;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('the profiles panel opens on the left, under the rail\'s avatar, as every panel the rail opens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider<ProfilesController>.value(
      value: _Profiles(),
      child: const MaterialApp(home: CinematicProfilesPanel()),
    ));
    await tester.pumpAndSettle();
    final panel = tester.getRect(
        find.descendant(of: find.byType(CinematicProfilesPanel), matching: find.byType(Material)).first);
    expect(panel.left, 24);
    expect(panel.top, 60);
    expect(panel.right, lessThan(960 / 2 + 200), reason: 'it stays on the left half');
  });
}
