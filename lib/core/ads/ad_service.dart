import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_unit_ids.dart';

class AdService {
  AdService();

  bool _initialized = false;
  int _gamesSinceInterstitial = 0;
  InterstitialAd? _interstitial;
  final Map<AdPlacement, RewardedAd?> _rewardedAds = {};
  static const _rewardedPlacements = <AdPlacement>[
    AdPlacement.rewardedUndo,
    AdPlacement.rewardedSkip,
    AdPlacement.rewardedHint,
    AdPlacement.rewardedGameOverBonus,
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    await _loadInterstitial();
    for (final placement in _rewardedPlacements) {
      await _loadRewarded(placement);
    }
  }

  Future<bool> showRewarded({
    required AdPlacement placement,
    required void Function(int amount, String type) onReward,
  }) async {
    if (!_initialized) await initialize();
    var ad = _rewardedAds[placement];
    if (ad == null) {
      await _loadRewarded(placement);
      ad = _rewardedAds[placement];
    }
    final rewardedAd = ad;
    if (rewardedAd == null) return false;

    _rewardedAds[placement] = null;
    var rewardEarned = false;
    var cleanedUp = false;
    final completer = Completer<void>();

    void cleanup() {
      if (cleanedUp) return;
      cleanedUp = true;
      rewardedAd.dispose();
      unawaited(_loadRewarded(placement));
      if (!completer.isCompleted) completer.complete();
    }

    rewardedAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => cleanup(),
      onAdFailedToShowFullScreenContent: (_, __) => cleanup(),
    );

    try {
      await rewardedAd.show(onUserEarnedReward: (_, reward) {
        rewardEarned = true;
        onReward(reward.amount.toInt(), reward.type);
      });
    } catch (_) {
      cleanup();
      return rewardEarned;
    }

    await completer.future;
    return rewardEarned;
  }

  Future<void> dispose() async {
    _interstitial?.dispose();
    _interstitial = null;
    for (final entry in _rewardedAds.entries) {
      entry.value?.dispose();
    }
    _rewardedAds.clear();
  }

  Future<void> _loadInterstitial() async {
    final id = AdUnitIds.idFor(
      AdPlacement.interstitialGameOver,
      defaultTargetPlatform,
    );
    if (id == null) return;
    await InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  Future<void> _loadRewarded(AdPlacement placement) async {
    final id = AdUnitIds.idFor(placement, defaultTargetPlatform);
    if (id == null) return;
    await RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAds[placement] = ad,
        onAdFailedToLoad: (_) => _rewardedAds[placement] = null,
      ),
    );
  }

  Future<void> recordGameCompleted() async {
    if (!_initialized) await initialize();
    _gamesSinceInterstitial++;
    if (_gamesSinceInterstitial < 2) return;
    _gamesSinceInterstitial = 0;
    await _showInterstitial();
  }

  Future<void> _showInterstitial() async {
    if (!_initialized) await initialize();
    var ad = _interstitial;
    if (ad == null) {
      await _loadInterstitial();
      ad = _interstitial;
    }
    if (ad == null) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => _loadInterstitial(),
      onAdFailedToShowFullScreenContent: (_, __) => _loadInterstitial(),
    );
    ad.show();
  }
}

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  unawaited(service.initialize());
  ref.onDispose(service.dispose);
  return service;
});
