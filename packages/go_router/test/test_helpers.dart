// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: cascade_invocations, diagnostic_describe_all_properties

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter<F>> createGoRouter<F>(WidgetTester tester) async {
  final GoRouter<F> goRouter = GoRouter<F>(
    initialLocation: '/',
    routes: <GoRoute<F>>[
      GoRoute<F>(path: '/', builder: (_, __) => const DummyStatefulWidget()),
      GoRoute<F>(
        path: '/error',
        builder: (_, __) => TestErrorScreen(TestFailure('Exception')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: goRouter,
  ));
  return goRouter;
}

Widget fakeNavigationBuilder<F>(
  BuildContext context,
  GoRouterState<F> state,
  Widget child,
) =>
    child;

class GoRouterNamedLocationSpy extends GoRouter {
  GoRouterNamedLocationSpy({required List<RouteBase> routes})
      : super.routingConfig(
            routingConfig:
                ConstantRoutingConfig(RoutingConfig(routes: routes)));

  String? name;
  Map<String, String>? pathParameters;
  Map<String, dynamic>? queryParameters;

  @override
  String namedLocation(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
  }) {
    this.name = name;
    this.pathParameters = pathParameters;
    this.queryParameters = queryParameters;
    return '';
  }
}

class GoRouterGoSpy extends GoRouter {
  GoRouterGoSpy({required List<RouteBase> routes})
      : super.routingConfig(
            routingConfig:
                ConstantRoutingConfig(RoutingConfig(routes: routes)));

  String? myLocation;
  Object? extra;

  @override
  void go(String location, {Object? extra}) {
    myLocation = location;
    this.extra = extra;
  }
}

class GoRouterGoNamedSpy extends GoRouter {
  GoRouterGoNamedSpy({required List<RouteBase> routes})
      : super.routingConfig(
            routingConfig:
                ConstantRoutingConfig(RoutingConfig(routes: routes)));

  String? name;
  Map<String, String>? pathParameters;
  Map<String, dynamic>? queryParameters;
  Object? extra;

  @override
  void goNamed(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    this.name = name;
    this.pathParameters = pathParameters;
    this.queryParameters = queryParameters;
    this.extra = extra;
  }
}

class GoRouterPushSpy extends GoRouter {
  GoRouterPushSpy({required List<RouteBase> routes})
      : super.routingConfig(
            routingConfig:
                ConstantRoutingConfig(RoutingConfig(routes: routes)));

  String? myLocation;
  Object? extra;

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    myLocation = location;
    this.extra = extra;
    return Future<T?>.value(extra as T?);
  }
}

class GoRouterPushNamedSpy extends GoRouter {
  GoRouterPushNamedSpy({required List<RouteBase> routes})
      : super.routingConfig(
            routingConfig:
                ConstantRoutingConfig(RoutingConfig(routes: routes)));

  String? name;
  Map<String, String>? pathParameters;
  Map<String, dynamic>? queryParameters;
  Object? extra;

  @override
  Future<T?> pushNamed<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    this.name = name;
    this.pathParameters = pathParameters;
    this.queryParameters = queryParameters;
    this.extra = extra;
    return Future<T?>.value(extra as T?);
  }
}

class GoRouterPopSpy extends GoRouter {
  GoRouterPopSpy({required List<RouteBase> routes})
      : super.routingConfig(
            routingConfig:
                ConstantRoutingConfig(RoutingConfig(routes: routes)));

  bool popped = false;
  Object? poppedResult;

  @override
  void pop<T extends Object?>([T? result]) {
    popped = true;
    poppedResult = result;
  }
}

Future<GoRouter<F>> createRouter<F>(
  List<RouteBase<F>> routes,
  WidgetTester tester, {
  GoRouterRedirect<F>? redirect,
  String initialLocation = '/',
  Object? initialExtra,
  int redirectLimit = 5,
  GlobalKey<NavigatorState>? navigatorKey,
  GoRouterWidgetBuilder<F>? errorBuilder,
  String? restorationScopeId,
  Codec<Object?, Object?>? extraCodec,
  GoExceptionHandler<F>? onException,
  bool requestFocus = true,
  bool overridePlatformDefaultLocation = false,
}) async {
  final GoRouter<F> goRouter = GoRouter<F>(
    routes: routes,
    redirect: redirect,
    extraCodec: extraCodec,
    initialLocation: initialLocation,
    onException: onException,
    initialExtra: initialExtra,
    redirectLimit: redirectLimit,
    errorBuilder: errorBuilder,
    navigatorKey: navigatorKey,
    restorationScopeId: restorationScopeId,
    requestFocus: requestFocus,
    overridePlatformDefaultLocation: overridePlatformDefaultLocation,
  );
  await tester.pumpWidget(
    MaterialApp.router(
      restorationScopeId:
          restorationScopeId != null ? '$restorationScopeId-root' : null,
      routerConfig: goRouter,
    ),
  );
  return goRouter;
}

