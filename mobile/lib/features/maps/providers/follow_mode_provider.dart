import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FollowMode { off, northUp, trackUp }

class FollowModeNotifier extends Notifier<FollowMode> {
  @override
  FollowMode build() => FollowMode.off;

  void set(FollowMode mode) {
    state = mode;
  }
}

final followModeProvider =
    NotifierProvider<FollowModeNotifier, FollowMode>(FollowModeNotifier.new);
