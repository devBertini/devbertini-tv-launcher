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

import 'dart:async';

import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/material.dart';

import 'package:flauncher/devbertini/profiles.dart';
import 'package:flauncher/devbertini/vitrine/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBarKey = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _backButtonActionKey = "back_button_action";
const _dateFormatKey = "date_format";
const _showCategoryTitlesKey = "show_category_titles";
const _showCategoryAppCountKey = "show_category_app_count";
const _showAppNamesBelowIconsKey = "show_app_names_below_icons";
const _themesKey = "app_banner_shape";
const _hideHighlightOutlineOnHomescreenKey = "hide_highlight_outline_on_homescreen";
const _appSelectorTransitionAnimationEnabledKey = "app_selector_transition_animation_enabled";
const _showDateInStatusBarKey = "show_date_in_status_bar";
const _showTimeInStatusBarKey = "show_time_in_status_bar";
const _timeFormatKey = "time_format";
const _dataUsagePeriodKey = "wifi_usage_period";
const _showDataWidgetInStatusBarKey = "show_wifi_widget_in_status_bar";
const String _showNetworkIndicatorInStatusBarKey = "show_network_indicator_in_status_bar";
const String _accentColorKey = "accent_color";
const String _screensaverClockStyleKey = "screensaver_clock_style";
const String _timeBasedWallpaperEnabledKey = "time_based_wallpaper_enabled";
const String _showInputsWidgetInStatusBarKey = "show_inputs_widget_in_status_bar";
const String _showContinueWatchingKey = "show_continue_watching";
const String _continueWatchingCardSizeKey = "continue_watching_card_size";
const String _continueWatchingMaxItemsKey = "continue_watching_max_items";
const String _continueWatchingShowProgressKey = "continue_watching_show_progress";
const String _continueWatchingShowPercentageKey = "continue_watching_show_percentage";
const String _continueWatchingShowDescriptionKey = "continue_watching_show_description";
const String _continueWatchingOrderKey = "continue_watching_order";
const String _hiddenWatchNextProgramIdsKey = "hidden_watch_next_program_ids";
const String _hiddenWatchNextPackagesKey = "hidden_watch_next_packages";
const String _startOnBootKey = "start_on_boot";
const String _devBertiniIntroBuildSeenKey = "devbertini_intro_build_seen";
const String _devBertiniIntroBootSeenKey = "devbertini_intro_boot_seen";
const String _devBertiniSaverMinutesKey = "devbertini_saver_minutes";
const String _screenAreaKey = "devbertini_screen_area";
const String _appearanceKey = "devbertini_appearance";
const String _showNotificationsWidgetInStatusBarKey = "show_notifications_widget_in_status_bar";
const String _autoHideNotificationsWidgetKey = "auto_hide_notifications_widget";
const String _appLanguageKey = "app_language";
const String _showWeatherInStatusBarKey = "show_weather_in_status_bar";
const String _showWeatherWarningsKey = "show_weather_warnings";
const String _temperatureUnitKey = "temperature_unit";

const String TEMPERATURE_UNIT_CELSIUS = "celsius";
const String TEMPERATURE_UNIT_FAHRENHEIT = "fahrenheit";

// WiFi usage period options
const String DATA_USAGE_DAILY = "daily";
const String DATA_USAGE_WEEKLY = "weekly";
const String DATA_USAGE_MONTHLY = "monthly";

// Accent color presets (hex values)
const String ACCENT_COLOR_PURPLE = "7C4DFF";
const String ACCENT_COLOR_TEAL = "00BFA5";
const String ACCENT_COLOR_BLUE = "2979FF";
const String ACCENT_COLOR_ORANGE = "FF6D00";
const String ACCENT_COLOR_PINK = "F50057";
const String ACCENT_COLOR_GREEN = "00C853";
const String ACCENT_COLOR_WHITE = "FFFFFF";
const String ACCENT_COLOR_YELLOW = "FFD600";
const String ACCENT_COLOR_RED = "D50000";
const String ACCENT_COLOR_CYAN = "00E5FF";
const String ACCENT_COLOR_INDIGO = "536DFE";
const String ACCENT_COLOR_LIME = "AEEA00";
const String ACCENT_COLOR_AMBER = "FFAB00";
const String ACCENT_COLOR_ROSE = "FF4081";
const String ACCENT_COLOR_ICE_BLUE = "80D8FF";
const String ACCENT_COLOR_DEVBERTINI = "6A4FE6";