Future<GoRouter<F>> createRouterWithRoutingConfig<F>(
  ValueListenable<RoutingConfig<F>> config,
  WidgetTester tester, {
  String initialLocation = '/',
  Object? initialExtra,
  GlobalKey<NavigatorState>? navigatorKey,
  GoRouterWidgetBuilder<F>? errorBuilder,
  String? restorationScopeId,
  GoExceptionHandler<F>? onException,
  bool requestFocus = true,
  bool overridePlatformDefaultLocation = false,
}) async {
  final GoRouter<F> goRouter = GoRouter<F>.routingConfig(
    routingConfig: config,
    initialLocation: initialLocation,
    onException: onException,
    initialExtra: initialExtra,
    errorBuilder: errorBuilder,
    navigatorKey: navigatorKey,
    restorationScopeId: restorationScopeId,
    requestFocus: requestFocus,
    overridePlatformDefaultLocation: overridePlatformDefaultLocation,
  );
  await tester.pumpWidget(
    MaterialApp.router(
      restorationScopeId:
          restorationScopeId != null ? '$restorationScopeId-root' : null,
      routerConfig: goRouter,
    ),
  );
  return goRouter;
}

class TestErrorScreen extends DummyScreen {
  const TestErrorScreen(this.ex, {super.key});

  final Exception ex;
}

class HomeScreen extends DummyScreen {
  const HomeScreen({super.key});
}

class Page1Screen extends DummyScreen {
  const Page1Screen({super.key});
}

class Page2Screen extends DummyScreen {
  const Page2Screen({super.key});
}

class LoginScreen extends DummyScreen {
  const LoginScreen({super.key});
}

class FamilyScreen extends DummyScreen {
  const FamilyScreen(this.fid, {super.key});

  final String fid;
}

class FamiliesScreen extends DummyScreen {
  const FamiliesScreen({required this.selectedFid, super.key});

  final String selectedFid;
}

class PersonScreen extends DummyScreen {
  const PersonScreen(this.fid, this.pid, {super.key});

  final String fid;
  final String pid;
}

class DummyScreen extends StatelessWidget {
  const DummyScreen({
    this.queryParametersAll = const <String, dynamic>{},
    super.key,
  });

  final Map<String, dynamic> queryParametersAll;

  @override
  Widget build(BuildContext context) => const Placeholder();
}

Widget dummy<F>(BuildContext context, GoRouterState<F> state) =>
    const DummyScreen();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DummyStatefulWidget extends StatefulWidget {
  const DummyStatefulWidget({super.key});

  @override
  State<StatefulWidget> createState() => DummyStatefulWidgetState();
}

class DummyStatefulWidgetState extends State<DummyStatefulWidget> {
  int counter = 0;

  void increment() => setState(() {
        counter++;
      });

  @override
  Widget build(BuildContext context) => Container();
}

class DummyRestorableStatefulWidget extends StatefulWidget {
  const DummyRestorableStatefulWidget({super.key, this.restorationId});

  final String? restorationId;

  @override
  State<StatefulWidget> createState() => DummyRestorableStatefulWidgetState();
}

class DummyRestorableStatefulWidgetState
    extends State<DummyRestorableStatefulWidget> with RestorationMixin {
  final RestorableInt _counter = RestorableInt(0);

  @override
  String? get restorationId => widget.restorationId;

  int get counter => _counter.value;

  void increment([int count = 1]) => setState(() {
        _counter.value += count;
      });

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (restorationId != null) {
      registerForRestoration(_counter, restorationId!);
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}

Future<void> simulateAndroidBackButton(WidgetTester tester) async {
  final ByteData message =
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
  await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage('flutter/navigation', message, (_) {});
}

GoRouterPageBuilder<F> createPageBuilder<F>(
        {String? restorationId, required Widget child}) =>
    (BuildContext context, GoRouterState<F> state) =>
        MaterialPage<dynamic>(restorationId: restorationId, child: child);

StatefulShellRouteBuilder<F> mockStackedShellBuilder<F>() =>
    (BuildContext context, GoRouterState<F> state,
        StatefulNavigationShell<F> navigationShell) {
      return navigationShell;
    };

RouteMatch<F> createRouteMatch<F>(RouteBase<F> route, String location) {
  return RouteMatch<F>(
    route: route,
    matchedLocation: location,
    pageKey: ValueKey<String>(location),
  );
}

/// A routing config that is never going to change.
@optionalTypeArgs
class ConstantRoutingConfig<F> extends ValueListenable<RoutingConfig<F>> {
  const ConstantRoutingConfig(this.value);
  @override
  void addListener(VoidCallback listener) {
    // Intentionally empty because listener will never be called.
  }

  @override
  void removeListener(VoidCallback listener) {
    // Intentionally empty because listener will never be called.
  }

  @override
  final RoutingConfig<F> value;
}

RouteConfiguration<F> createRouteConfiguration<F>({
  required List<RouteBase<F>> routes,
  required GlobalKey<NavigatorState> navigatorKey,
  required GoRouterRedirect<F> topRedirect,
  required int redirectLimit,
}) {
  return RouteConfiguration<F>(
      ConstantRoutingConfig<F>(RoutingConfig<F>(
        routes: routes,
        redirect: topRedirect,
        redirectLimit: redirectLimit,
      )),
      navigatorKey: navigatorKey);
}

class SimpleDependencyProvider extends InheritedNotifier<SimpleDependency> {
  const SimpleDependencyProvider(
      {super.key, required SimpleDependency dependency, required super.child})
      : super(notifier: dependency);

  static SimpleDependency of(BuildContext context) {
    final SimpleDependencyProvider result =
        context.dependOnInheritedWidgetOfExactType<SimpleDependencyProvider>()!;
    return result.notifier!;
  }
}

class SimpleDependency extends ChangeNotifier {
  bool get boolProperty => _boolProperty;
  bool _boolProperty = true;
  set boolProperty(bool value) {
    if (value == _boolProperty) {
      return;
    }
    _boolProperty = value;
    notifyListeners();
  }
}
