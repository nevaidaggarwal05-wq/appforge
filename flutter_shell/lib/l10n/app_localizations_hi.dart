// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'ऐप';

  @override
  String get splashTagline => 'लोड हो रहा है...';

  @override
  String get updateTitle => 'अपडेट आवश्यक है';

  @override
  String get updateMessage =>
      'एक नया संस्करण उपलब्ध है। जारी रखने के लिए कृपया अपडेट करें।';

  @override
  String get updateButton => 'अभी अपडेट करें';

  @override
  String get softUpdateMessage => 'नया संस्करण उपलब्ध है';

  @override
  String get softUpdateButton => 'अपडेट';

  @override
  String get softUpdateLater => 'बाद में';

  @override
  String get offlineTitle => 'आप ऑफ़लाइन हैं';

  @override
  String get offlineMessage => 'कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।';

  @override
  String get offlineRetry => 'पुनः प्रयास करें';

  @override
  String get rootedTitle => 'डिवाइस समर्थित नहीं है';

  @override
  String get rootedMessage =>
      'यह ऐप रूटेड या जेलब्रोकन डिवाइस पर नहीं चल सकता।';

  @override
  String get timeoutTitle => 'इसमें सामान्य से अधिक समय लग रहा है';

  @override
  String get timeoutMessage => 'कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।';

  @override
  String get timeoutRetry => 'पुनः प्रयास करें';

  @override
  String get rateTitle => 'ऐप पसंद आ रहा है?';

  @override
  String get rateBody => 'क्या आप हमें रेट करने के लिए एक पल निकालेंगे?';

  @override
  String get rateYes => 'रेट करें';

  @override
  String get rateNo => 'नहीं धन्यवाद';
}
