import 'dart:async';

import 'package:common_utils/common_utils.dart';
import 'package:flutter/services.dart';

class NknWalletPlugin {
  static const String TAG = 'NknWalletPlugin';
  static const MethodChannel _methodChannel = MethodChannel('org.nkn.sdk/wallet');
  static const EventChannel _eventChannel = EventChannel('org.nkn.sdk/wallet/event');
  static Map<String, Completer> _walletEventQueue = Map<String, Completer>();

  static init() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      Map data = event;
      String key = data['_id'];
      var result;
      if (data.containsKey('result')) {
        result = data['result'];
      } else {
        var keys = data.keys.toList();
        keys.remove('_id');
        result = Map<String, dynamic>();
        for (var key in keys) {
          result[key] = data[key];
        }
      }

      _walletEventQueue[key].complete(result);
    }, onError: (err) {
      if (_walletEventQueue[err.code] != null) {
        _walletEventQueue[err.code].completeError(err.message);
      }
    });
  }

  static Future<String> createWallet(String seed, String password) async {
    LogUtil.v('createWallet   ', tag: TAG);
    try {
      final String wallet = await _methodChannel.invokeMethod('createWallet', {
        'seed': seed,
        'password': password,
      });

      LogUtil.v(wallet);
      return wallet;
    } catch (e) {
      throw e;
    }
  }

  static Future<String> restoreWallet(String keystore, String password) async {
    try {
      LogUtil.v('restoreWallet   ', tag: TAG);
      final String wallet = await _methodChannel.invokeMethod('restoreWallet', {
        'keystore': keystore,
        'password': password,
      });
      return wallet;
    } catch (e) {
      throw e;
    }
  }

  static Future<Map<dynamic, dynamic>> openWallet(String keystore, String password) async {
    try {
      LogUtil.v('openWallet   ', tag: TAG);
      final Map<dynamic, dynamic> wallet = await _methodChannel.invokeMethod('openWallet', {
        'keystore': keystore,
        'password': password,
      });
      LogUtil.v(wallet);
      return wallet;
    } on PlatformException catch (e) {
      LogUtil.v(e.message);
      throw e;
    }
  }

  static Future<double> getBalance(String address) async {
    try {
      LogUtil.v('getBalance   ', tag: TAG);
      final String balance = await _methodChannel.invokeMethod('getBalance', {
        'address': address,
      });
      return double.parse(balance);
    } catch (e) {
      throw e;
    }
  }

  static Future<double> getBalanceAsync(String address) async {
    Completer<double> completer = Completer<double>();
    String id = completer.hashCode.toString();
    _walletEventQueue[id] = completer;
    LogUtil.v('getBalanceAsync   ', tag: TAG);
    _methodChannel.invokeMethod('getBalanceAsync', {
      '_id': id,
      'address': address,
    });

    return completer.future.whenComplete(() {
      _walletEventQueue.remove(id);
    });
  }

  static Future<String> transfer(String keystore, String password, String address, String amount, String fee) async {
    try {
      LogUtil.v('transfer   ', tag: TAG);
      final String hash = await _methodChannel.invokeMethod('transfer', {
        'keystore': keystore,
        'password': password,
        'address': address,
        'amount': amount,
        'fee': fee,
      });
      return hash;
    } catch (e) {
      throw e;
    }
  }

  static Future<String> pubKeyToWalletAddr(String publicKey) async {
    try {
      final String address = await _methodChannel.invokeMethod('pubKeyToWalletAddr', {
        'publicKey': publicKey,
      });
      return address;
    } catch (e) {
      return null;
    }
  }

}