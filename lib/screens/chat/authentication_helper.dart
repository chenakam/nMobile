/*
 * Copyright (C) NKN Labs, Inc. - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 */

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/local_notification.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/helpers/secure_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/services/local_authentication_service.dart';
import 'package:nmobile/utils/const_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

/// @author Chenai
/// @version 1.0, 14/07/2020
enum PageAction { init, pushNext, popToCurr, force }

class TimerAuth {
  final ActivePage activePage;
  bool _enabled = true;
  bool _authError = false;
  bool _canDisable = false;
  bool homePageShowing = false;

//  Timer _timer;
  DateTime _startTime;
  Set<VoidCallback> _observers = HashSet();

  TimerAuth(this.activePage);

  bool get enabled => _enabled;

  addOnStateChanged(VoidCallback callback) {
    _observers.add(callback);
  }

  removeOnStateChanged(VoidCallback callback) {
    _observers.remove(callback);
  }

  _notifyObservers() async {
    for (final callback in _observers) {
      callback();
    }
  }

  onHomePageResumed(BuildContext context) {
    if (_startTime != null) {
      _canDisable = DateTime.now().millisecondsSinceEpoch - _startTime.millisecondsSinceEpoch >= Duration.millisecondsPerMinute;
    }
    LocalNotification.debugNotification(
      '<[DEBUG]> message list',
      '${AppLifecycleState.resumed}, canDisable: $_canDisable, timer: ${/*_timer !=*/ null}, begin: ${_startTime?.toLocal().toString()}',
    );
//    _timer?.cancel();
//    _timer = null;
    if (_canDisable) {
//      _canDisable = false;
      // Pop all except `ChatScreen`, this page is in `ChatScreen`.
      Navigator.of(context).popUntil(ModalRoute.withName(ModalRoute.of(context).settings.name));
      _enabled = false;
      _notifyObservers();
      Timer(Duration(milliseconds: 350), () {
        ensureVerifyPassword(context);
      });
    }
  }

  onHomePagePaused(BuildContext context) {
//    _timer?.cancel();
    if (_authError) {
//      _timer = null;
      _canDisable = true;
    } else {
      _startTime = DateTime.now();
      // When system suspend, timer doesn't seems to keep going.
//      _timer = Timer(Duration(minutes: 1), () {
//        _timer = null;
//        _canDisable = true;
//      });
    }
  }

  onNoConnection() {
//    _timer?.cancel();
//    _timer = null;
    _enabled = true;
    _authError = false;
    _canDisable = false;
    homePageShowing = false;
  }

  onHomePageFirstShow(BuildContext context) async {
    LocalNotification.debugNotification(
      '<[DEBUG]> homePageFirstShow',
      'canDisable: $_canDisable, timer: ${/*_timer !=*/ null}, ${DateTime.now().toLocal().toString()}',
    );
//    _timer?.cancel();
//    _timer = null;
    _enabled = true;
    _authError = false;
    _canDisable = false;
    homePageShowing = true;
    if (await Global.isInBackground) {
      onHomePagePaused(context);
    }
  }

  ensureVerifyPassword(BuildContext context) async {
    if (enabled || !homePageShowing || !activePage.isCurrPageActive || await Global.isInBackground) return;
    DChatAuthenticationHelper.loadDChatUseWallet(BlocProvider.of<WalletsBloc>(context), (wallet) {
      // When show faceIdAuthentication dialog, lifecycle is inactive,
      // this can prevent secondary ejection popup.
      _canDisable = false;
      _startTime = null;
      DChatAuthenticationHelper.authToVerifyPassword(
        wallet: wallet,
        onGot: (nw) {
          _authError = false;
          _enabled = true;
          _notifyObservers();
        },
        onError: (pwdIncorrect, e) {
          _authError = true;
          if (pwdIncorrect) {
            showToast(NL10ns.of(context).tip_password_error);
          }
        },
      );
    });
  }
}

class DChatAuthenticationHelper with Tag {
  // ignore: non_constant_identifier_names
  LOG _LOG;

  DChatAuthenticationHelper() {
    _LOG = LOG(tag, usePrint: false);
  }

  bool canShow = false;
  WalletSchema wallet;

  bool _pageActiveInited = false;
  bool _isPageActive = true; // e.g. isTabOnCurrentPageIndex

  void setPageActive(PageAction action, [bool value]) {
    if (_pageActiveInited) {
      switch (action) {
        case PageAction.init:
//        _isPageActive = force;
          throw 'illegal state';
          break;
        case PageAction.pushNext:
          _isPageActive = false;
          break;
        case PageAction.popToCurr:
          _isPageActive = true;
          break;
        case PageAction.force:
          assert(value != null);
          _isPageActive = value;
          break;
        default:
          throw 'unknown';
      }
    } else {
      switch (action) {
        case PageAction.init:
          _pageActiveInited = true;
          _isPageActive = value;
          break;
        default:
          throw 'illegal state';
      }
    }
  }

