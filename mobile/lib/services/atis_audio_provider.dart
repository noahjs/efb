import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'api_client.dart';

class AtisAudioState {
  final bool isPlaying;
  final bool isLoading;
  final String? error;

  const AtisAudioState({
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
  });

  AtisAudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AtisAudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AtisAudioNotifier extends Notifier<AtisAudioState> {
  final String airportId;
  AudioPlayer? _player;
  StreamSubscription? _playerSub;

  AtisAudioNotifier(this.airportId);

  @override
  AtisAudioState build() {
    ref.onDispose(() {
      _playerSub?.cancel();
      _player?.dispose();
    });
    return const AtisAudioState();
  }

  Future<void> play() async {
    // If loading or playing, stop instead
    if (state.isLoading || state.isPlaying) {
      await stop();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final url = await apiClient.getAtisAudioUrl(airportId);

      if (!ref.mounted) return;

      if (url == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No audio available',
        );
        return;
      }

      _playerSub?.cancel();
      _player?.dispose();
      _player = AudioPlayer();

      // Listen for playback completion
      _playerSub = _player!.playerStateStream.listen((playerState) {
        if (!ref.mounted) return;
        if (playerState.processingState == ProcessingState.completed) {
          state = state.copyWith(isPlaying: false, isLoading: false);
        }
      });

      await _player!.setUrl(url);

      if (!ref.mounted) return;

      await _player!.play();

      if (!ref.mounted) return;

      state = state.copyWith(isPlaying: true, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to play audio',
      );
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    if (!ref.mounted) return;
    state = state.copyWith(isPlaying: false, isLoading: false);
  }
}

/// Auto-dispose provider keyed by airport ID.
/// When the airport detail screen is left, the provider disposes and audio stops.
final atisAudioProvider =
    NotifierProvider.autoDispose.family<AtisAudioNotifier, AtisAudioState, String>(
  (airportId) => AtisAudioNotifier(airportId),
);
