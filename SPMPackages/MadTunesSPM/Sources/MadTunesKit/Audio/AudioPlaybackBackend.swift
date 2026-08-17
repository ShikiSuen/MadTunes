// (c) 2026 and onwards Shiki Suen (AGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `AGPL-3.0-or-later`.

import Foundation

// MARK: - PlaybackEngineKind

/// Phase 176: Selectable playback pipeline backend.
public enum PlaybackEngineKind: Int, Sendable {
  /// AVPlayer / CoreAudio pipeline (default).
  case avPlayer = 0
  /// AVAudioEngine + AVAudioPlayerNode pipeline (experimental).
  case avAudioEngine = 1
}

// MARK: - AudioPlaybackBackend

/// Phase 176: Abstraction over the actual playback pipeline (AVPlayer or
/// AVAudioEngine). `AudioPlayer` owns the queue, Now Playing integration and
/// loop behavior; a backend only knows how to render one file at a time.
///
/// All methods are invoked on the main actor, and all callbacks fire on the
/// main actor.
@MainActor
protocol AudioPlaybackBackend: AnyObject {
  /// Which pipeline this backend implements.
  var kind: PlaybackEngineKind { get }

  /// Called once when the loaded file is ready to play. Payload: duration in
  /// seconds (0 when the duration could not be determined).
  var onReadyToPlay: (@MainActor (TimeInterval) -> Void)? { get set }
  /// Periodic playback progress. Payloads: current time, duration.
  var onPeriodicTime: (@MainActor (TimeInterval, TimeInterval) -> Void)? { get set }
  /// The file played to its natural end (repeat-one did not intercept it).
  var onNaturalEnd: (@MainActor () -> Void)? { get set }
  /// The backend failed to load or render the file.
  var onFailure: (@MainActor () -> Void)? { get set }
  /// Playback was paused or resumed by the system itself
  /// (e.g. an iOS audio-session interruption). Payload: isPlaying.
  var onExternalPlayStateChange: (@MainActor (Bool) -> Void)? { get set }

  /// Output volume (0...1), applied live.
  var volume: Float { get set }
  /// Whether the backend should loop the current file by itself (repeat-one).
  var repeatOneRequested: Bool { get set }

  /// Load `url` and start (or, when `autoPlay` is false, merely arm) playback
  /// at `startAt` seconds into the file.
  func play(url: URL, startAt: TimeInterval, autoPlay: Bool)
  func pause()
  func resume()
  func stop()
  func seek(to time: TimeInterval)

  #if os(macOS)
  /// Route output to the device with the given UID (`nil` = system default).
  func setOutputDevice(uid: String?)
  #endif
}
