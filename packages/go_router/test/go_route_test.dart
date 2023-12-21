// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_helpers.dart';

void main() {
  test('throws when a builder is not set', () {
    expect(() => GoRoute(path: '/'), throwsA(isAssertionError));
  });

  test('throws when a path is empty', () {
    expect(() => GoRoute(path: ''), throwsA(isAssertionError));
  });

  test('does not throw when only redirect is provided', () {
    GoRoute(path: '/', redirect: (_, __) => '/a');
  });

  testWidgets('ShellRoute can use parent navigator key',
      (WidgetTester tester) async {
    final GlobalKey<NavigatorState> rootNavigatorKey =
        GlobalKey<NavigatorState>();
    final GlobalKey<NavigatorState> shellNavigatorKey =
        GlobalKey<NavigatorState>();

    final List<RouteBase> routes = <RouteBase>[
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (_, __, Widget child) {
          return Scaffold(
            body: Column(
              children: <Widget>[
                const Text('Screen A'),
                Expanded(child: child),
              ],
            ),
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/b',
            builder: (_, __) {
              return const Scaffold(
                body: Text('Screen B'),
              );
            },
            routes: <RouteBase>[
              ShellRoute(
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, __, Widget child) {
                  return Scaffold(
                    body: Column(
                      children: <Widget>[
                        const Text('Screen D'),
                        Expanded(child: child),
                      ],
                    ),
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'c',
                    builder: (_, __) {
                      return const Scaffold(
                        body: Text('Screen C'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

    await createRouter(routes, tester,
        initialLocation: '/b/c', navigatorKey: rootNavigatorKey);
    expect(find.text('Screen A'), findsNothing);
    expect(find.text('Screen B'), findsNothing);
    expect(find.text('Screen D'), findsOneWidget);
    expect(find.text('Screen C'), findsOneWidget);
  });

  testWidgets('StatefulShellRoute can use parent navigator key',
      (WidgetTester tester) async {
    final GlobalKey<NavigatorState> rootNavigatorKey =
        GlobalKey<NavigatorState>();
    final GlobalKey<NavigatorState> shellNavigatorKey =
        GlobalKey<NavigatorState>();

    final List<RouteBase> routes = <RouteBase>[
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (_, __, Widget child) {
          return Scaffold(
            body: Column(
              children: <Widget>[
                const Text('Screen A'),
                Expanded(child: child),
              ],
            ),
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/b',
            builder: (_, __) {
              return const Scaffold(
                body: Text('Screen B'),
              );
            },
            routes: <RouteBase>[
              StatefulShellRoute.indexedStack(
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, __, StatefulNavigationShell navigationShell) {
                  return Column(
                    children: <Widget>[
                      const Text('Screen D'),
                      Expanded(child: navigationShell),
                    ],
                  );
                },
                branches: <StatefulShellBranch>[
                  StatefulShellBranch(
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'c',
                        builder: (_, __) {
                          return const Scaffold(
                            body: Text('Screen C'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

    await createRouter(routes, tester,
        initialLocation: '/b/c', navigatorKey: rootNavigatorKey);
    expect(find.text('Screen A'), findsNothing);
    expect(find.text('Screen B'), findsNothing);
    expect(find.text('Screen D'), findsOneWidget);
    expect(find.text('Screen C'), findsOneWidget);
  });

  test('ShellRoute parent navigator key throw if not match', () async {
    final GlobalKey<NavigatorState> key1 = GlobalKey<NavigatorState>();
    final GlobalKey<NavigatorState> key2 = GlobalKey<NavigatorState>();
    bool hasError = false;
    try {
      ShellRoute(
        navigatorKey: key1,
        builder: (_, __, Widget child) => child,
        routes: <RouteBase>[
          ShellRoute(
            parentNavigatorKey: key2,
            builder: (_, __, Widget child) => child,
            routes: <RouteBase>[
              GoRoute(
                path: '1',
                builder: (_, __) => const Text('/route/1'),
              ),
            ],
          ),
        ],
      );
    } on AssertionError catch (_) {
      hasError = true;
    }
    expect(hasError, isTrue);
  });

  group('GoRoute titleBuilder', () {
    testWidgets('GoRoute titleBuilder Changes with Route Change',
        (WidgetTester tester) async {
      final UniqueKey aKey = UniqueKey();
      final UniqueKey bKey = UniqueKey();
      final List<GoRoute<CustomData>> routes = <GoRoute<CustomData>>[
        GoRoute(
          path: '/a',
          titleBuilder: (_, __) => const CustomData('A'),
          builder: (_, __) => Builder(builder: (BuildContext context) {
            return Text(
              key: aKey,
              GoRouterState.of<CustomData>(context)
                      .titleBuilder
                      ?.call(context)
                      .value ??
                  '',
            );
          }),
          routes: <GoRoute<CustomData>>[
            GoRoute(
              path: 'b',
              titleBuilder: (_, __) => const CustomData('B'),
              builder: (_, __) => Builder(builder: (BuildContext context) {
                return Text(
                  key: bKey,
                  GoRouterState.of<CustomData>(context)
                          .titleBuilder
                          ?.call(context)
                          .value ??
                      '',
                );
              }),
            ),
          ],
        ),
      ];
      final GoRouter<CustomData> router =
          await createRouter<CustomData>(routes, tester, initialLocation: '/a');
      expect(tester.widget<Text>(find.byKey(aKey)).data, 'A');

      router.go('/a/b');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(bKey)).data, 'B');
    });

    testWidgets('GoRoute titleBuilder accessible from StatefulShellRoute',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> shellNavigatorKey =
          GlobalKey<NavigatorState>();
      final List<RouteBase<CustomData>> routes = <RouteBase<CustomData>>[
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (_, __, Widget child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Screen 0'),
                  Expanded(child: child),
                ],
              ),
            );
          },
          routes: <RouteBase<CustomData>>[
            GoRoute(
              path: '/',
              builder: (_, __) {
                return const Scaffold(
                  body: Text('Screen 1'),
                );
              },
              routes: <RouteBase<CustomData>>[
                StatefulShellRoute<CustomData>.indexedStack(
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (BuildContext context,
                      GoRouterState<CustomData> state,
                      StatefulNavigationShell navigationShell) {
                    return Column(
                      children: <Widget>[
                        Text(state.titleBuilder?.call(context).value ??
                            'No Title'),
                        Expanded(child: navigationShell),
                      ],
                    );
                  },
                  branches: <StatefulShellBranch<CustomData>>[
                    StatefulShellBranch(
                      routes: <RouteBase<CustomData>>[
                        GoRoute(
                          path: 'a',
                          titleBuilder: (_, __) => const CustomData('A'),
                          builder: (_, __) {
                            return const Scaffold(
                              body: Text('Screen 2'),
                            );
                          },
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: <RouteBase<CustomData>>[
                        GoRoute(
                          path: 'b',
                          titleBuilder: (_, __) => const CustomData('B'),
                          builder: (_, __) {
                            return const Scaffold(
                              body: Text('Screen 2'),
                            );
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ],
            )
          ],
        ),
      ];
      final GoRouter<CustomData> router = await createRouter(routes, tester,
          initialLocation: '/a', navigatorKey: rootNavigatorKey);
      expect(find.text('A'), findsOneWidget);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('Redirect only GoRoute', () {
    testWidgets('can redirect to subroute', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('home'),
            routes: <RouteBase>[
              GoRoute(
                path: 'route',
                redirect: (_, __) => '/route/1',
                routes: <RouteBase>[
                  GoRoute(
                    path: '1',
                    builder: (_, __) => const Text('/route/1'),
                  ),
                ],
              ),
            ],
          ),
        ],
        tester,
      );
      expect(find.text('home'), findsOneWidget);

      router.go('/route');
      await tester.pumpAndSettle();
      // Should redirect to /route/1 without error.
      expect(find.text('/route/1'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      // Should go back directly to home page.
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('throw if redirect to itself.', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('home'),
            routes: <RouteBase>[
              GoRoute(
                path: 'route',
                redirect: (_, __) => '/route',
                routes: <RouteBase>[
                  GoRoute(
                    path: '1',
                    builder: (_, __) => const Text('/route/1'),
                  ),
                ],
              ),
            ],
          ),
        ],
        tester,
      );
      expect(find.text('home'), findsOneWidget);

      router.go('/route');
      await tester.pumpAndSettle();
      // Should redirect to /route/1 without error.
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('throw if sub route does not conform with parent navigator key',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key1 = GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> key2 = GlobalKey<NavigatorState>();
      bool hasError = false;
      try {
        ShellRoute(
          navigatorKey: key1,
          builder: (_, __, Widget child) => child,
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              redirect: (_, __) => '/route',
              routes: <RouteBase>[
                GoRoute(
                  parentNavigatorKey: key2,
                  path: 'route',
                  builder: (_, __) => const Text('/route/1'),
                ),
              ],
            ),
          ],
        );
      } on AssertionError catch (_) {
        hasError = true;
      }
      expect(hasError, isTrue);
    });
  });
}

class CustomData {
  const CustomData(this.value);
  final String value;
}
