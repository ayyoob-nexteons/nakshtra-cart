import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Internal state for a single room's WebSocket connection.
class _RoomConn {
  WebSocketChannel? channel;
  StreamSubscription<dynamic>? sub;
  Timer? pingTimer;
  Timer? reconnectTimer;
  bool closed = false;
  int refCount = 0; // ← Tracks how many listeners depend on this room
}

/// Singleton WebSocket service.
///
/// Supports multiple simultaneous rooms (one per screen).
/// Each screen calls connect(roomId) / disconnect(roomId) independently,
/// so navigating between screens never kills another screen's connection.
///
/// Usage:
///   // In initState
///   WebSocketService.instance.connect('cartlistscreen');
///   _wsSub = WebSocketService.instance.messageStream.listen((msg) { … });
///
///   // After add/remove
///   WebSocketService.instance.broadcast('cartlistscreen', 'removed');
///
///   // In dispose
///   _wsSub?.cancel();
///   WebSocketService.instance.disconnect('cartlistscreen');
class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  static const String _baseUrl = 'wss://api.websocket.salonsyncs.com';
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // One entry per active roomId
  final Map<String, _RoomConn> _rooms = {};

  // All rooms share one broadcast stream so screens can listen once
  final StreamController<Map<String, dynamic>> _ctrl =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Subscribe to this to receive incoming WebSocket messages from any room.
  Stream<Map<String, dynamic>> get messageStream => _ctrl.stream;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Open a connection for [roomId] (lowercased automatically).
  /// Safe to call multiple times — idempotent if already connected.
  void connect(String roomId) {
    final id = _normalize(roomId);
    final existing = _rooms[id];
    if (existing != null) {
      existing.refCount++;
      debugPrint('[WS] ✓ Already connected to room=$id (refCount=${existing.refCount})');
      return;
    }
    debugPrint('[WS] → Connecting to room=$id');
    final conn = _RoomConn()..refCount = 1;
    _rooms[id] = conn;
    _doConnect(id, conn);
  }

  /// Close only the connection for [roomId].
  /// Other rooms remain unaffected.
  void disconnect(String roomId) {
    final id = _normalize(roomId);
    final conn = _rooms[id];
    if (conn == null) {
      debugPrint('[WS] disconnect: room=$id not found (already closed?)');
      return;
    }

    conn.refCount--;
    debugPrint('[WS] -- Decremented count for room=$id (remaining=${conn.refCount})');

    if (conn.refCount <= 0) {
      debugPrint('[WS] ✕ Disconnecting room=$id (refCount is zero)');
      _rooms.remove(id);
      conn.closed = true;
      _tearDown(conn);
    }
  }

  /// Send a broadcast event on the specified room.
  ///
  /// [data] is the payload sent inside the `"data"` field, e.g.:
  ///   {"event": "removed", "cartId": "xxx"}
  ///   {"event": "added",   "cart": { ...Cart fields... }}
  void broadcast(String roomId, Map<String, dynamic> data) {
    final id = _normalize(roomId);
    final conn = _rooms[id];
    if (conn == null || conn.channel == null) {
      debugPrint('[WS] broadcast FAILED — no active connection for room=$id');
      return;
    }
    final payload = jsonEncode({
      'action': 'broadcast',
      'roomId': id,
      'data': data,
    });
    try {
      conn.channel!.sink.add(payload);
      debugPrint('[WS] ↑ broadcast room=$id data=$data');
    } catch (e) {
      debugPrint('[WS] broadcast error room=$id: $e');
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _doConnect(String roomId, _RoomConn conn) async {
    if (conn.closed) return;

    // Tear down any existing socket (keeps timers for reconnect scheduling)
    _tearDown(conn, keepTimers: true);

    final uri = Uri.parse('$_baseUrl?roomId=$roomId');
    debugPrint('[WS] Opening socket → $uri');

    WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
      conn.channel = channel;
      // Wait for the handshake to complete (web_socket_channel ≥ 3.x)
      await channel.ready;
      debugPrint('[WS] ✓ Handshake complete for room=$roomId');
    } catch (e) {
      debugPrint('[WS] ✗ Handshake failed room=$roomId: $e');
      conn.channel = null;
      if (!conn.closed) _scheduleReconnect(roomId, conn);
      return;
    }

    if (conn.closed) {
      debugPrint('[WS] room=$roomId was closed during connect — aborting');
      _tearDown(conn);
      return;
    }

    // Listen to incoming messages
    conn.sub = channel.stream.listen(
      (raw) => _onMessage(roomId, raw),
      onError: (Object e) {
        debugPrint('[WS] Stream error room=$roomId: $e');
        if (!conn.closed) {
          _tearDown(conn, keepTimers: true);
          _scheduleReconnect(roomId, conn);
        }
      },
      onDone: () {
        debugPrint(
            '[WS] Stream done room=$roomId (closed=${conn.closed})');
        if (!conn.closed) {
          _tearDown(conn, keepTimers: true);
          _scheduleReconnect(roomId, conn);
        }
      },
      cancelOnError: true,
    );

    // Start keep-alive ping
    conn.pingTimer?.cancel();
    conn.pingTimer = Timer.periodic(_pingInterval, (_) {
      if (conn.closed) return;
      try {
        conn.channel?.sink.add(jsonEncode({'action': 'ping'}));
        debugPrint('[WS] ↑ ping → room=$roomId');
      } catch (e) {
        debugPrint('[WS] ping error room=$roomId: $e');
      }
    });
  }

  void _onMessage(String roomId, dynamic raw) {
    debugPrint('[WS] ↓ room=$roomId raw=$raw');
    try {
      final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map<String, dynamic>) {
        _ctrl.add(decoded);
      } else {
        debugPrint('[WS] Unexpected message type: ${decoded.runtimeType}');
      }
    } catch (e) {
      debugPrint('[WS] Parse error room=$roomId: $e  raw=$raw');
    }
  }

  void _scheduleReconnect(String roomId, _RoomConn conn) {
    if (conn.closed) return;
    conn.reconnectTimer?.cancel();
    debugPrint(
        '[WS] Scheduling reconnect for room=$roomId in ${_reconnectDelay.inSeconds}s');
    conn.reconnectTimer = Timer(_reconnectDelay, () {
      if (!conn.closed && _rooms.containsKey(roomId)) {
        debugPrint('[WS] Reconnecting room=$roomId…');
        _doConnect(roomId, conn);
      }
    });
  }

  /// Cancels all timers and closes the socket.
  /// Pass [keepTimers]=true when tearing down before a reconnect.
  void _tearDown(_RoomConn conn, {bool keepTimers = false}) {
    conn.sub?.cancel();
    conn.sub = null;

    conn.pingTimer?.cancel();
    conn.pingTimer = null;

    if (!keepTimers) {
      conn.reconnectTimer?.cancel();
      conn.reconnectTimer = null;
    }

    try {
      conn.channel?.sink.close();
    } catch (_) {}
    conn.channel = null;
  }

  String _normalize(String roomId) => roomId.toLowerCase().trim();
}
