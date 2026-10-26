/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
 * Modified in 2026 by Claudio Bertini (devBertini): the fork's author, name and links, in Portuguese and English.
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

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/providers/settings_service.dart';

class LTvLauncherAboutDialog extends StatelessWidget {
  final PackageInfo packageInfo;

  /// The fork's own repository and its author's pages.
  static const String repositoryUrl = "https://github.com/devBertini/devbertini-tv-launcher";
  static const String authorGitHubUrl = "https://github.com/devBertini";
  static const String authorLinkedInUrl = "https://www.linkedin.com/in/claudio-bertini/";

  const LTvLauncherAboutDialog({
    super.key,
    required this.packageInfo,
  });

  Color _hexToColor(String hex) {
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final accentColor = _hexToColor(settingsService.accentColorHex);
    final pt = Localizations.maybeLocaleOf(context)?.languageCode == 'pt';
    String tr(String en, String portuguese) => pt ? portuguese : en;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 380,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clean App Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  "assets/icon.png",
                  height: 56,
                  width: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),

              // Title & Version
              const Text(
                "devBertini TV Launcher",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "v${packageInfo.version} (${packageInfo.buildNumber})",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr("By Claudio Bertini (devBertini)", "Por Claudio Bertini (devBertini)"),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr("Based on LTvLauncher by LeanBitLab and on FLauncher",
                    "Baseado no LTvLauncher, da LeanBitLab, e no FLauncher"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),

              // About info description
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr("A fast, private home screen for Android TV and Google TV, free and open source. No ads and no trackers.",
                      "Uma tela inicial rápida e privada para Android TV e Google TV, livre e de código aberto. Sem anúncios e sem rastreadores."),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // The fork's author
              _AboutSection(tr("Author", "Autor")),
              const SizedBox(height: 8),
              _AboutButton(
                icon: Icons.code,
                iconColor: Colors.white70,
                label: tr("Source code on GitHub", "Código-fonte no GitHub"),
                accentColor: accentColor,
                autofocus: true,
                onPressed: () {
                  FLauncherChannel().openUrl(repositoryUrl);
                },
              ),
              const SizedBox(height: 6),
              _AboutButton(
                icon: Icons.person_outline_rounded,
                iconColor: Colors.white70,
                label: "GitHub (devBertini)",
                accentColor: accentColor,
                onPressed: () {
                  FLauncherChannel().openUrl(authorGitHubUrl);
                },
              ),
              const SizedBox(height: 6),
              _AboutButton(
                icon: Icons.work_outline_rounded,
                iconColor: const Color(0xFF0A66C2),
                label: "LinkedIn (Claudio Bertini)",
                accentColor: accentColor,
                onPressed: () {
                  FLauncherChannel().openUrl(authorLinkedInUrl);
                },
              ),
              const SizedBox(height: 14),

              // The project it is built on
              _AboutSection(tr("Original project: LeanBitLab", "Projeto original: LeanBitLab")),
              const SizedBox(height: 8),

              // Official Website
              _AboutButton(
                icon: Icons.language,
                iconColor: const Color(0xFF7C4DFF),
                label: "Website",
                accentColor: accentColor,
                onPressed: () {
                  FLauncherChannel().openUrl("https://leanbitlab.github.io/LeanBitLab/");
                },
              ),
              const SizedBox(height: 6),

              // Source Code / GitHub
              _AboutButton(
                icon: Icons.code,
                iconColor: Colors.white70,
                label: tr("LTvLauncher on GitHub", "LTvLauncher no GitHub"),
                accentColor: accentColor,
                onPressed: () {
                  FLauncherChannel().openUrl("https://github.com/leanbitlab-org/LtvLauncher");
                },
              ),
              const SizedBox(height: 6),

              // Telegram Channel
              _AboutButton(
                icon: Icons.send_rounded,
                iconColor: const Color(0xFF2CA5E0),
                label: "Telegram (@LeanBitLab)",
                accentColor: accentColor,
                onPressed: () {
                  FLauncherChannel().openUrl("https://t.me/LeanBitLab");
                },
              ),
              const SizedBox(height: 6),

              // Reddit Community
              _AboutButton(
                icon: Icons.forum_rounded,
                iconColor: const Color(0xFFFF4500),
                label: "Reddit (r/LeanBitLab_)",
                accentColor: accentColor,
                onPressed: () {
                  FLauncherChannel().openUrl("https://www.reddit.com/r/LeanBitLab_/");
                },
              ),
              const SizedBox(height: 10),

              // Close Action
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  tr("Close", "Fechar"),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;

  const _AboutSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AboutButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color accentColor;
  final VoidCallback onPressed;
  final bool autofocus;

  const _AboutButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.accentColor,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  State<_AboutButton> createState() => _AboutButtonState();
}

class _AboutButtonState extends State<_AboutButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _focused ? widget.accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? Colors.white : Colors.transparent,
                width: _focused ? 2 : 0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 16, color: _focused ? Colors.white : widget.iconColor),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: _focused ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
