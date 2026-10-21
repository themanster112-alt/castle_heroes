/// A server-time anchor advanced by a monotonic timer, independent of device time.
class ServerClock {
  final Stopwatch _elapsed = Stopwatch()..start();
  final Duration Function()? readElapsed;
  DateTime? _anchor;
  Duration _anchoredAt = Duration.zero;
  ServerClock({this.readElapsed});
  Duration get elapsed => readElapsed?.call() ?? _elapsed.elapsed;
  bool get synchronized => _anchor != null;
  Duration get age => elapsed - _anchoredAt;
  void synchronize(DateTime serverTime, {Duration roundTrip = Duration.zero}) {
    _anchor = serverTime.add(
      Duration(microseconds: roundTrip.inMicroseconds ~/ 2),
    );
    _anchoredAt = elapsed;
  }

  DateTime get now {
    if (_anchor == null) throw StateError('وقت الخادم غير متاح');
    return _anchor!.add(age);
  }
}
