import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_event.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/plugins/common_native.dart';
import 'package:nmobile/screens/active_page.dart';
import 'package:nmobile/screens/wallet/wallet.dart';
import 'package:nmobile/services/background_fetch_service.dart';
import 'package:nmobile/services/service_locator.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:orientation/orientation.dart';

import 'components/footer/nav.dart';
import 'screens/chat/chat.dart';
import 'screens/settings/settings.dart';

class AppScreen extends StatefulWidget {
  static const String routeName = '/AppScreen';

  @override
  _AppScreenState createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  WalletsBloc _walletsBloc;
  PageController _pageController;
  int _currentIndex = 0;
  List<Widget> screens = <Widget>[
    ChatScreen(ActivePage(0)),
//    NewsScreen(),
    WalletScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    (screens[0] as ChatScreen).activePage.setCurrActivePageIndex(_currentIndex);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    OrientationPlugin.forceOrientation(DeviceOrientation.portraitUp);
    _pageController = PageController();
//    Global.currentPageIndex = _currentIndex;
    _walletsBloc = BlocProvider.of<WalletsBloc>(context);
    _walletsBloc.add(LoadWallets());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 375, height: 812);
    Global.appContext = context;

    instanceOf<TaskService>().init();
    instanceOf<BackgroundFetchService>().init();
    return WillPopScope(
      onWillPop: () async {
        await CommonNative.androidBackToDesktop();
        return false;
      },
      child: getView(),
    );
  }

  getView() {
    return Stack(
      children: <Widget>[
        Scaffold(
          body: ConstrainedBox(
            constraints: BoxConstraints.expand(),
            child: Container(
              constraints: BoxConstraints.expand(),
              child: Flex(
                direction: Axis.vertical,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: PageView(
                      onPageChanged: (n) async {
                        setState(() {
                          _currentIndex = n;
//                          Global.currentPageIndex = _currentIndex;
//                          eventBus.fire(MainTabIndex(Global.currentPageIndex));
                        });
                        (screens[0] as ChatScreen).activePage.setCurrActivePageIndex(_currentIndex);
                      },
                      controller: _pageController,
                      children: screens,
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.white,
            child: SafeArea(
              child: Nav(
                currentIndex: _currentIndex,
                screens: screens,
                controller: _pageController,
              ),
            ),
          ),
        ),
//        getBottomView()
      ],
    );
  }

//  getBottomView() {
//    return Positioned(
//        bottom: 0,
//        left: 0,
//        right: 0,
//        child: Column(children: <Widget>[
//          Container(
//            child: SafeArea(
//              child: Nav(
//                currentIndex: _currentIndex,
//                screens: screens,
//                controller: _pageController,
//              ),
//            ),
//          ),
////          Container(
////            height: MediaQuery.of(context).padding.bottom,
////            width: double.infinity,
////            color: DefaultTheme.backgroundLightColor,
////          )
//        ]));
//  }
}