class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  final SharedPreferences _sharedPreferences;

  late bool _appHighlightAnimationEnabled;
  late bool _appKeyClickEnabled;
  late bool _autoHideAppBarEnabled;
  late bool _showCategoryTitles;
  late bool _showCategoryAppCount;
  late bool _showAppNamesBelowIcons;
  late String _themes;
  late bool _hideHighlightOutlineOnHomescreen;
  late bool _appSelectorTransitionAnimationEnabled;
  late bool _showDateInStatusBar;
  late bool _showTimeInStatusBar;
  late String? _gradientUuid;
  late String _backButtonAction;
  late String _dateFormat;
  late String _timeFormat;
  late String _dataUsagePeriod;
  late bool _showDataWidgetInStatusBar;
  late bool _showNetworkIndicatorInStatusBar;
  late String _accentColorHex;
  late String _screensaverClockStyle;
  late bool _timeBasedWallpaperEnabled;
  late bool _showInputsWidgetInStatusBar;
  late bool _showContinueWatching;
  late String _continueWatchingCardSize;
  late int _continueWatchingMaxItems;
  late bool _continueWatchingShowProgress;
  late bool _continueWatchingShowPercentage;
  late bool _continueWatchingShowDescription;
  late int _continueWatchingOrder;
  late List<String> _hiddenWatchNextProgramIds;
  late List<String> _hiddenWatchNextPackages;
  late bool _startOnBoot;
  late int _devBertiniIntroBuildSeen;
  late int _devBertiniIntroBootSeen;
  late int _devBertiniSaverMinutes;
  late double _screenArea;
  late String _appearance;
  late bool _showNotificationsWidgetInStatusBar;
  late bool _autoHideNotificationsWidget;
  late String _appLanguage;
  late bool _showWeatherInStatusBar;
  late bool _showWeatherWarnings;
  late String _temperatureUnit;

  bool get appHighlightAnimationEnabled => _appHighlightAnimationEnabled;

  bool get appKeyClickEnabled => _appKeyClickEnabled;

  bool get autoHideAppBarEnabled => _autoHideAppBarEnabled;

  bool get showCategoryTitles => _showCategoryTitles;

  bool get showCategoryAppCount => _showCategoryAppCount;

  bool get showAppNamesBelowIcons => _showAppNamesBelowIcons;

  String get themes => _themes;

  bool get hideHighlightOutlineOnHomescreen => _hideHighlightOutlineOnHomescreen;

  bool get appSelectorTransitionAnimationEnabled => _appSelectorTransitionAnimationEnabled;

  bool get showDateInStatusBar => _showDateInStatusBar;

  bool get showTimeInStatusBar => _showTimeInStatusBar;

  String? get gradientUuid => _gradientUuid;

  String get backButtonAction => _backButtonAction;

  String get dateFormat => _dateFormat;

  String get timeFormat => _timeFormat;

  String get dataUsagePeriod => _dataUsagePeriod;

  bool get showDataWidgetInStatusBar => _showDataWidgetInStatusBar;

  bool get showNetworkIndicatorInStatusBar => _showNetworkIndicatorInStatusBar;

  bool get showInputsWidgetInStatusBar => _showInputsWidgetInStatusBar;
  bool get showContinueWatching => _showContinueWatching;
  String get continueWatchingCardSize => _continueWatchingCardSize;
  int get continueWatchingMaxItems => _continueWatchingMaxItems;
  bool get continueWatchingShowProgress => _continueWatchingShowProgress;
  bool get continueWatchingShowPercentage => _continueWatchingShowPercentage;
  bool get continueWatchingShowDescription => _continueWatchingShowDescription;
  int get continueWatchingOrder => _continueWatchingOrder;
  List<String> get hiddenWatchNextProgramIds => List.unmodifiable(_hiddenWatchNextProgramIds);
  List<String> get hiddenWatchNextPackages => List.unmodifiable(_hiddenWatchNextPackages);
  bool get startOnBoot => _startOnBoot;
  int get devBertiniIntroBuildSeen => _devBertiniIntroBuildSeen;

  /// The boot (Settings.Global.BOOT_COUNT) the studio intro last played in; -1 before the first.
  int get devBertiniIntroBootSeen => _devBertiniIntroBootSeen;

  /// Minutes without a key on the home before the devBertini screensaver shows; 0 is off.
  int get devBertiniSaverMinutes => _devBertiniSaverMinutes;

  /// Share of the screen the launcher draws on, 1.0 for all of it (Screen area setting).
  double get screenArea => _screenArea;

  /// Aparência: appearanceDark (the default), appearanceLight or appearanceAuto (dark in the Modo noite hours).
  String get appearance => _appearance;
  bool get showNotificationsWidgetInStatusBar => _showNotificationsWidgetInStatusBar;
  bool get autoHideNotificationsWidget => _autoHideNotificationsWidget;
  bool get showWeatherInStatusBar => _showWeatherInStatusBar;
  bool get showWeatherWarnings => _showWeatherWarnings;
  String get temperatureUnit => _temperatureUnit;
  bool get useFahrenheit => _temperatureUnit == TEMPERATURE_UNIT_FAHRENHEIT;

  String get appLanguage => _appLanguage;

  Locale? get appLocale {
    if (_appLanguage.isEmpty) {
      return null;
    }
    return Locale(_appLanguage);
  }

  String get accentColorHex => _accentColorHex;

  String get screensaverClockStyle => _screensaverClockStyle;

  Color get accentColor {
    final hex = accentColorHex;
    final int value = int.tryParse("0xFF$hex") ?? 0xFF7C4DFF;
    return Color(value);
  }

  /// Prefix of this profile's keys ('' for the main profile, the bare keys of before profiles).
  final String _keyPrefix;

  SettingsService(this._sharedPreferences, {this._keyPrefix = ''}) {
    reload();
  }

  /// The stored key of [key] for this profile; the keys every profile shares stay bare.
  String _k(String key) => globalSettingsKeys.contains(key) ? key : '$_keyPrefix$key';

  void reload() {
    _appHighlightAnimationEnabled = _sharedPreferences.getBool(_k(_appHighlightAnimationEnabledKey)) ?? true;
    _appKeyClickEnabled = _sharedPreferences.getBool(_k(_appKeyClickEnabledKey)) ?? true;
    _autoHideAppBarEnabled = _sharedPreferences.getBool(_k(_autoHideAppBarKey)) ?? false;
    _showCategoryTitles = _sharedPreferences.getBool(_k(_showCategoryTitlesKey)) ?? true;
    _showCategoryAppCount = _sharedPreferences.getBool(_k(_showCategoryAppCountKey)) ?? false;
    _showAppNamesBelowIcons = _sharedPreferences.getBool(_k(_showAppNamesBelowIconsKey)) ?? false;
    _themes = _sharedPreferences.getString(_k(_themesKey)) ?? "devbertini";
    _hideHighlightOutlineOnHomescreen = _sharedPreferences.getBool(_k(_hideHighlightOutlineOnHomescreenKey)) ?? false;
    _appSelectorTransitionAnimationEnabled = _sharedPreferences.getBool(_k(_appSelectorTransitionAnimationEnabledKey)) ?? true;
    _showDateInStatusBar = _sharedPreferences.getBool(_k(_showDateInStatusBarKey)) ?? true;
    _showTimeInStatusBar = _sharedPreferences.getBool(_k(_showTimeInStatusBarKey)) ?? true;
    _gradientUuid = _sharedPreferences.getString(_k(_gradientUuidKey));
    _backButtonAction = _sharedPreferences.getString(_k(_backButtonActionKey)) ?? BACK_BUTTON_ACTION_NOTHING;
    _dateFormat = _sharedPreferences.getString(_k(_dateFormatKey)) ?? defaultDateFormat;
    _timeFormat = _sharedPreferences.getString(_k(_timeFormatKey)) ?? defaultTimeFormat;
    _dataUsagePeriod = _sharedPreferences.getString(_k(_dataUsagePeriodKey)) ?? DATA_USAGE_DAILY;
    _showDataWidgetInStatusBar = _sharedPreferences.getBool(_k(_showDataWidgetInStatusBarKey)) ?? false;
    _showNetworkIndicatorInStatusBar = _sharedPreferences.getBool(_k(_showNetworkIndicatorInStatusBarKey)) ?? true;
    _accentColorHex = _sharedPreferences.getString(_k(_accentColorKey)) ?? ACCENT_COLOR_DEVBERTINI;
    _screensaverClockStyle = _sharedPreferences.getString(_k(_screensaverClockStyleKey)) ?? "minimal";
    _timeBasedWallpaperEnabled = _sharedPreferences.getBool(_k(_timeBasedWallpaperEnabledKey)) ?? false;
    _showInputsWidgetInStatusBar = _sharedPreferences.getBool(_k(_showInputsWidgetInStatusBarKey)) ?? true;
    // On unless turned off in the gear's panel: the Vitrine home's hero and Continuar assistindo come from it.
    _showContinueWatching = _sharedPreferences.getBool(_k(_showContinueWatchingKey)) ?? true;
    _continueWatchingCardSize = _sharedPreferences.getString(_k(_continueWatchingCardSizeKey)) ?? "normal";
    _continueWatchingMaxItems = _sharedPreferences.getInt(_k(_continueWatchingMaxItemsKey)) ?? 15;
    _continueWatchingShowProgress = _sharedPreferences.getBool(_k(_continueWatchingShowProgressKey)) ?? true;
    _continueWatchingShowPercentage = _sharedPreferences.getBool(_k(_continueWatchingShowPercentageKey)) ?? true;
    _continueWatchingShowDescription = _sharedPreferences.getBool(_k(_continueWatchingShowDescriptionKey)) ?? true;
    _continueWatchingOrder = _sharedPreferences.getInt(_k(_continueWatchingOrderKey)) ?? 0;
    _hiddenWatchNextProgramIds = _sharedPreferences.getStringList(_k(_hiddenWatchNextProgramIdsKey)) ?? [];
    _hiddenWatchNextPackages = _sharedPreferences.getStringList(_k(_hiddenWatchNextPackagesKey)) ?? [];
    _startOnBoot = _sharedPreferences.getBool(_k(_startOnBootKey)) ?? false;
    _devBertiniIntroBuildSeen = _sharedPreferences.getInt(_k(_devBertiniIntroBuildSeenKey)) ?? 0;
    _devBertiniIntroBootSeen = _sharedPreferences.getInt(_k(_devBertiniIntroBootSeenKey)) ?? -1;
    _devBertiniSaverMinutes = _sharedPreferences.getInt(_k(_devBertiniSaverMinutesKey)) ?? 5;
    _screenArea = _sharedPreferences.getDouble(_k(_screenAreaKey)) ?? 1.0;
    _appearance = _sharedPreferences.getString(_k(_appearanceKey)) ?? defaultAppearance;
    _showNotificationsWidgetInStatusBar = _sharedPreferences.getBool(_k(_showNotificationsWidgetInStatusBarKey)) ?? true;
    _autoHideNotificationsWidget = _sharedPreferences.getBool(_k(_autoHideNotificationsWidgetKey)) ?? false;
    _appLanguage = _sharedPreferences.getString(_k(_appLanguageKey)) ?? "";
    _showWeatherInStatusBar = _sharedPreferences.getBool(_k(_showWeatherInStatusBarKey)) ?? false;
    _showWeatherWarnings = _sharedPreferences.getBool(_k(_showWeatherWarningsKey)) ?? true;
    _temperatureUnit = _sharedPreferences.getString(_k(_temperatureUnitKey)) ?? TEMPERATURE_UNIT_CELSIUS;
    notifyListeners();
  }

  Map<String, dynamic> exportSettingsMap() {
    return {
      _appHighlightAnimationEnabledKey: _appHighlightAnimationEnabled,
      _appKeyClickEnabledKey: _appKeyClickEnabled,
      _autoHideAppBarKey: _autoHideAppBarEnabled,
      _showCategoryTitlesKey: _showCategoryTitles,
      _showCategoryAppCountKey: _showCategoryAppCount,
      _showAppNamesBelowIconsKey: _showAppNamesBelowIcons,
      _themesKey: _themes,
      _hideHighlightOutlineOnHomescreenKey: _hideHighlightOutlineOnHomescreen,
      _appSelectorTransitionAnimationEnabledKey: _appSelectorTransitionAnimationEnabled,
      _showDateInStatusBarKey: _showDateInStatusBar,
      _showTimeInStatusBarKey: _showTimeInStatusBar,
      if (_gradientUuid != null) _gradientUuidKey: _gradientUuid,
      _backButtonActionKey: _backButtonAction,
      _dateFormatKey: _dateFormat,
      _timeFormatKey: _timeFormat,
      _dataUsagePeriodKey: _dataUsagePeriod,
      _showDataWidgetInStatusBarKey: _showDataWidgetInStatusBar,
      _showNetworkIndicatorInStatusBarKey: _showNetworkIndicatorInStatusBar,
      _accentColorKey: _accentColorHex,
      _screensaverClockStyleKey: _screensaverClockStyle,
      _timeBasedWallpaperEnabledKey: _timeBasedWallpaperEnabled,
      _showInputsWidgetInStatusBarKey: _showInputsWidgetInStatusBar,
      _showContinueWatchingKey: _showContinueWatching,
      _continueWatchingCardSizeKey: _continueWatchingCardSize,
      _continueWatchingMaxItemsKey: _continueWatchingMaxItems,
      _continueWatchingShowProgressKey: _continueWatchingShowProgress,
      _continueWatchingShowPercentageKey: _continueWatchingShowPercentage,
      _continueWatchingShowDescriptionKey: _continueWatchingShowDescription,
      _continueWatchingOrderKey: _continueWatchingOrder,
      _hiddenWatchNextProgramIdsKey: _hiddenWatchNextProgramIds,
      _hiddenWatchNextPackagesKey: _hiddenWatchNextPackages,
      _startOnBootKey: _startOnBoot,
      _showNotificationsWidgetInStatusBarKey: _showNotificationsWidgetInStatusBar,
      _autoHideNotificationsWidgetKey: _autoHideNotificationsWidget,
      _appLanguageKey: _appLanguage,
      _showWeatherInStatusBarKey: _showWeatherInStatusBar,
      _showWeatherWarningsKey: _showWeatherWarnings,
      _temperatureUnitKey: _temperatureUnit,
      _appearanceKey: _appearance,
    };
  }

  Future<void> importSettingsMap(Map<String, dynamic> settingsMap) async {
    for (final entry in settingsMap.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is bool) {
        await _sharedPreferences.setBool(_k(key), value);
      } else if (value is int) {
        await _sharedPreferences.setInt(_k(key), value);
      } else if (value is double) {
        await _sharedPreferences.setDouble(_k(key), value);
      } else if (value is String) {
        await _sharedPreferences.setString(_k(key), value);
      } else if (value is List) {
        await _sharedPreferences.setStringList(_k(key), value.map((e) => e.toString()).toList());
      }
    }
    reload();
  }

  Future<void> setAppLanguage(String value) async {
    await _sharedPreferences.setString(_k(_appLanguageKey), value);
    _appLanguage = value;
    notifyListeners();
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    await _sharedPreferences.setBool(_k(_appHighlightAnimationEnabledKey), value);
    _appHighlightAnimationEnabled = value;
    notifyListeners();
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    await _sharedPreferences.setBool(_k(_appKeyClickEnabledKey), value);
    _appKeyClickEnabled = value;
    notifyListeners();
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    await _sharedPreferences.setBool(_k(_autoHideAppBarKey), value);
    _autoHideAppBarEnabled = value;
    notifyListeners();
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_k(_gradientUuidKey), value);
    _gradientUuid = value;
    notifyListeners();
  }

  Future<void> setBackButtonAction(String value) async {
    await _sharedPreferences.setString(_k(_backButtonActionKey), value);
    _backButtonAction = value;
    notifyListeners();
  }

  Future<void> setDateTimeFormat(String dateFormatString, String timeFormatString) async {
    await Future.wait([
      _sharedPreferences.setString(_k(_dateFormatKey), dateFormatString),
      _sharedPreferences.setString(_k(_timeFormatKey), timeFormatString)
    ]);
    _dateFormat = dateFormatString;
    _timeFormat = timeFormatString;
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    await _sharedPreferences.setBool(_k(_showCategoryTitlesKey), show);
    _showCategoryTitles = show;
    notifyListeners();
  }

  Future<void> setShowCategoryAppCount(bool show) async {
    await _sharedPreferences.setBool(_k(_showCategoryAppCountKey), show);
    _showCategoryAppCount = show;
    notifyListeners();
  }

  Future<void> setShowAppNamesBelowIcons(bool show) async {
    await _sharedPreferences.setBool(_k(_showAppNamesBelowIconsKey), show);
    _showAppNamesBelowIcons = show;
    notifyListeners();
  }

  Future<void> setThemes(String shape) async {
    await _sharedPreferences.setString(_k(_themesKey), shape);
    _themes = shape;
    notifyListeners();
  }

  Future<void> setHideHighlightOutlineOnHomescreen(bool enabled) async {
    await _sharedPreferences.setBool(_k(_hideHighlightOutlineOnHomescreenKey), enabled);
    _hideHighlightOutlineOnHomescreen = enabled;
    notifyListeners();
  }

  Future<void> setAppSelectorTransitionAnimationEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_k(_appSelectorTransitionAnimationEnabledKey), enabled);
    _appSelectorTransitionAnimationEnabled = enabled;
    notifyListeners();
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showDateInStatusBarKey), show);
    _showDateInStatusBar = show;
    notifyListeners();
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showTimeInStatusBarKey), show);
    _showTimeInStatusBar = show;
    notifyListeners();
  }

  Future<void> setDataUsagePeriod(String period) async {
    await _sharedPreferences.setString(_k(_dataUsagePeriodKey), period);
    _dataUsagePeriod = period;
    notifyListeners();
  }

  Future<void> setShowDataWidgetInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showDataWidgetInStatusBarKey), show);
    _showDataWidgetInStatusBar = show;
    notifyListeners();
  }

  Future<void> setShowNetworkIndicatorInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showNetworkIndicatorInStatusBarKey), show);
    _showNetworkIndicatorInStatusBar = show;
    notifyListeners();
  }

  Future<void> setAccentColor(String colorHex) async {
    await _sharedPreferences.setString(_k(_accentColorKey), colorHex);
    _accentColorHex = colorHex;
    notifyListeners();
  }

  Future<void> setScreensaverClockStyle(String style) async {
    await _sharedPreferences.setString(_k(_screensaverClockStyleKey), style);
    _screensaverClockStyle = style;
    notifyListeners();
  }

  bool get timeBasedWallpaperEnabled => _timeBasedWallpaperEnabled;

  Future<void> setTimeBasedWallpaperEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_k(_timeBasedWallpaperEnabledKey), enabled);
    _timeBasedWallpaperEnabled = enabled;
    notifyListeners();
  }

  Future<void> setShowInputsWidgetInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showInputsWidgetInStatusBarKey), show);
    _showInputsWidgetInStatusBar = show;
    notifyListeners();
  }

  Future<void> setShowContinueWatching(bool show) async {
    await _sharedPreferences.setBool(_k(_showContinueWatchingKey), show);
    _showContinueWatching = show;
    notifyListeners();
  }

  Future<void> setContinueWatchingCardSize(String size) async {
    await _sharedPreferences.setString(_k(_continueWatchingCardSizeKey), size);
    _continueWatchingCardSize = size;
    notifyListeners();
  }

  Future<void> setContinueWatchingMaxItems(int count) async {
    await _sharedPreferences.setInt(_k(_continueWatchingMaxItemsKey), count);
    _continueWatchingMaxItems = count;
    notifyListeners();
  }

  Future<void> setContinueWatchingShowProgress(bool show) async {
    await _sharedPreferences.setBool(_k(_continueWatchingShowProgressKey), show);
    _continueWatchingShowProgress = show;
    notifyListeners();
  }

  Future<void> setContinueWatchingShowPercentage(bool show) async {
    await _sharedPreferences.setBool(_k(_continueWatchingShowPercentageKey), show);
    _continueWatchingShowPercentage = show;
    notifyListeners();
  }

  Future<void> setContinueWatchingShowDescription(bool show) async {
    await _sharedPreferences.setBool(_k(_continueWatchingShowDescriptionKey), show);
    _continueWatchingShowDescription = show;
    notifyListeners();
  }

  Future<void> setContinueWatchingOrder(int order) async {
    await _sharedPreferences.setInt(_k(_continueWatchingOrderKey), order);
    _continueWatchingOrder = order;
    notifyListeners();
  }

  Future<void> hideWatchNextProgram(int id) async {
    final strId = id.toString();
    if (!_hiddenWatchNextProgramIds.contains(strId)) {
      _hiddenWatchNextProgramIds = List<String>.from(_hiddenWatchNextProgramIds)..add(strId);
      await _sharedPreferences.setStringList(_k(_hiddenWatchNextProgramIdsKey), _hiddenWatchNextProgramIds);
      notifyListeners();
    }
  }

  Future<void> unhideWatchNextProgram(int id) async {
    final strId = id.toString();
    if (_hiddenWatchNextProgramIds.contains(strId)) {
      _hiddenWatchNextProgramIds = List<String>.from(_hiddenWatchNextProgramIds)..remove(strId);
      await _sharedPreferences.setStringList(_k(_hiddenWatchNextProgramIdsKey), _hiddenWatchNextProgramIds);
      notifyListeners();
    }
  }

  Future<void> hideWatchNextPackage(String packageName) async {
    if (!_hiddenWatchNextPackages.contains(packageName)) {
      _hiddenWatchNextPackages = List<String>.from(_hiddenWatchNextPackages)..add(packageName);
      await _sharedPreferences.setStringList(_k(_hiddenWatchNextPackagesKey), _hiddenWatchNextPackages);
      notifyListeners();
    }
  }

  Future<void> unhideWatchNextPackage(String packageName) async {
    if (_hiddenWatchNextPackages.contains(packageName)) {
      _hiddenWatchNextPackages = List<String>.from(_hiddenWatchNextPackages)..remove(packageName);
      await _sharedPreferences.setStringList(_k(_hiddenWatchNextPackagesKey), _hiddenWatchNextPackages);
      notifyListeners();
    }
  }

  Future<void> unhideAllWatchNextPackages() async {
    _hiddenWatchNextPackages = [];
    await _sharedPreferences.remove(_k(_hiddenWatchNextPackagesKey));
    notifyListeners();
  }

  Future<void> clearHiddenWatchNextPrograms() async {
    _hiddenWatchNextProgramIds = [];
    await _sharedPreferences.remove(_k(_hiddenWatchNextProgramIdsKey));
    notifyListeners();
  }

  Future<void> clearAllHiddenWatchNext() async {
    _hiddenWatchNextProgramIds = [];
    _hiddenWatchNextPackages = [];
    await _sharedPreferences.remove(_k(_hiddenWatchNextProgramIdsKey));
    await _sharedPreferences.remove(_k(_hiddenWatchNextPackagesKey));
    notifyListeners();
  }

  Future<void> setStartOnBoot(bool enabled) async {
    await _sharedPreferences.setBool(_k(_startOnBootKey), enabled);
    _startOnBoot = enabled;
    notifyListeners();
  }

  Future<void> setScreenArea(double area) async {
    _screenArea = area;
    notifyListeners();
    await _sharedPreferences.setDouble(_k(_screenAreaKey), area);
  }

  Future<void> setAppearance(String appearance) async {
    await _sharedPreferences.setString(_k(_appearanceKey), appearance);
    _appearance = appearance;
    notifyListeners();
  }

  /// Records that the studio intro of this build was shown; nothing on screen depends on it.
  Future<void> setDevBertiniIntroBuildSeen(int build) async {
    _devBertiniIntroBuildSeen = build;
    await _sharedPreferences.setInt(_k(_devBertiniIntroBuildSeenKey), build);
  }

  Future<void> setDevBertiniSaverMinutes(int minutes) async {
    _devBertiniSaverMinutes = minutes;
    await _sharedPreferences.setInt(_k(_devBertiniSaverMinutesKey), minutes);
    notifyListeners();
  }

  /// Records the boot the studio intro played in, so a launcher restart in that boot skips it.
  Future<void> setDevBertiniIntroBootSeen(int boot) async {
    _devBertiniIntroBootSeen = boot;
    await _sharedPreferences.setInt(_k(_devBertiniIntroBootSeenKey), boot);
  }

  Future<void> setShowNotificationsWidgetInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showNotificationsWidgetInStatusBarKey), show);
    _showNotificationsWidgetInStatusBar = show;
    notifyListeners();
  }

  Future<void> setAutoHideNotificationsWidget(bool value) async {
    await _sharedPreferences.setBool(_k(_autoHideNotificationsWidgetKey), value);
    _autoHideNotificationsWidget = value;
    notifyListeners();
  }

  Future<void> setShowWeatherInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_k(_showWeatherInStatusBarKey), show);
    _showWeatherInStatusBar = show;
    notifyListeners();
  }

  Future<void> setShowWeatherWarnings(bool show) async {
    await _sharedPreferences.setBool(_k(_showWeatherWarningsKey), show);
    _showWeatherWarnings = show;
    notifyListeners();
  }

  Future<void> setTemperatureUnit(String unit) async {
    await _sharedPreferences.setString(_k(_temperatureUnitKey), unit);
    _temperatureUnit = unit;
    notifyListeners();
  }
}
