class ScrollRetentionState {
  static final ScrollRetentionState _instance =
      ScrollRetentionState._internal();
  factory ScrollRetentionState() => _instance;
  ScrollRetentionState._internal();

  bool _shouldRetain = false;
  void Function()? _listener;

  bool get shouldRetainPosition => _shouldRetain;

  void updateShouldRetain(bool shouldRetain) {
    if (_shouldRetain != shouldRetain) {
      _shouldRetain = shouldRetain;
      _listener?.call();
    }
  }
}
