import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PremiumProvider with ChangeNotifier {
  bool _isPremium = false;
  bool _isLoading = true;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  // TODO: Replace with the actual RevenueCat Public API Key before release
  static const String _revenueCatApiKeyAndroid = "goog_xxxxxxxxxxxxxxxxxxxxxxxxxxx";
  static const String _revenueCatApiKeyIos = "appl_xxxxxxxxxxxxxxxxxxxxxxxxxxx";

  PremiumProvider() {
    initRevenueCat();
  }

  Future<void> initRevenueCat() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration? configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyAndroid);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyIos);
      }

      if (configuration != null) {
        await Purchases.configure(configuration);
        await checkPremiumStatus();
      }
    } catch (e) {
      debugPrint("Error initializing RevenueCat: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkPremiumStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // Check if the user has the "premium" entitlement active
      if (customerInfo.entitlements.all["premium"] != null &&
          customerInfo.entitlements.all["premium"]!.isActive) {
        _isPremium = true;
      } else {
        _isPremium = false;
      }
    } catch (e) {
      debugPrint("Error checking premium status: $e");
      _isPremium = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> purchasePremium() async {
    try {
      _isLoading = true;
      notifyListeners();

      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        final purchaseResult = await Purchases.purchasePackage(offerings.current!.availablePackages.first);
        final customerInfo = purchaseResult.customerInfo;
        if (customerInfo.entitlements.all["premium"] != null &&
            customerInfo.entitlements.all["premium"]!.isActive) {
          _isPremium = true;
          notifyListeners();
          return true;
        }
      }
      return false;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Error purchasing: $e");
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all["premium"] != null &&
          customerInfo.entitlements.all["premium"]!.isActive) {
        _isPremium = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
