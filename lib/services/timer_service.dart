import 'dart:async';

class CountdownService {
  Timer? _timer;
  int _secondsRemaining = 0;
  void Function(int)? onTick;
  void Function()? onFinished;

  int get secondsRemaining => _secondsRemaining;

  void start(int seconds, {void Function(int)? onTick, void Function()? onFinished}) {
    stop();
    _secondsRemaining = seconds;
    this.onTick = onTick;
    this.onFinished = onFinished;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        this.onTick?.call(_secondsRemaining);
      } else {
        stop();
        this.onFinished?.call();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
