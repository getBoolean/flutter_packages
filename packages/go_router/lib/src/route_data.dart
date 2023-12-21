// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:meta/meta_meta.dart';

import 'route.dart';
import 'state.dart';

/// Baseclass for supporting
/// [Type-safe routing](https://pub.dev/documentation/go_router/latest/topics/Type-safe%20routes-topic.html).
abstract class RouteData {
  /// Allows subclasses to have `const` constructors.
  const RouteData();
}

/// A class to represent a [GoRoute] in
/// [Type-safe routing](https://pub.dev/documentation/go_router/latest/topics/Type-safe%20routes-topic.html).
///
/// Subclasses must override one of [build], [buildPage], or
/// [redirect].
/// {@category Type-safe routes}
@optionalTypeArgs
abstract class GoRouteData<F> extends RouteData {
  /// Allows subclasses to have `const` constructors.
  ///
  /// [GoRouteData] is abstract and cannot be instantiated directly.
  const GoRouteData();

  /// Creates the [Widget] for `this` route.
  ///
  /// Subclasses must override one of [build], [buildPage], or
  /// [redirect].
  ///
  /// Corresponds to [GoRoute.builder].
  Widget build(BuildContext context, GoRouterState<F> state) =>
      throw UnimplementedError(
        'One of `build` or `buildPage` must be implemented.',
      );

  /// A page builder for this route.
  ///
  /// Subclasses can override this function to provide a custom [Page].
  ///
  /// Subclasses must override one of [build], [buildPage] or
  /// [redirect].
  ///
  /// Corresponds to [GoRoute.pageBuilder].
  ///
  /// By default, returns a [Page] instance that is ignored, causing a default
  /// [Page] implementation to be used with the results of [build].
  Page<void> buildPage(BuildContext context, GoRouterState<F> state) =>
      const NoOpPage();

  /// An optional redirect function for this route.
  ///
  /// Subclasses must override one of [build], [buildPage], or
  /// [redirect].
  ///
  /// Corresponds to [GoRoute.redirect].
  FutureOr<String?> redirect(BuildContext context, GoRouterState<F> state) =>
      null;

  /// A helper function used by generated code.
  ///
  /// Should not be used directly.
  static String $location(String path, {Map<String, dynamic>? queryParams}) =>
      Uri.parse(path)
          .replace(
            queryParameters:
                // Avoid `?` in generated location if `queryParams` is empty
                queryParams?.isNotEmpty ?? false ? queryParams : null,
          )
          .toString();

  /// A helper function used by generated code.
  ///
  /// Should not be used directly.
  static GoRoute<F> $route<T extends GoRouteData<F>, F>({
    required String path,
    String? name,
    required T Function(GoRouterState<F>) factory,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    List<RouteBase<F>>? routes,
  }) {
    T factoryImpl(GoRouterState<F> state) {
      final Object? extra = state.extra;

      // If the "extra" value is of type `T` then we know it's the source
      // instance of `GoRouteData`, so it doesn't need to be recreated.
      if (extra is T) {
        return extra;
      }

      return (_stateObjectExpando[state] ??= factory(state)) as T;
    }

    Widget builder(BuildContext context, GoRouterState<F> state) =>
        factoryImpl(state).build(context, state);

    Page<void> pageBuilder(BuildContext context, GoRouterState<F> state) =>
        factoryImpl(state).buildPage(context, state);

    FutureOr<String?> redirect(BuildContext context, GoRouterState<F> state) =>
        factoryImpl(state).redirect(context, state);

    return GoRoute<F>(
      path: path,
      name: name,
      builder: builder,
      pageBuilder: pageBuilder,
      redirect: redirect,
      routes: routes ?? <RouteBase<F>>[],
      parentNavigatorKey: parentNavigatorKey,
    );
  }

  /// Used to cache [GoRouteData] that corresponds to a given [GoRouterState]
  /// to minimize the number of times it has to be deserialized.
  static final Expando<GoRouteData<dynamic>> _stateObjectExpando =
      Expando<GoRouteData<dynamic>>(
    'GoRouteState to GoRouteData expando',
  );
}

