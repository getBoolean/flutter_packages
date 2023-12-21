// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'configuration.dart';
import 'information_provider.dart';
import 'logging.dart';
import 'match.dart';
import 'route.dart';
import 'router.dart';

/// The function signature of [GoRouteInformationParser.onParserException].
///
/// The `routeMatchList` parameter contains the exception explains the issue
/// occurred.
///
/// The returned [RouteMatchList] is used as parsed result for the
/// [GoRouterDelegate].
typedef ParserExceptionHandler<F> = RouteMatchList<F> Function(
  BuildContext context,
  RouteMatchList<F> routeMatchList,
);

/// Converts between incoming URLs and a [RouteMatchList] using [RouteMatcher].
/// Also performs redirection using [RouteRedirector].
@optionalTypeArgs
class GoRouteInformationParser<F>
    extends RouteInformationParser<RouteMatchList<F>> {
  /// Creates a [GoRouteInformationParser].
  GoRouteInformationParser({
    required this.configuration,
    required this.onParserException,
  }) : _routeMatchListCodec = RouteMatchListCodec<F>(configuration);

  /// The route configuration used for parsing [RouteInformation]s.
  final RouteConfiguration<F> configuration;

  /// The exception handler that is called when parser can't handle the incoming
  /// uri.
  ///
  /// This method must return a [RouteMatchList] for the parsed result.
  final ParserExceptionHandler<F>? onParserException;

  final RouteMatchListCodec<F> _routeMatchListCodec;

  final Random _random = Random();

  /// The future of current route parsing.
  ///
  /// This is used for testing asynchronous redirection.
  @visibleForTesting
  Future<RouteMatchList<F>>? debugParserFuture;

  /// Called by the [Router]. The
  @override
  Future<RouteMatchList<F>> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    assert(routeInformation.state != null);
    final Object state = routeInformation.state!;

    if (state is! RouteInformationState<void, F>) {
      // This is a result of browser backward/forward button or state
      // restoration. In this case, the route match list is already stored in
      // the state.
      final RouteMatchList<F> matchList =
          _routeMatchListCodec.decode(state as Map<Object?, Object?>);
      return debugParserFuture = _redirect(context, matchList)
          .then<RouteMatchList<F>>((RouteMatchList<F> value) {
        if (value.isError && onParserException != null) {
          return onParserException!(context, value);
        }
        return value;
      });
    }

    late final RouteMatchList<F> initialMatches;
    initialMatches =
        // TODO(chunhtai): remove this ignore and migrate the code
        // https://github.com/flutter/flutter/issues/124045.
        // TODO(chunhtai): After the migration from routeInformation's location
        // to uri, empty path check might be required here; see
        // https://github.com/flutter/packages/pull/5113#discussion_r1374861070
        // ignore: deprecated_member_use, unnecessary_non_null_assertion
        configuration.findMatch(routeInformation.location!, extra: state.extra);
    if (initialMatches.isError) {
      // TODO(chunhtai): remove this ignore and migrate the code
      // https://github.com/flutter/flutter/issues/124045.
      // ignore: deprecated_member_use
      log('No initial matches: ${routeInformation.location}');
    }

    return debugParserFuture = _redirect(
      context,
      initialMatches,
    ).then<RouteMatchList<F>>((RouteMatchList<F> matchList) {
      if (matchList.isError && onParserException != null) {
        return onParserException!(context, matchList);
      }

      assert(() {
        if (matchList.isNotEmpty) {
          assert(!(matchList.last.route as GoRoute<F>).redirectOnly,
              'A redirect-only route must redirect to location different from itself.\n The offending route: ${matchList.last.route}');
        }
        return true;
      }());
      return _updateRouteMatchList(
        matchList,
        baseRouteMatchList: state.baseRouteMatchList,
        completer: state.completer,
        type: state.type,
      );
    });
  }

  @override
  Future<RouteMatchList<F>> parseRouteInformation(
      RouteInformation routeInformation) {
    throw UnimplementedError(
        'use parseRouteInformationWithDependencies instead');
  }

  /// for use by the Router architecture as part of the RouteInformationParser
  @override
  RouteInformation? restoreRouteInformation(RouteMatchList<F> configuration) {
    if (configuration.isEmpty) {
      return null;
    }
    final String location;
    if (GoRouter.optionURLReflectsImperativeAPIs &&
        configuration.matches.last is ImperativeRouteMatch) {
      location = (configuration.matches.last as ImperativeRouteMatch<F>)
          .matches
          .uri
          .toString();
    } else {
      location = configuration.uri.toString();
    }
    return RouteInformation(
      // TODO(chunhtai): remove this ignore and migrate the code
      // https://github.com/flutter/flutter/issues/124045.
      // ignore: deprecated_member_use
      location: location,
      state: _routeMatchListCodec.encode(configuration),
    );
  }

  Future<RouteMatchList<F>> _redirect(
      BuildContext context, RouteMatchList<F> routeMatch) {
    final FutureOr<RouteMatchList<F>> redirectedFuture = configuration
        .redirect(context, routeMatch, redirectHistory: <RouteMatchList<F>>[]);
    if (redirectedFuture is RouteMatchList<F>) {
      return SynchronousFuture<RouteMatchList<F>>(redirectedFuture);
    }
    return redirectedFuture;
  }

  RouteMatchList<F> _updateRouteMatchList(
    RouteMatchList<F> newMatchList, {
    required RouteMatchList<F>? baseRouteMatchList,
    required Completer<Object?>? completer,
    required NavigatingType type,
  }) {
    switch (type) {
      case NavigatingType.push:
        return baseRouteMatchList!.push(
          ImperativeRouteMatch<F>(
            pageKey: _getUniqueValueKey(),
            completer: completer!,
            matches: newMatchList,
          ),
        );
      case NavigatingType.pushReplacement:
        final RouteMatch<F> routeMatch = baseRouteMatchList!.last;
        return baseRouteMatchList.remove(routeMatch).push(
              ImperativeRouteMatch<F>(
                pageKey: _getUniqueValueKey(),
                completer: completer!,
                matches: newMatchList,
              ),
            );
      case NavigatingType.replace:
        final RouteMatch<F> routeMatch = baseRouteMatchList!.last;
        return baseRouteMatchList.remove(routeMatch).push(
              ImperativeRouteMatch<F>(
                pageKey: routeMatch.pageKey,
                completer: completer!,
                matches: newMatchList,
              ),
            );
      case NavigatingType.go:
        return newMatchList;
      case NavigatingType.restore:
        // Still need to consider redirection.
        return baseRouteMatchList!.uri.toString() != newMatchList.uri.toString()
            ? newMatchList
            : baseRouteMatchList;
    }
  }

  ValueKey<String> _getUniqueValueKey() {
    return ValueKey<String>(String.fromCharCodes(
        List<int>.generate(32, (_) => _random.nextInt(33) + 89)));
  }
}
