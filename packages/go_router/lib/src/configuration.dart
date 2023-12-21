// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'logging.dart';
import 'match.dart';
import 'misc/errors.dart';
import 'path_utils.dart';
import 'route.dart';
import 'router.dart';
import 'state.dart';

/// The signature of the redirect callback.
typedef GoRouterRedirect<F> = FutureOr<String?> Function(
    BuildContext context, GoRouterState<F> state);

/// The route configuration for GoRouter configured by the app.
@optionalTypeArgs
class RouteConfiguration<F> {
  /// Constructs a [RouteConfiguration].
  RouteConfiguration(
    this._routingConfig, {
    required this.navigatorKey,
    this.extraCodec,
  }) {
    _onRoutingTableChanged();
    _routingConfig.addListener(_onRoutingTableChanged);
  }

  static bool _debugCheckPath<F>(List<RouteBase<F>> routes, bool isTopLevel) {
    for (final RouteBase<F> route in routes) {
      late bool subRouteIsTopLevel;
      if (route is GoRoute<F>) {
        if (isTopLevel) {
          assert(route.path.startsWith('/'),
              'top-level path must start with "/": $route');
        } else {
          assert(!route.path.startsWith('/') && !route.path.endsWith('/'),
              'sub-route path may not start or end with "/": $route');
        }
        subRouteIsTopLevel = false;
      } else if (route is ShellRouteBase) {
        subRouteIsTopLevel = isTopLevel;
      }
      _debugCheckPath(route.routes, subRouteIsTopLevel);
    }
    return true;
  }

  // Check that each parentNavigatorKey refers to either a ShellRoute's
  // navigatorKey or the root navigator key.
  static bool _debugCheckParentNavigatorKeys<F>(
      List<RouteBase<F>> routes, List<GlobalKey<NavigatorState>> allowedKeys) {
    for (final RouteBase<F> route in routes) {
      if (route is GoRoute<F>) {
        final GlobalKey<NavigatorState>? parentKey = route.parentNavigatorKey;
        if (parentKey != null) {
          // Verify that the root navigator or a ShellRoute ancestor has a
          // matching navigator key.
          assert(
              allowedKeys.contains(parentKey),
              'parentNavigatorKey $parentKey must refer to'
              " an ancestor ShellRoute's navigatorKey or GoRouter's"
              ' navigatorKey');

          _debugCheckParentNavigatorKeys(
            route.routes,
            <GlobalKey<NavigatorState>>[
              // Once a parentNavigatorKey is used, only that navigator key
              // or keys above it can be used.
              ...allowedKeys.sublist(0, allowedKeys.indexOf(parentKey) + 1),
            ],
          );
        } else {
          _debugCheckParentNavigatorKeys(
            route.routes,
            <GlobalKey<NavigatorState>>[
              ...allowedKeys,
            ],
          );
        }
      } else if (route is ShellRoute<F>) {
        _debugCheckParentNavigatorKeys(
          route.routes,
          <GlobalKey<NavigatorState>>[...allowedKeys..add(route.navigatorKey)],
        );
      } else if (route is StatefulShellRoute<F>) {
        for (final StatefulShellBranch<F> branch in route.branches) {
          assert(
              !allowedKeys.contains(branch.navigatorKey),
              'StatefulShellBranch must not reuse an ancestor navigatorKey '
              '(${branch.navigatorKey})');

          _debugCheckParentNavigatorKeys(
            branch.routes,
            <GlobalKey<NavigatorState>>[
              ...allowedKeys,
              branch.navigatorKey,
            ],
          );
        }
      }
    }
    return true;
  }

  static bool _debugVerifyNoDuplicatePathParameter<T>(
      List<RouteBase<T>> routes, Map<String, GoRoute<T>> usedPathParams) {
    for (final RouteBase<T> route in routes) {
      if (route is! GoRoute<T>) {
        continue;
      }
      for (final String pathParam in route.pathParameters) {
        if (usedPathParams.containsKey(pathParam)) {
          final bool sameRoute = usedPathParams[pathParam] == route;
          throw GoError(
              "duplicate path parameter, '$pathParam' found in ${sameRoute ? '$route' : '${usedPathParams[pathParam]}, and $route'}");
        }
        usedPathParams[pathParam] = route;
      }
      _debugVerifyNoDuplicatePathParameter(route.routes, usedPathParams);
      route.pathParameters.forEach(usedPathParams.remove);
    }
    return true;
  }