/// A class to represent a [ShellRoute] in
/// [Type-safe routing](https://pub.dev/documentation/go_router/latest/topics/Type-safe%20routes-topic.html).
@optionalTypeArgs
abstract class ShellRouteData<F> extends RouteData {
  /// Allows subclasses to have `const` constructors.
  ///
  /// [ShellRouteData] is abstract and cannot be instantiated directly.
  const ShellRouteData();

  /// [pageBuilder] is used to build the page
  Page<void> pageBuilder(
    BuildContext context,
    GoRouterState<F> state,
    Widget navigator,
  ) =>
      const NoOpPage();

  /// [builder] is used to build the widget
  Widget builder(
    BuildContext context,
    GoRouterState<F> state,
    Widget navigator,
  ) =>
      throw UnimplementedError(
        'One of `builder` or `pageBuilder` must be implemented.',
      );

  /// A helper function used by generated code.
  ///
  /// Should not be used directly.
  static ShellRoute<F> $route<T extends ShellRouteData<F>, F>({
    required T Function(GoRouterState<F>) factory,
    GlobalKey<NavigatorState>? navigatorKey,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    List<RouteBase<F>>? routes,
    List<NavigatorObserver>? observers,
    String? restorationScopeId,
  }) {
    T factoryImpl(GoRouterState<F> state) {
      return (_stateObjectExpando[state] ??= factory(state)) as T;
    }

    Widget builder(
      BuildContext context,
      GoRouterState<F> state,
      Widget navigator,
    ) =>
        factoryImpl(state).builder(
          context,
          state,
          navigator,
        );

    Page<void> pageBuilder(
      BuildContext context,
      GoRouterState<F> state,
      Widget navigator,
    ) =>
        factoryImpl(state).pageBuilder(
          context,
          state,
          navigator,
        );

    return ShellRoute<F>(
      builder: builder,
      pageBuilder: pageBuilder,
      parentNavigatorKey: parentNavigatorKey,
      routes: routes ?? <RouteBase<F>>[],
      navigatorKey: navigatorKey,
      observers: observers,
      restorationScopeId: restorationScopeId,
    );
  }

  /// Used to cache [ShellRouteData] that corresponds to a given [GoRouterState]
  /// to minimize the number of times it has to be deserialized.
  static final Expando<ShellRouteData<dynamic>> _stateObjectExpando =
      Expando<ShellRouteData<dynamic>>(
    'GoRouteState to ShellRouteData expando',
  );
}

/// Base class for supporting
/// [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html)
@optionalTypeArgs
abstract class StatefulShellRouteData<F> extends RouteData {
  /// Default const constructor
  const StatefulShellRouteData();

  /// [pageBuilder] is used to build the page
  Page<void> pageBuilder(
    BuildContext context,
    GoRouterState<F> state,
    StatefulNavigationShell<F> navigationShell,
  ) =>
      const NoOpPage();

  /// [builder] is used to build the widget
  Widget builder(
    BuildContext context,
    GoRouterState<F> state,
    StatefulNavigationShell<F> navigationShell,
  ) =>
      throw UnimplementedError(
        'One of `builder` or `pageBuilder` must be implemented.',
      );

  /// A helper function used by generated code.
  ///
  /// Should not be used directly.
  static StatefulShellRoute<F> $route<T extends StatefulShellRouteData<F>, F>({
    required T Function(GoRouterState<F>) factory,
    required List<StatefulShellBranch<F>> branches,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    ShellNavigationContainerBuilder<F>? navigatorContainerBuilder,
    String? restorationScopeId,
  }) {
    T factoryImpl(GoRouterState<F> state) {
      return (_stateObjectExpando[state] ??= factory(state)) as T;
    }

    Widget builder(
      BuildContext context,
      GoRouterState<F> state,
      StatefulNavigationShell<F> navigationShell,
    ) =>
        factoryImpl(state).builder(
          context,
          state,
          navigationShell,
        );

    Page<void> pageBuilder(
      BuildContext context,
      GoRouterState<F> state,
      StatefulNavigationShell<F> navigationShell,
    ) =>
        factoryImpl(state).pageBuilder(
          context,
          state,
          navigationShell,
        );

    if (navigatorContainerBuilder != null) {
      return StatefulShellRoute<F>(
        branches: branches,
        builder: builder,
        pageBuilder: pageBuilder,
        navigatorContainerBuilder: navigatorContainerBuilder,
        parentNavigatorKey: parentNavigatorKey,
        restorationScopeId: restorationScopeId,
      );
    }
    return StatefulShellRoute<F>.indexedStack(
      branches: branches,
      builder: builder,
      pageBuilder: pageBuilder,
      parentNavigatorKey: parentNavigatorKey,
      restorationScopeId: restorationScopeId,
    );
  }

