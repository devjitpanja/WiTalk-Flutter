import 'package:flutter/foundation.dart';

class AddaLeaveInterstitialAdService {
  static final AddaLeaveInterstitialAdService _instance = AddaLeaveInterstitialAdService._internal();
  factory AddaLeaveInterstitialAdService() => _instance;
  AddaLeaveInterstitialAdService._internal();

  void showAdIfReady() {
    if (kDebugMode) print('[AddaLeaveInterstitialAdService] Interstitial ad trigger on leave');
  }
}

final addaLeaveInterstitialAdService = AddaLeaveInterstitialAdService();
