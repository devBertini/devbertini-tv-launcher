/*
 * DevBertini theme for LTvLauncher (GPL-3.0, like the rest of this project).
 * Copyright (C) 2026 Claudio Bertini (devBertini)
 */

import 'package:flauncher/devbertini/brand.dart';
import 'package:flauncher/devbertini/vitrine/field.dart';
import 'package:flauncher/devbertini/vitrine/plate.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Plates per line on the Apps page: five fit the content column (x 100..912) with their gap.
const int vitrineAppsPageColumns = 5;

/// Every app, by category (docs/devbertini/DESIGN-VITRINE.md, "Remote": the rail's Apps and the row's Todos): each
/// category with apps, its name, then its plates in lines of five, on the home's field. The first plate takes the
/// focus; the page scrolls to keep the focused plate in view; holding OK keeps the apps' options (move, hide, change
/// the image). Back returns to the home.
class VitrineAppsPage extends StatelessWidget {
  const VitrineAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    final pt = Localizations.localeOf(context).languageCode == 'pt';
    final categories = context.select<AppsService, List<Category>>(
      (apps) => apps.launcherSections.whereType<Category>().where((c) => c.applications.isNotEmpty).toList(),
      // The list is new on every read: compare what it holds, so a change elsewhere in the service rebuilds nothing.
    );
    return Material(
      type: MaterialType.transparency,
      child: VitrineField(
        child: FocusTraversalGroup(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(vitrineAppsPageLeft, 34, 48, 40),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    pt ? 'Apps' : 'Apps',
                    style: vitrineText(26, weight: 500, line: 32, tracking: -0.5, color: t.ink),
                  ),
                );
              }
              final category = categories[index - 1];
              return _CategorySection(category: category, autofocusFirst: index == 1);
            },
          ),
        ),
      ),
    );
  }
}

/// Where the page's column starts, the home's content edge.
const double vitrineAppsPageLeft = 100;

class _CategorySection extends StatelessWidget {
  final Category category;
  final bool autofocusFirst;

  const _CategorySection({required this.category, required this.autofocusFirst});

  @override
  Widget build(BuildContext context) {
    final t = VitrineTheme.of(context);
    // The section follows its apps' order (a plate moved, an app hidden) and nothing else the service announces.
    context.select<AppsService, String>((_) => category.applications.map((a) => a.packageName).join(','));
    final apps = category.applications;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(categoryDisplayName(context, category.name), style: vitrineText(15, weight: 600, line: 18, color: t.ink)),
          const SizedBox(height: 9),
          RepaintBoundary(
            child: Wrap(
              spacing: vitrinePlateGap,
              runSpacing: vitrinePlateGap,
              children: [
                for (final (index, app) in apps.indexed)
                  VitrinePlate(
                    key: ValueKey('apps-page:${category.id}:${app.packageName}'),
                    app: app,
                    category: category,
                    autofocus: autofocusFirst && index == 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
