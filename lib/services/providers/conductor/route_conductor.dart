import 'dart:async';
import 'dart:developer';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:webrtc_test/events/event.dart';
import 'package:webrtc_test/events/navigation_events.dart';
import 'package:webrtc_test/providers/auth/auth_notifier.dart';
import 'package:webrtc_test/providers/auth/user_state.dart';
import 'package:webrtc_test/routes/app_router.gr.dart';
import 'package:webrtc_test/services/interfaces/conductor/route_conductor.dart';
import 'package:webrtc_test/services/interfaces/conductor/ticket_stamper.dart';
import 'package:webrtc_test/services/providers/conductor/ticket_stamper.dart';

part 'conductor_state.dart';

final routeConductorProvider =
    Provider.family<IRouteConductor, AppRouter>((ref, AppRouter router) {
  return RouteConductor(
    router,
    ref.read(appEventBusProvider),
    ref.read(authStateProvider.stream),
  );
});

class RouteConductor extends StateNotifier<ConductorState>
    implements IRouteConductor {
  final AppRouter _router;
  final EventBus _eventBus;
  final Stream<UserState> _userState;

  late final StreamSubscription _busSubscription;
  late final StreamSubscription _subscription;

  final TicketStamperObserver _observer = TicketStamperObserver();

  @override
  TicketStamper get stamper => _observer;
  @override
  NavigatorObserver get observer => _observer;

  RouteConductor(this._router, this._eventBus, this._userState)
      : super(InitialConductorState()) {
    _subscription = _eventBus
        .on<BeginNavigationEvent>()
        .first
        .asStream()
        .switchMap((value) => _userState)
        .asyncMap(createState)
        .whereType<ConductorState>()
        .distinct((a, b) => a.runtimeType == b.runtimeType)
        .listen((state) {
      this.state = state;
    });
    _busSubscription =
        _eventBus.on<NavigationEvent>().listen(handleNavigationEvent);

    addListener(
      (state) => state._complete(Future.sync(() => handleState(state))),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _subscription.cancel();
    _busSubscription.cancel();
  }

  void handleNavigationEvent(NavigationEvent event) async {
    if (event is AuthRequiredNavigationEvent) {
      final finished = _router.push(const LoginRoute());
      if (event.onResult != null) {
        final isAuth = stream.firstWhere((element) => element.auth);
        final done = await Future.any([isAuth, finished]);
        if (done is ConductorState) {
          await done.awaitHandle;
          event.onResult?.call(true);
        } else {
          event.onResult?.call(false);
        }
      }
    }
  }

  FutureOr<ConductorState?> createState(UserState userState) {
    log("Received user state ${userState.runtimeType}");
    if (userState is LoadingUserState) {
      return LoadingConductorState();
    } else if (userState is AuthenticatedUserState) {
      return MainConductorState();
    } else {
      return AuthRequiredConductorState();
    }
  }

  void handleState(ConductorState state) {
    log("Received conductor state ${state.runtimeType}");
    if (state is LoadingConductorState) {
      _router.popUntilRoot();
      _router.replace(const LoadingRoute());
    } else if (state is AuthRequiredConductorState) {
      _router.popUntilRoot();
      _router.replace<void>(const LoginRoute());
    } else if (state is MainConductorState) {
      log("Going");
      _router.popUntilRoot();
      _router.replace<void>(const RoomsRoute());
    }
  }
}
