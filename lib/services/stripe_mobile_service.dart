import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeMobileService {
  StripeMobileService._();

  static Future<void> preparePaymentSheet({
    required String publishableKey,
    required String clientSecret,
  }) async {
    Stripe.publishableKey = publishableKey;

    await Stripe.instance.applySettings();

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'FashionStore',
        style: ThemeMode.dark,
      ),
    );
  }

  static Future<void> presentPaymentSheet() async {
    await Stripe.instance.presentPaymentSheet();
  }
}