  /// Used to cache [StatefulShellRouteData] that corresponds to a given [GoRouterState]
  /// to minimize the number of times it has to be deserialized.
  static final Expando<StatefulShellRouteData<dynamic>> _stateObjectExpando =
      Expando<StatefulShellRouteData<dynamic>>(
    'GoRouteState to StatefulShellRouteData expando',
  );
}

/// Base class for supporting
/// [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html)
abstract class StatefulShellBranchData {
  /// Default const constructor
  const StatefulShellBranchData();

  /// A helper function used by generated code.
  ///
  /// Should not be used directly.
  static StatefulShellBranch<F> $branch<T extends StatefulShellBranchData, F>({
    GlobalKey<NavigatorState>? navigatorKey,
    List<RouteBase<F>>? routes,
    List<NavigatorObserver>? observers,
    String? initialLocation,
    String? restorationScopeId,
  }) {
    return StatefulShellBranch<F>(
      routes: routes ?? <RouteBase<F>>[],
      navigatorKey: navigatorKey,
      observers: observers,
      initialLocation: initialLocation,
      restorationScopeId: restorationScopeId,
    );
  }
}

/// A superclass for each typed route descendant
class TypedRoute<T extends RouteData> {
  /// Default const constructor
  const TypedRoute();
}

/// A superclass for each typed go route descendant
@Target(<TargetKind>{TargetKind.library, TargetKind.classType})
class TypedGoRoute<T extends GoRouteData<F>, F> extends TypedRoute<T> {
  /// Default const constructor
  const TypedGoRoute({
    required this.path,
    this.name,
    this.routes = const <TypedRoute<RouteData>>[],
  });

  /// The path that corresponds to this route.
  ///
  /// See [GoRoute.path].
  ///
  ///
  final String path;

  /// The name that corresponds to this route.
  /// Used by Analytics services such as Firebase Analytics
  /// to log the screen views in their system.
  ///
  /// See [GoRoute.name].
  ///
  final String? name;

  /// Child route definitions.
  ///
  /// See [RouteBase.routes].
  final List<TypedRoute<RouteData>> routes;
}

/// A superclass for each typed shell route descendant
@Target(<TargetKind>{TargetKind.library, TargetKind.classType})
class TypedShellRoute<T extends ShellRouteData<F>, F> extends TypedRoute<T> {
  /// Default const constructor
  const TypedShellRoute({
    this.routes = const <TypedRoute<RouteData>>[],
  });

  /// Child route definitions.
  ///
  /// See [RouteBase.routes].
  final List<TypedRoute<RouteData>> routes;
}

/// A superclass for each typed shell route descendant
@Target(<TargetKind>{TargetKind.library, TargetKind.classType})
class TypedStatefulShellRoute<T extends StatefulShellRouteData<F>, F>
    extends TypedRoute<T> {
  /// Default const constructor
  const TypedStatefulShellRoute({
    this.branches = const <TypedStatefulShellBranch<StatefulShellBranchData>>[],
  });

  /// Child route definitions.
  ///
  /// See [RouteBase.routes].
  final List<TypedStatefulShellBranch<StatefulShellBranchData>> branches;
}

/// A superclass for each typed shell route descendant
@Target(<TargetKind>{TargetKind.library, TargetKind.classType})
class TypedStatefulShellBranch<T extends StatefulShellBranchData> {
  /// Default const constructor
  const TypedStatefulShellBranch({
    this.routes = const <TypedRoute<RouteData>>[],
  });

  /// Child route definitions.
  ///
  /// See [RouteBase.routes].
  final List<TypedRoute<RouteData>> routes;
}

/// Internal class used to signal that the default page behavior should be used.
@internal
class NoOpPage extends Page<void> {
  /// Creates an instance of NoOpPage;
  const NoOpPage();

  @override
  Route<void> createRoute(BuildContext context) =>
      throw UnsupportedError('Should never be called');
}