  // Check to see that the configured initialLocation of StatefulShellBranches
  // points to a descendant route of the route branch.
  bool _debugCheckStatefulShellBranchDefaultLocations(
      List<RouteBase<F>> routes) {
    for (final RouteBase<F> route in routes) {
      if (route is StatefulShellRoute<F>) {
        for (final StatefulShellBranch<F> branch in route.branches) {
          if (branch.initialLocation == null) {
            // Recursively search for the first GoRoute descendant. Will
            // throw assertion error if not found.
            final GoRoute<F>? route = branch.defaultRoute;
            final String? initialLocation =
                route != null ? locationForRoute(route) : null;
            assert(
                initialLocation != null,
                'The default location of a StatefulShellBranch must be '
                'derivable from GoRoute descendant');
            assert(
                route!.pathParameters.isEmpty,
                'The default location of a StatefulShellBranch cannot be '
                'a parameterized route');
          } else {
            final RouteMatchList<F> matchList =
                findMatch(branch.initialLocation!);
            assert(
                !matchList.isError,
                'initialLocation (${matchList.uri}) of StatefulShellBranch must '
                'be a valid location');
            final List<RouteBase<F>> matchRoutes = matchList.routes;
            final int shellIndex = matchRoutes.indexOf(route);
            bool matchFound = false;
            if (shellIndex >= 0 && (shellIndex + 1) < matchRoutes.length) {
              final RouteBase<F> branchRoot = matchRoutes[shellIndex + 1];
              matchFound = branch.routes.contains(branchRoot);
            }
            assert(
                matchFound,
                'The initialLocation (${branch.initialLocation}) of '
                'StatefulShellBranch must match a descendant route of the '
                'branch');
          }
        }
      }
      _debugCheckStatefulShellBranchDefaultLocations(route.routes);
    }
    return true;
  }

  /// The match used when there is an error during parsing.
  static RouteMatchList<T> _errorRouteMatchList<T>(
    Uri uri,
    GoException exception, {
    Object? extra,
  }) {
    return RouteMatchList<T>(
      matches: const <RouteMatch<Never>>[],
      extra: extra,
      error: exception,
      uri: uri,
      pathParameters: const <String, String>{},
    );
  }

  void _onRoutingTableChanged() {
    final RoutingConfig<F> routingTable = _routingConfig.value;
    assert(_debugCheckPath(routingTable.routes, true));
    assert(_debugVerifyNoDuplicatePathParameter(
        routingTable.routes, <String, GoRoute<F>>{}));
    assert(_debugCheckParentNavigatorKeys(
        routingTable.routes, <GlobalKey<NavigatorState>>[navigatorKey]));
    assert(_debugCheckStatefulShellBranchDefaultLocations(routingTable.routes));
    _nameToPath.clear();
    _cacheNameToPath('', routingTable.routes);
    log(debugKnownRoutes());
  }

  /// Builds a [GoRouterState] suitable for top level callback such as
  /// `GoRouter.redirect` or `GoRouter.onException`.
  GoRouterState<F> buildTopLevelGoRouterState(RouteMatchList<F> matchList) {
    return GoRouterState<F>(
      this,
      uri: matchList.uri,
      // No name available at the top level trim the query params off the
      // sub-location to match route.redirect
      fullPath: matchList.fullPath,
      pathParameters: matchList.pathParameters,
      matchedLocation: matchList.uri.path,
      extra: matchList.extra,
      pageKey: const ValueKey<String>('topLevel'),
      matchList: matchList,
    );
  }

  /// The routing table.
  final ValueListenable<RoutingConfig<F>> _routingConfig;

  /// The list of top level routes used by [GoRouterDelegate].
  List<RouteBase<F>> get routes => _routingConfig.value.routes;

  /// Top level page redirect.
  GoRouterRedirect<F> get topRedirect => _routingConfig.value.redirect;

  /// The limit for the number of consecutive redirects.
  int get redirectLimit => _routingConfig.value.redirectLimit;

  /// The global key for top level navigator.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The codec used to encode and decode extra into a serializable format.
  ///
  /// When navigating using [GoRouter.go] or [GoRouter.push], one can provide
  /// an `extra` parameter along with it. If the extra contains complex data,
  /// consider provide a codec for serializing and deserializing the extra data.
  ///
  /// See also:
  ///  * [Navigation](https://pub.dev/documentation/go_router/latest/topics/Navigation-topic.html)
  ///    topic.
  ///  * [extra_codec](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/extra_codec.dart)
  ///    example.
  final Codec<Object?, Object?>? extraCodec;

  final Map<String, String> _nameToPath = <String, String>{};