  ensureAutoShowAuthentication(String debug, void onGetPassword(WalletSchema wallet, String password)) {
    _LOG.d('ensureAutoShowAuth...[$debug] | canShow: $canShow, _isPageActive: $_isPageActive,'
        ' route: ${ModalRoute.of(Global.appContext).settings.name}, wallet: $wallet.');
    LocalNotification.debugNotification('<[DEBUG]> ensureAutoShowAuth...',
        '[$debug] canShow: $canShow, pageActive: $_isPageActive, wallet: ${wallet != null}, ' + DateTime.now().toLocal().toString());
    if (canShow && _isPageActive && wallet != null) {
      prepareConnect(onGetPassword);
    }
  }

  prepareConnect(void onGetPassword(WalletSchema wallet, String password)) {
    authToPrepareConnect(wallet, (wallet, password) {
      canShow = false;
      onGetPassword(wallet, password);
    });
  }

  static void authToPrepareConnect(WalletSchema wallet, void onGetPassword(WalletSchema wallet, String password)) async {
    final _wallet = wallet;
    final _password = await authToGetPassword(_wallet);
    if (_password != null && _password.length > 0) {
      onGetPassword(_wallet, _password);
    }
  }

  static bool _authenticating = false;

  static Future<String> authToGetPassword(WalletSchema wallet, {bool forceShowInputDialog = false}) async {
    if (_authenticating) return null;
    _authenticating = true;
    final _password = await wallet.getPassword(showDialogIfCanceledBiometrics: true /*default*/, forceShowInputDialog: forceShowInputDialog);
    _authenticating = false;
    return _password;
  }

  static getPassword4BackgroundFetch({
    @required WalletSchema wallet,
    bool verifyProtectionEnabled = true,
    @required void onGetPassword(WalletSchema wallet, String password),
  }) async {
    // 22508-22760 E/flutter: [ERROR:flutter/lib/ui/ui_dart_state.cc(157)] Unhandled Exception: MissingPluginException(
    // No implementation found for method getAvailableBiometrics on channel plugins.flutter.io/local_auth)
    // Since Android Native Service create a new `DartVM`, and not init other MethodChannel.
    bool isProtectionEnabled = false;
    if (verifyProtectionEnabled) {
      isProtectionEnabled = (await LocalAuthenticationService.instance).isProtectionEnabled;
    } else {
      isProtectionEnabled = true;
    }
    if (isProtectionEnabled) {
      final _password = await SecureStorage().get('${SecureStorage.PASSWORDS_KEY}:${wallet.address}');
      if (_password != null && _password.length > 0) {
        onGetPassword(wallet, _password);
      }
    }
  }

  static void cancelAuthentication() async {
    // Must be canceled accompanied by `inputPasswordDialog`, or it only shows `inputPasswordDialog`.
//    LocalAuthenticationService.instance.then((instance) {
//      instance.cancelAuthentication();
//    });
    // TODO: cancel input password dialog, `_authenticating` also played a role.
  }

  static void verifyPassword({
    @required WalletSchema wallet,
    @required String password,
    @required void onGot(Map nknWallet),
    void onError(bool pwdIncorrect, dynamic e),
  }) async {
    try {
      final nknWallet = await wallet.exportWallet(password);
      onGot(nknWallet);
    } catch (e) {
      if (onError != null) onError(e.message == ConstUtils.WALLET_PASSWORD_ERROR, e);
    }
  }

  static authToVerifyPassword({
    @required WalletSchema wallet,
    @required void onGot(Map nknWallet),
    void onError(bool pwdIncorrect, dynamic e),
    bool forceShowInputDialog = false,
  }) async {
    final _password = await authToGetPassword(wallet, forceShowInputDialog: forceShowInputDialog);
    if (_password != null && _password.length > 0) {
      verifyPassword(wallet: wallet, password: _password, onGot: onGot, onError: onError);
    } else {
      if (onError != null) onError(false, null);
    }
  }

  static void loadDChatUseWalletByState(WalletsLoaded state, void callback(WalletSchema wallet)) {
    LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS).then((walletAddress) {
      // `walletAddress` can be null.
      final addr = walletAddress;

      void parse(WalletsLoaded state) {
        final wallet = state.wallets.firstWhere((w) => w.address == addr, orElse: () => state.wallets.first);
        callback(wallet);
      }

      parse(state);
    });
  }

  static void loadDChatUseWallet(WalletsBloc walletBloc, void callback(WalletSchema wallet)) {
    LocalStorage().get(LocalStorage.DEFAULT_D_CHAT_WALLET_ADDRESS).then((walletAddress) {
      // `walletAddress` can be null.
      final addr = walletAddress;

      void parse(WalletsLoaded state) {
        final wallet = state.wallets.firstWhere((w) => w.address == addr, orElse: () => state.wallets.first);
        callback(wallet);
      }

      if (walletBloc.state is WalletsLoaded) {
        parse(walletBloc.state as WalletsLoaded);
      } else {
        var subscription;

        void onData(state) {
          if (walletBloc.state is WalletsLoaded) {
            parse(walletBloc.state as WalletsLoaded);
            subscription.cancel();
          }
        }

        subscription = walletBloc.listen(onData);
      }
    });
  }
}
