// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'App';

  @override
  String get splashTagline => 'Loading...';

  @override
  String get updateTitle => 'Update required';

  @override
  String get updateMessage =>
      'A new version is available. Please update to continue.';

  @override
  String get updateButton => 'Update now';

  @override
  String get softUpdateMessage => 'A new version is available';

  @override
  String get softUpdateButton => 'Update';

  @override
  String get softUpdateLater => 'Later';

  @override
  String get offlineTitle => 'You\'re offline';

  @override
  String get offlineMessage => 'Check your connection and try again.';

  @override
  String get offlineRetry => 'Retry';

  @override
  String get rootedTitle => 'Device not supported';

  @override
  String get rootedMessage =>
      'This app can\'t run on rooted or jailbroken devices.';

  @override
  String get timeoutTitle => 'This is taking longer than usual';

  @override
  String get timeoutMessage => 'Check your connection and try again.';

  @override
  String get timeoutRetry => 'Retry';

  @override
  String get rateTitle => 'Enjoying the app?';

  @override
  String get rateBody => 'Would you mind taking a moment to rate us?';

  @override
  String get rateYes => 'Rate us';

  @override
  String get rateNo => 'No thanks';
}
