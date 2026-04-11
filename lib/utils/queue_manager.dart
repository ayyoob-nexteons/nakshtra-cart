import 'dart:async';

class QueueManager {
  // Singleton instance
  static final QueueManager _instance = QueueManager._internal();

  // Factory constructor that returns the singleton instance
  factory QueueManager() => _instance;

  // Private constructor
  QueueManager._internal();

  // Queue to hold API calls with Completer to handle return values
  final List<_ApiTask> _apiQueue = [];

  // Indicates if an API call is in progress
  bool _isProcessing = false;

  // Add API call to the queue and return a Future that completes with the result
  Future<T?> enqueueCall<T>(Function apiCall, [List<dynamic>? params]) {
    final completer = Completer<T?>();

    // Wrap the API call to handle parameters
    wrappedApiCall() async {
      try {
        final result = await Function.apply(apiCall, params);
        completer.complete(result as T?);
      } catch (e) {
        completer.completeError(e);
      }
    }

    _apiQueue.add(_ApiTask(wrappedApiCall, completer));
    _processQueue();
    return completer.future;
  }

  // Process the queue
  void _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_apiQueue.isNotEmpty) {
      final task = _apiQueue.removeAt(0);

      try {
        await task.apiCall();
      } catch (e) {
        task.completer.completeError(e);
      }
    }

    _isProcessing = false;
  }
}

// Helper class to store each API call and its associated Completer
class _ApiTask<T> {
  final Future<void> Function() apiCall;
  final Completer<T?> completer;

  _ApiTask(this.apiCall, this.completer);
}
