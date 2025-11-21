import 'package:flutter/foundation.dart';

enum AdPlacement {
  interstitialGameOver,
  rewardedUndo,
  rewardedSkip,
  rewardedHint,
  rewardedGameOverBonus,
}

class AdUnitIds {
  static const String androidAppId = 'ca-app-pub-5255146345620489~3900091876';
  static const String iosAppId = 'ca-app-pub-5255146345620489~7372433025';

  static const _androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosRewardedTestId = 'ca-app-pub-3940256099942544/1712485313';

  static String? idFor(AdPlacement placement, TargetPlatform platform) {
    final useTestIds = kDebugMode;
    switch (platform) {
      case TargetPlatform.android:
        return (useTestIds ? _androidTestUnits : _androidUnits)[placement];
      case TargetPlatform.iOS:
        return (useTestIds ? _iosTestUnits : _iosUnits)[placement];
      default:
        return null;
    }
  }

  static const Map<AdPlacement, String> _androidUnits = {
    AdPlacement.interstitialGameOver: 'ca-app-pub-5255146345620489/6273197672',
    AdPlacement.rewardedUndo: 'ca-app-pub-5255146345620489/9719943507',
    AdPlacement.rewardedSkip: 'ca-app-pub-5255146345620489/7093780163',
    AdPlacement.rewardedHint: 'ca-app-pub-5255146345620489/9451801459',
    AdPlacement.rewardedGameOverBonus: 'ca-app-pub-5255146345620489/9396811199',
  };

  static const Map<AdPlacement, String> _iosUnits = {
    AdPlacement.interstitialGameOver: 'ca-app-pub-5255146345620489/1378419053',
    AdPlacement.rewardedUndo: 'ca-app-pub-5255146345620489/1355912913',
    AdPlacement.rewardedSkip: 'ca-app-pub-5255146345620489/3433188014',
    AdPlacement.rewardedHint: 'ca-app-pub-5255146345620489/3154535156',
    AdPlacement.rewardedGameOverBonus: 'ca-app-pub-5255146345620489/9829693566',
  };

  static const Map<AdPlacement, String> _androidTestUnits = {
    AdPlacement.interstitialGameOver: 'ca-app-pub-3940256099942544/1033173712',
    AdPlacement.rewardedUndo: _androidRewardedTestId,
    AdPlacement.rewardedSkip: _androidRewardedTestId,
    AdPlacement.rewardedHint: _androidRewardedTestId,
    AdPlacement.rewardedGameOverBonus: _androidRewardedTestId,
  };

  static const Map<AdPlacement, String> _iosTestUnits = {
    AdPlacement.interstitialGameOver: 'ca-app-pub-3940256099942544/4411468910',
    AdPlacement.rewardedUndo: _iosRewardedTestId,
    AdPlacement.rewardedSkip: _iosRewardedTestId,
    AdPlacement.rewardedHint: _iosRewardedTestId,
    AdPlacement.rewardedGameOverBonus: _iosRewardedTestId,
  };
}
