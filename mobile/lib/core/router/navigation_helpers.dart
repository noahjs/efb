import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension GoRouterBackNav on BuildContext {
  /// Pop the current route with the correct back animation.
  /// Falls back to [fallbackRoute] via `go()` if there is nothing to pop.
  void goBack([String? fallbackRoute]) {
    if (canPop()) {
      pop();
    } else if (fallbackRoute != null) {
      go(fallbackRoute);
    }
  }
}