  /// Looks up the url location by a [GoRoute]'s name.
  String namedLocation(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
  }) {
    assert(() {
      log('getting location for name: '
          '"$name"'
          '${pathParameters.isEmpty ? '' : ', pathParameters: $pathParameters'}'
          '${queryParameters.isEmpty ? '' : ', queryParameters: $queryParameters'}');
      return true;
    }());
    assert(_nameToPath.containsKey(name), 'unknown route name: $name');
    final String path = _nameToPath[name]!;
    assert(() {
      // Check that all required params are present
      final List<String> paramNames = <String>[];
      patternToRegExp(path, paramNames);
      for (final String paramName in paramNames) {
        assert(pathParameters.containsKey(paramName),
            'missing param "$paramName" for $path');
      }

      // Check that there are no extra params
      for (final String key in pathParameters.keys) {
        assert(paramNames.contains(key), 'unknown param "$key" for $path');
      }
      return true;
    }());
    final Map<String, String> encodedParams = <String, String>{
      for (final MapEntry<String, String> param in pathParameters.entries)
        param.key: Uri.encodeComponent(param.value)
    };
    final String location = patternToPath(path, encodedParams);
    return Uri(
            path: location,
            queryParameters: queryParameters.isEmpty ? null : queryParameters)
        .toString();
  }

  /// Finds the routes that matched the given URL.
  RouteMatchList<F> findMatch(String location, {Object? extra}) {
    final Uri uri = Uri.parse(canonicalUri(location));

    final Map<String, String> pathParameters = <String, String>{};
    final List<RouteMatch<F>>? matches =
        _getLocRouteMatches(uri, pathParameters);

    if (matches == null) {
      return _errorRouteMatchList(
        uri,
        GoException('no routes for location: $uri'),
        extra: extra,
      );
    }
    return RouteMatchList<F>(
      matches: matches,
      uri: uri,
      pathParameters: pathParameters,
      extra: extra,
      titleBuilder: matches.lastOrNull?.route.titleBuilder,
    );
  }

  /// Reparse the input RouteMatchList
  RouteMatchList<F> reparse(RouteMatchList<F> matchList) {
    RouteMatchList<F> result =
        findMatch(matchList.uri.toString(), extra: matchList.extra);

    for (final ImperativeRouteMatch<F> imperativeMatch
        in matchList.matches.whereType<ImperativeRouteMatch<F>>()) {
      final ImperativeRouteMatch<F> match = ImperativeRouteMatch<F>(
          pageKey: imperativeMatch.pageKey,
          matches: findMatch(imperativeMatch.matches.uri.toString(),
              extra: imperativeMatch.matches.extra),
          completer: imperativeMatch.completer);
      result = result.push(match);
    }
    return result;
  }

  List<RouteMatch<F>>? _getLocRouteMatches(
      Uri uri, Map<String, String> pathParameters) {
    final List<RouteMatch<F>>? result = _getLocRouteRecursively(
      location: uri.path,
      remainingLocation: uri.path,
      matchedLocation: '',
      matchedPath: '',
      pathParameters: pathParameters,
      routes: _routingConfig.value.routes,
    );
    return result;
  }

  List<RouteMatch<F>>? _getLocRouteRecursively({
    required String location,
    required String remainingLocation,
    required String matchedLocation,
    required String matchedPath,
    required Map<String, String> pathParameters,
    required List<RouteBase<F>> routes,
  }) {
    List<RouteMatch<F>>? result;
    late Map<String, String> subPathParameters;
    // find the set of matches at this level of the tree
    for (final RouteBase<F> route in routes) {
      subPathParameters = <String, String>{};

      final RouteMatch<F>? match = RouteMatch.match(
        route: route,
        remainingLocation: remainingLocation,
        matchedLocation: matchedLocation,
        matchedPath: matchedPath,
        pathParameters: subPathParameters,
      );

      if (match == null) {
        continue;
      }

      if (match.route is GoRoute &&
          match.matchedLocation.toLowerCase() == location.toLowerCase()) {
        // If it is a complete match, then return the matched route
        // NOTE: need a lower case match because matchedLocation is canonicalized to match
        // the path case whereas the location can be of any case and still match
        result = <RouteMatch<F>>[match];
      } else if (route.routes.isEmpty) {
        // If it is partial match but no sub-routes, bail.
        continue;
      } else {
        // Otherwise, recurse
        final String childRestLoc;
        final String newParentSubLoc;
        final String newParentPath;
        if (match.route is ShellRouteBase) {
          childRestLoc = remainingLocation;
          newParentSubLoc = matchedLocation;
          newParentPath = matchedPath;
        } else {
          assert(location.startsWith(match.matchedLocation));
          assert(remainingLocation.isNotEmpty);

          childRestLoc = location.substring(match.matchedLocation.length +
              (match.matchedLocation == '/' ? 0 : 1));
          newParentSubLoc = match.matchedLocation;
          newParentPath =
              concatenatePaths(matchedPath, (match.route as GoRoute<F>).path);
        }

        final List<RouteMatch<F>>? subRouteMatch = _getLocRouteRecursively(
          location: location,
          remainingLocation: childRestLoc,
          matchedLocation: newParentSubLoc,
          matchedPath: newParentPath,
          pathParameters: subPathParameters,
          routes: route.routes,
        );

        // If there's no sub-route matches, there is no match for this location
        if (subRouteMatch == null) {
          continue;
        }
        result = <RouteMatch<F>>[match, ...subRouteMatch];
      }
      // Should only reach here if there is a match.
      break;
    }
    if (result != null) {
      pathParameters.addAll(subPathParameters);
    }
    return result;
  }

  /// Processes redirects by returning a new [RouteMatchList] representing the new
  /// location.
  FutureOr<RouteMatchList<F>> redirect(
      BuildContext context, FutureOr<RouteMatchList<F>> prevMatchListFuture,
      {required List<RouteMatchList<F>> redirectHistory}) {
    FutureOr<RouteMatchList<F>> processRedirect(
        RouteMatchList<F> prevMatchList) {
      final String prevLocation = prevMatchList.uri.toString();
      FutureOr<RouteMatchList<F>> processTopLevelRedirect(
          String? topRedirectLocation) {
        if (topRedirectLocation != null &&
            topRedirectLocation != prevLocation) {
          final RouteMatchList<F> newMatch = _getNewMatches(
            topRedirectLocation,
            prevMatchList.uri,
            redirectHistory,
          );
          if (newMatch.isError) {
            return newMatch;
          }
          return redirect(
            context,
            newMatch,
            redirectHistory: redirectHistory,
          );
        }

        FutureOr<RouteMatchList<F>> processRouteLevelRedirect(
            String? routeRedirectLocation) {
          if (routeRedirectLocation != null &&
              routeRedirectLocation != prevLocation) {
            final RouteMatchList<F> newMatch = _getNewMatches(
              routeRedirectLocation,
              prevMatchList.uri,
              redirectHistory,
            );

            if (newMatch.isError) {
              return newMatch;
            }
            return redirect(
              context,
              newMatch,
              redirectHistory: redirectHistory,
            );
          }
          return prevMatchList;
        }

        final FutureOr<String?> routeLevelRedirectResult =
            _getRouteLevelRedirect(context, prevMatchList, 0);
        if (routeLevelRedirectResult is String?) {
          return processRouteLevelRedirect(routeLevelRedirectResult);
        }
        return routeLevelRedirectResult
            .then<RouteMatchList<F>>(processRouteLevelRedirect);
      }

      redirectHistory.add(prevMatchList);
      // Check for top-level redirect
      final FutureOr<String?> topRedirectResult = _routingConfig.value.redirect(
        context,
        buildTopLevelGoRouterState(prevMatchList),
      );

      if (topRedirectResult is String?) {
        return processTopLevelRedirect(topRedirectResult);
      }
      return topRedirectResult.then<RouteMatchList<F>>(processTopLevelRedirect);
    }

    if (prevMatchListFuture is RouteMatchList<F>) {
      return processRedirect(prevMatchListFuture);
    }
    return prevMatchListFuture.then<RouteMatchList<F>>(processRedirect);
  }

  FutureOr<String?> _getRouteLevelRedirect(
    BuildContext context,
    RouteMatchList<F> matchList,
    int currentCheckIndex,
  ) {
    if (currentCheckIndex >= matchList.matches.length) {
      return null;
    }
    final RouteMatch<F> match = matchList.matches[currentCheckIndex];
    FutureOr<String?> processRouteRedirect(String? newLocation) =>
        newLocation ??
        _getRouteLevelRedirect(context, matchList, currentCheckIndex + 1);
    final RouteBase<F> route = match.route;
    FutureOr<String?> routeRedirectResult;
    if (route is GoRoute<F> && route.redirect != null) {
      final RouteMatchList<F> effectiveMatchList =
          match is ImperativeRouteMatch<F> ? match.matches : matchList;
      routeRedirectResult = route.redirect!(
        context,
        GoRouterState<F>(
          this,
          uri: effectiveMatchList.uri,
          matchedLocation: match.matchedLocation,
          name: route.name,
          path: route.path,
          fullPath: effectiveMatchList.fullPath,
          extra: effectiveMatchList.extra,
          pathParameters: effectiveMatchList.pathParameters,
          pageKey: match.pageKey,
          matchList: effectiveMatchList,
        ),
      );
    }
    if (routeRedirectResult is String?) {
      return processRouteRedirect(routeRedirectResult);
    }
    return routeRedirectResult.then<String?>(processRouteRedirect);
  }

  RouteMatchList<F> _getNewMatches(
    String newLocation,
    Uri previousLocation,
    List<RouteMatchList<F>> redirectHistory,
  ) {
    try {
      final RouteMatchList<F> newMatch = findMatch(newLocation);
      _addRedirect(redirectHistory, newMatch, previousLocation);
      return newMatch;
    } on GoException catch (e) {
      log('Redirection exception: ${e.message}');
      return _errorRouteMatchList(previousLocation, e);
    }
  }

  /// Adds the redirect to [redirects] if it is valid.
  ///
  /// Throws if a loop is detected or the redirection limit is reached.
  void _addRedirect(
    List<RouteMatchList<F>> redirects,
    RouteMatchList<F> newMatch,
    Uri prevLocation,
  ) {
    if (redirects.contains(newMatch)) {
      throw GoException(
          'redirect loop detected ${_formatRedirectionHistory(<RouteMatchList<F>>[
            ...redirects,
            newMatch
          ])}');
    }
    if (redirects.length > _routingConfig.value.redirectLimit) {
      throw GoException(
          'too many redirects ${_formatRedirectionHistory(<RouteMatchList<F>>[
            ...redirects,
            newMatch
          ])}');
    }

    redirects.add(newMatch);

    log('redirecting to $newMatch');
  }

  String _formatRedirectionHistory(List<RouteMatchList<F>> redirections) {
    return redirections
        .map<String>(
            (RouteMatchList<F> routeMatches) => routeMatches.uri.toString())
        .join(' => ');
  }

  /// Get the location for the provided route.
  ///
  /// Builds the absolute path for the route, by concatenating the paths of the
  /// route and all its ancestors.
  String? locationForRoute(RouteBase<F> route) =>
      fullPathForRoute(route, '', _routingConfig.value.routes);

  @override
  String toString() {
    return 'RouterConfiguration: ${_routingConfig.value.routes}';
  }

  /// Returns the full path of [routes].
  ///
  /// Each path is indented based depth of the hierarchy, and its `name`
  /// is also appended if not null
  @visibleForTesting
  String debugKnownRoutes() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('Full paths for routes:');
    _debugFullPathsFor(_routingConfig.value.routes, '', 0, sb);

    if (_nameToPath.isNotEmpty) {
      sb.writeln('known full paths for route names:');
      for (final MapEntry<String, String> e in _nameToPath.entries) {
        sb.writeln('  ${e.key} => ${e.value}');
      }
    }

    return sb.toString();
  }

  void _debugFullPathsFor(List<RouteBase<F>> routes, String parentFullpath,
      int depth, StringBuffer sb) {
    for (final RouteBase<F> route in routes) {
      if (route is GoRoute<F>) {
        final String fullPath = concatenatePaths(parentFullpath, route.path);
        sb.writeln('  => ${''.padLeft(depth * 2)}$fullPath');
        _debugFullPathsFor(route.routes, fullPath, depth + 1, sb);
      } else if (route is ShellRouteBase) {
        _debugFullPathsFor(route.routes, parentFullpath, depth, sb);
      }
    }
  }

  void _cacheNameToPath(String parentFullPath, List<RouteBase<F>> childRoutes) {
    for (final RouteBase<F> route in childRoutes) {
      if (route is GoRoute<F>) {
        final String fullPath = concatenatePaths(parentFullPath, route.path);

        if (route.name != null) {
          final String name = route.name!;
          assert(
              !_nameToPath.containsKey(name),
              'duplication fullpaths for name '
              '"$name":${_nameToPath[name]}, $fullPath');
          _nameToPath[name] = fullPath;
        }

        if (route.routes.isNotEmpty) {
          _cacheNameToPath(fullPath, route.routes);
        }
      } else if (route is ShellRouteBase<F>) {
        if (route.routes.isNotEmpty) {
          _cacheNameToPath(parentFullPath, route.routes);
        }
      }
    }
  }
}
