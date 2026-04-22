import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nakshatra/config/db.dart';
import 'package:nakshatra/controller/cart_controller.dart';
import 'package:nakshatra/model/product_list/product_list.dart';
import 'package:nakshatra/model/cart/cart.dart';
import 'package:nakshatra/screens/cart_list_screen.dart';
import 'package:nakshatra/service/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status enum
// ─────────────────────────────────────────────────────────────────────────────
enum _ScanStatus {
  added,
  alreadyInCart,
  notAvailable,
  failed,
}

// ─────────────────────────────────────────────────────────────────────────────
// Scanned item model
// ─────────────────────────────────────────────────────────────────────────────
class _ScannedItem {
  final String rawSku;
  final ProductList? product;
  final _ScanStatus status;
  final bool addedByMe;
  final String? cartId;

  const _ScannedItem({
    required this.rawSku,
    required this.status,
    this.product,
    this.addedByMe = false,
    this.cartId,
  });

  String get displayName {
    final v = product?.variantDetail;
    if (v?.displayName?.trim().isNotEmpty ?? false) return v!.displayName!;
    if (v?.name?.trim().isNotEmpty ?? false) return v!.name!;
    return rawSku;
  }

  String get displaySku => product?.variantDetail?.sku?.trim() ?? rawSku;
  int? get stock => product?.variantDetail?.qty;
}

enum _ScanMode { barcode, nfc }

// ─────────────────────────────────────────────────────────────────────────────
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, this.cartController});
  final CartController? cartController;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with WidgetsBindingObserver {

  // ── Shared WebSocket room — MUST match CartListScreen ─────────────────────
  static const String _cartRoom = 'cartevents';

  // ── Camera ────────────────────────────────────────────────────────────────
  MobileScannerController? _scannerCtrl;
  bool _cameraRunning = false;
  bool _cameraMounted = false;

  // ── NFC ───────────────────────────────────────────────────────────────────
  bool _nfcAvailable = false;
  bool _nfcListening = false;
  bool _nfcReady     = false;
  String _nfcStatus  = 'Initialising NFC…';

  // ── Audio ─────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Shared ────────────────────────────────────────────────────────────────
  final List<_ScannedItem> _scannedItems = [];
  final Set<String> _inflightSkus  = {};
  final Set<String> _processedSkus = {};

  late final CartController _controller;
  late final CartController _myItemsController;
  late final bool _ownsController;

  String? _currentUserId;
  _ScanMode _mode       = _ScanMode.nfc;
  DateTime? _lastScanAt;
  bool _isApiLoading    = false;
  String _barcodeStatus = 'Point camera at a barcode or QR code';
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  int get _addedCount =>
      _scannedItems.where((e) => e.status == _ScanStatus.added).length;
  int get _inCartCount =>
      _scannedItems.where((e) => e.status == _ScanStatus.alreadyInCart).length;
  int get _unavailableCount => _scannedItems
      .where((e) =>
          e.status == _ScanStatus.notAvailable ||
          e.status == _ScanStatus.failed)
      .length;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ownsController = widget.cartController == null;
    _controller = widget.cartController ?? CartController(pageSize: 10);
    if (_ownsController) _controller.init();

    _myItemsController = CartController(pageSize: 3, screenType: const [100]);
    _myItemsController.init();
    _myItemsController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNfc());

    // ── Join the SHARED cart room ─────────────────────────────────────────
    WebSocketService.instance.connect(_cartRoom);
    _wsSub = WebSocketService.instance.messageStream.listen((msg) {
      debugPrint('[AddProductScreen] WS message: $msg');

      final Map<String, dynamic> data =
          (msg['data'] as Map<String, dynamic>?) ?? msg;

      final String? event   = data['event']  as String?;
      final String? cartId  = data['cartId'] as String?;
      final dynamic cartRaw = data['cart'];

      debugPrint('[AddProductScreen] event=$event cartId=$cartId hasCart=${cartRaw != null}');

      if (event == 'added' && cartRaw is Map<String, dynamic>) {
        debugPrint('[AddProductScreen] ✓ insertItemLocally');
        if (mounted) {
          try {
            _controller.insertItemLocally(Cart.fromJson(cartRaw));
          } catch (e) {
            debugPrint('[AddProductScreen] ✗ Cart.fromJson error: $e');
          }
        }
      } else if (event == 'removed' && cartId != null) {
        debugPrint('[AddProductScreen] ✓ removeItemLocally cartId=$cartId');
        if (mounted) {
          String? skuToUnlock;
          final allItems = [..._controller.items, ..._myItemsController.items];
          for (final c in allItems) {
            if (c.id?.trim() == cartId.trim()) {
              skuToUnlock = c.variantDetails?.sku?.toLowerCase();
              if (skuToUnlock != null) break;
            }
          }

          _controller.removeItemLocally(cartId);
          _myItemsController.removeItemLocally(cartId);

          if (skuToUnlock != null) {
            debugPrint('[AddProductScreen] → Unlocking SKU: $skuToUnlock');
            _processedSkus.remove(skuToUnlock);
            _scannedItems.removeWhere((item) =>
                item.rawSku.toLowerCase() == skuToUnlock ||
                item.cartId?.trim() == cartId.trim());
          } else {
            _scannedItems.removeWhere((item) => item.cartId?.trim() == cartId.trim());
          }

          setState(() {});
        }
      } else if (event != null) {
        debugPrint('[AddProductScreen] ✗ WS message ignored (unrecognised event=$event)');
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    final user = await LocalDb.getUser();
    if (!mounted) return;
    setState(() => _currentUserId = user?.id?.trim());
  }

  // ── Audio helpers ─────────────────────────────────────────────────────────
  Future<void> _playSuccess() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
    } catch (e) {
      debugPrint('[AddProductScreen] audio success error: $e');
    }
  }

  Future<void> _playError() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/error.mp3'));
    } catch (e) {
      debugPrint('[AddProductScreen] audio error error: $e');
    }
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_mode == _ScanMode.barcode) _startCamera();
        if (_mode == _ScanMode.nfc && !mounted) _startNfc();
        break;
      case AppLifecycleState.inactive:
        _stopCamera();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopCamera();
        _stopNfc();
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startCamera() async {
    if (!mounted) return;
    if (_cameraRunning) return;

    if (_scannerCtrl != null) {
      final old = _scannerCtrl;
      setState(() {
        _scannerCtrl   = null;
        _cameraMounted = false;
      });
      await Future.delayed(const Duration(milliseconds: 120));
      try { old?.dispose(); } catch (_) {}
    }

    if (!mounted) return;
    final ctrl = MobileScannerController(autoStart: true);
    setState(() {
      _scannerCtrl   = ctrl;
      _cameraMounted = true;
      _cameraRunning = true;
    });
  }

  Future<void> _stopCamera() async {
    if (!_cameraRunning) return;
    _cameraRunning = false;
    final ctrl = _scannerCtrl;
    setState(() {
      _scannerCtrl   = null;
      _cameraMounted = false;
    });
    await Future.delayed(const Duration(milliseconds: 80));
    try { ctrl?.stop(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 80));
    try { ctrl?.dispose(); } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NFC
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startNfc() async {
    if (_nfcListening) return;
    final available = await NfcManager.instance.isAvailable();
    if (!mounted) return;

    if (!available) {
      setState(() {
        _nfcAvailable = false;
        _nfcReady     = false;
        _nfcStatus    = 'NFC is not available on this device.';
      });
      return;
    }

    setState(() {
      _nfcAvailable = true;
      _nfcListening = true;
      _nfcReady     = true;
      _nfcStatus    = 'Hold NFC tag near the top of your device';
    });

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      invalidateAfterFirstRead: false,
      onDiscovered: _onNfcDiscovered,
      onError: (error) async {
        if (!mounted) return;
        // Session ended (e.g. user dismissed native dialog) — allow tap-to-restart
        setState(() {
          _nfcListening = false;
          _nfcReady     = false;
          _nfcStatus    = 'Tap here to restart NFC scanning';
        });
      },
    );
  }

  Future<void> _stopNfc() async {
    if (!_nfcListening) return;
    _nfcListening = false;
    _nfcReady     = false;
    try { await NfcManager.instance.stopSession(); } catch (_) {}
    if (mounted) setState(() => _nfcStatus = 'NFC stopped');
  }

  /// Fully stops any existing NFC session and starts a fresh one.
  /// Safe to call even when the session has already been closed by the OS.
  Future<void> _restartNfc() async {
    if (!mounted) return;
    // Silently attempt to stop any lingering session
    if (_nfcListening) {
      _nfcListening = false;
      _nfcReady     = false;
      try { await NfcManager.instance.stopSession(); } catch (_) {}
    }
    setState(() {
      _nfcReady  = false;
      _nfcStatus = 'Starting NFC…';
    });
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) await _startNfc();
  }

  String? _extractSkuFromTag(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef != null) {
      final msg = ndef.cachedMessage;
      if (msg != null) {
        for (final record in msg.records) {
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.type.length == 1 &&
              record.type[0] == 0x54) {
            final payload = record.payload;
            if (payload.isEmpty) continue;
            final statusByte = payload[0];
            final isUtf16 = (statusByte & 0x80) != 0;
            final langLen = statusByte & 0x3F;
            if (1 + langLen >= payload.length) continue;
            final textBytes = payload.sublist(1 + langLen);
            String text = '';
            if (isUtf16) {
              if (textBytes.length >= 2) {
                bool isLE = true;
                int startIndex = 0;
                if (textBytes[0] == 0xFF && textBytes[1] == 0xFE) {
                  isLE = true; startIndex = 2;
                } else if (textBytes[0] == 0xFE && textBytes[1] == 0xFF) {
                  isLE = false; startIndex = 2;
                }
                final buffer = StringBuffer();
                for (int i = startIndex; i < textBytes.length - 1; i += 2) {
                  int charCode = isLE
                      ? (textBytes[i] | (textBytes[i + 1] << 8))
                      : ((textBytes[i] << 8) | textBytes[i + 1]);
                  buffer.writeCharCode(charCode);
                }
                text = buffer.toString();
              }
            } else {
              try {
                text = utf8.decode(textBytes, allowMalformed: true);
              } catch (_) {
                text = String.fromCharCodes(textBytes);
              }
            }
            text = text.replaceAll(RegExp(r'[\x00]'), '').trim();
            if (text.isNotEmpty) return text;
          }

          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.type.length == 1 &&
              record.type[0] == 0x55) {
            final payload = record.payload;
            if (payload.length < 2) continue;
            try {
              final body = utf8.decode(payload.sublist(1), allowMalformed: true).trim();
              if (body.isNotEmpty) return body;
            } catch (_) {
              final body = String.fromCharCodes(payload.sublist(1)).trim();
              if (body.isNotEmpty) return body;
            }
          }

          try {
            String raw = utf8.decode(record.payload, allowMalformed: true).trim();
            raw = raw.replaceAll(RegExp(r'[\x00]'), '');
            if (raw.isNotEmpty) return raw;
          } catch (_) {}
        }
      }
    }

    try {
      List<int>? idBytes;
      final data = tag.data;
      for (final key in ['nfca', 'nfcb', 'nfcf', 'nfcv', 'mifare', 'isodep']) {
        if (data.containsKey(key) && data[key]?['identifier'] != null) {
          idBytes = List<int>.from(data[key]['identifier'] as Iterable);
          break;
        }
      }
      if (idBytes != null && idBytes.isNotEmpty) {
        return idBytes
            .map((e) => e.toRadixString(16).toUpperCase().padLeft(2, '0'))
            .join('');
      }
    } catch (_) {}

    return null;
  }

  Future<void> _onNfcDiscovered(NfcTag tag) async {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);

    final sku = _extractSkuFromTag(tag);
    if (sku == null || sku.isEmpty) {
      if (mounted) {
        setState(() {
          _nfcReady  = true;
          _nfcStatus = 'Could not read SKU from tag. Try again.';
        });
      }
      return;
    }

    await _processSku(sku, isNfc: true);

    if (mounted) {
      setState(() {
        _nfcReady  = true;
        _nfcStatus = 'Hold NFC tag near the top of your device';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSub?.cancel();
    WebSocketService.instance.disconnect(_cartRoom);
    if (_nfcListening) {
      _nfcListening = false;
      NfcManager.instance.stopSession().catchError((_) {});
    }
    final ctrl = _scannerCtrl;
    _scannerCtrl   = null;
    _cameraMounted = false;
    _cameraRunning = false;
    Future.microtask(() {
      try { ctrl?.stop(); } catch (_) {}
      Future.delayed(const Duration(milliseconds: 60), () {
        try { ctrl?.dispose(); } catch (_) {}
      });
    });
    _audioPlayer.dispose();
    if (_ownsController) _controller.dispose();
    _myItemsController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Barcode detect callback
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_mode != _ScanMode.barcode || _isApiLoading) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    await _processSku(raw.trim(), isNfc: false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared SKU pipeline
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processSku(String sku, {required bool isNfc}) async {
    if (sku.isEmpty || _isApiLoading) return;

    final normalized = sku.toLowerCase();
    if (_inflightSkus.contains(normalized)) return;

    final last = _lastScanAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 2500)) return;
    _lastScanAt = DateTime.now();

    if (_processedSkus.contains(normalized)) return;

    _inflightSkus.add(normalized);
    _setStatus('Checking cart for: $sku…', isNfc: isNfc);
    setState(() => _isApiLoading = true);

    try {
      // 1. Already in cart?
      final existsInCart = await _controller.isSkuAlreadyInCart(sku);
      if (!mounted) return;
      if (existsInCart) {
        _processedSkus.add(normalized);
        _insert(_ScannedItem(rawSku: sku, status: _ScanStatus.alreadyInCart));
        HapticFeedback.selectionClick();
        _playError(); // ← error sound: already in cart
        _setStatus('Already in cart: $sku', isNfc: isNfc);
        return;
      }

      // 2. Fetch product
      _setStatus('Finding product: $sku…', isNfc: isNfc);
      final product = await _controller.fetchProductBySku(sku);
      if (!mounted) return;
      if (product == null) {
        _processedSkus.add(normalized);
        _insert(_ScannedItem(rawSku: sku, status: _ScanStatus.notAvailable));
        HapticFeedback.vibrate();
        _playError(); // ← error sound: not available
        _setStatus('Not available: $sku', isNfc: isNfc);
        return;
      }

      // 3. Auto-add to cart
      _setStatus('Adding to cart: $sku…', isNfc: isNfc);
      final ok = await _controller.addProductsToCart([product]);
      if (!mounted) return;

      if (ok) {
        final variantId = (product.variantDetail?.id ?? '').trim();
        Cart? newCart;
        if (variantId.isNotEmpty) {
          for (final c in _controller.items) {
            if ((c.variantId ?? '').trim() == variantId) {
              newCart = c;
              break;
            }
          }
        }

        if (newCart != null) {
          _processedSkus.add(normalized);
          final isMe = (_currentUserId?.trim().isNotEmpty ?? false);
          _insert(_ScannedItem(
            rawSku: sku,
            product: product,
            status: _ScanStatus.added,
            addedByMe: isMe,
            cartId: newCart.id,
          ));
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.lightImpact();
          _playSuccess(); // ← success sound: added to cart
          _setStatus('Added: ${product.variantDetail?.sku ?? sku}', isNfc: isNfc);
          _myItemsController.refresh();

          debugPrint('[AddProductScreen] Broadcasting "added" on room=$_cartRoom cart=${newCart.id}');
          WebSocketService.instance.broadcast(_cartRoom, {
            'event': 'added',
            'cart': newCart.toJson(),
          });
        } else {
          debugPrint('[AddProductScreen] ✗ No Cart found to broadcast (variantId=$variantId)');
        }
      } else {
        _insert(_ScannedItem(rawSku: sku, product: product, status: _ScanStatus.failed));
        HapticFeedback.vibrate();
        _playError(); // ← error sound: add failed
        _setStatus('Failed to add: $sku', isNfc: isNfc);
      }
    } catch (_) {
      if (!mounted) return;
      _processedSkus.add(normalized);
      _insert(_ScannedItem(rawSku: sku, status: _ScanStatus.failed));
      HapticFeedback.vibrate();
      _playError(); // ← error sound: exception
      _setStatus('Error scanning: $sku', isNfc: isNfc);
    } finally {
      _inflightSkus.remove(normalized);
      if (mounted) setState(() => _isApiLoading = false);
    }
  }

  void _setStatus(String msg, {required bool isNfc}) {
    if (!mounted) return;
    setState(() {
      if (isNfc) {
        _nfcStatus = msg;
      } else {
        _barcodeStatus = msg;
      }
    });
  }

  void _insert(_ScannedItem item) {
    if (!mounted) return;
    setState(() => _scannedItems.insert(0, item));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mode switch
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _switchMode(_ScanMode mode) async {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    if (mode == _ScanMode.barcode) {
      await _stopNfc();
      await _startCamera();
    } else {
      await _stopCamera();
      await _startNfc();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    final scheme = Theme.of(context).colorScheme;
    final isLoading = _isApiLoading || _controller.isVerifyingSku;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 4,
        title: const Text(
          'Product Scanner',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          if (isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: teal,
              backgroundColor: teal.withValues(alpha: 0.1),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(11),
              ),
              child: CupertinoSlidingSegmentedControl<_ScanMode>(
                groupValue: _mode,
                backgroundColor: Colors.transparent,
                thumbColor: scheme.surface,
                children: const {
                  _ScanMode.nfc: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('NFC',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  _ScanMode.barcode: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Barcode',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                },
                onValueChanged: (v) {
                  if (v != null) _switchMode(v);
                },
              ),
            ),
          ),
          Expanded(child: _buildScrollBody(scheme, teal)),
        ],
      ),
    );
  }

  Widget _buildScrollBody(ColorScheme scheme, Color teal) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _mode == _ScanMode.barcode
              ? _buildCameraViewport(teal)
              : _buildNfcPanel(scheme, teal),
        ),
        if (_scannedItems.isNotEmpty)
          SliverToBoxAdapter(child: _buildStatusSummary(scheme, teal)),
        if (_myItemsController.items.isNotEmpty || _myItemsController.isFirstLoad) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(scheme, teal,
                icon: Icons.person_rounded,
                label: 'Added by Me',
                count: _myItemsController.totalCount),
          ),
          SliverToBoxAdapter(child: _buildMyItemsList(scheme, teal)),
        ],
        if (_scannedItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(scheme, teal,
                icon: Icons.history_rounded,
                label: 'Scan History',
                count: _scannedItems.length),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            sliver: SliverList.separated(
              itemCount: _scannedItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _buildScannedTile(scheme, teal, _scannedItems[i]),
            ),
          ),
        ],
        if (_scannedItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(scheme, teal),
          ),
      ],
    );
  }

  Widget _buildCameraViewport(Color teal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_cameraMounted && _scannerCtrl != null)
                MobileScanner(
                  controller: _scannerCtrl!,
                  onDetect: _onDetect,
                  errorBuilder: (_, error, __) =>
                      _CameraErrorPlaceholder(error: error),
                )
              else
                Container(
                  color: const Color(0xFF0D1117),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0F766E)),
                    ),
                  ),
                ),
              if (_cameraMounted)
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: CustomPaint(painter: _FramePainter()),
                  ),
                ),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: _StatusBadge(text: _barcodeStatus),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── NFC panel — tapping the whole container restarts NFC if session dropped
  Widget _buildNfcPanel(ColorScheme scheme, Color teal) {
    // Session is dropped when _nfcAvailable=true but _nfcListening=false.
    // We allow restart taps in that state (or any time the icon is tapped and
    // NFC is available), so the GestureDetector is always active when available.
    final canRestart = _nfcAvailable && !_nfcListening && !_isApiLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GestureDetector(
        onTap: canRestart ? _restartNfc : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 210,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF0D1117)),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The icon itself is also individually tappable for clarity
                      GestureDetector(
                        onTap: canRestart ? _restartNfc : null,
                        child: _NfcPulseIcon(
                          ready: _nfcReady && !_isApiLoading,
                          available: _nfcAvailable,
                          canRestart: canRestart,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        !_nfcAvailable
                            ? 'NFC Not Available'
                            : _isApiLoading
                                ? 'Processing…'
                                : _nfcReady
                                    ? 'Ready to Scan'
                                    : canRestart
                                        ? 'Tap to Restart NFC'
                                        : 'NFC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_nfcAvailable && _nfcReady && !_isApiLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Tap your NFC tag',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      if (canRestart)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Tap anywhere to restart',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: _StatusBadge(text: _nfcStatus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSummary(ColorScheme scheme, Color teal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.check_circle_rounded,
            label: 'Added',
            count: _addedCount,
            color: const Color(0xFF16A34A),
            bg: const Color(0xFFDCFCE7),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.shopping_cart_rounded,
            label: 'In Cart',
            count: _inCartCount,
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFDBEAFE),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.warning_rounded,
            label: 'Unavailable',
            count: _unavailableCount,
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFEF3C7),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ColorScheme scheme,
    Color teal, {
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: teal),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: teal)),
          ),
        ],
      ),
    );
  }

  Widget _buildMyItemsList(ColorScheme scheme, Color teal) {
    if (_myItemsController.isFirstLoad) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: teal),
          ),
        ),
      );
    }

    final items = _myItemsController.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildCartTile(scheme, teal, item),
                    ))
                .toList(),
          ),
        ),
        if (_myItemsController.totalCount > items.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CartListScreen(screenType: [100]),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: teal.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 16, color: teal),
                    const SizedBox(width: 6),
                    Text(
                      'View All ${_myItemsController.totalCount} Products Added by Me',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: teal),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCartTile(ColorScheme scheme, Color teal, Cart cart) {
    final v = cart.variantDetails;
    final displayName = (v?.displayName?.trim().isNotEmpty ?? false)
        ? v!.displayName!
        : (v?.name ?? 'Product');
    final displaySku = (v?.sku ?? '').trim();
    final stock = v?.qty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: teal, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: teal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: const [
                Icon(Icons.person_rounded, size: 13, color: Colors.white70),
                SizedBox(width: 6),
                Text('Added by Me',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(displaySku,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusButton(status: _ScanStatus.added),
              ],
            ),
          ),
          if (stock != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4))),
                color: teal.withValues(alpha: 0.04),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text('$stock in stock',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannedTile(ColorScheme scheme, Color teal, _ScannedItem item) {
    const tealLight = Color(0xFFE1F5EE);
    final isMe = item.addedByMe;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? teal : scheme.outlineVariant.withValues(alpha: 0.6),
          width: isMe ? 1.5 : 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMe)
            Container(
              color: teal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.person_rounded, size: 13, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('Added by Me',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isMe ? teal : tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      size: 20, color: isMe ? Colors.white : teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(item.displaySku,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusButton(status: item.status),
              ],
            ),
          ),
          if (item.stock != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4))),
                color: isMe
                    ? teal.withValues(alpha: 0.04)
                    : scheme.surfaceContainerLowest,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text('${item.stock} in stock',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme, Color teal) {
    const tealLight = Color(0xFFE1F5EE);
    final isNfc = _mode == _ScanMode.nfc;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tealLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isNfc ? Icons.nfc_rounded : Icons.qr_code_scanner_rounded,
              size: 30,
              color: teal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isNfc ? 'No NFC tags scanned yet' : 'No products scanned yet',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            isNfc
                ? 'Tap an NFC tag to add products automatically'
                : 'Scanned items will appear here automatically',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated NFC pulse icon
// ─────────────────────────────────────────────────────────────────────────────
class _NfcPulseIcon extends StatefulWidget {
  const _NfcPulseIcon({
    required this.ready,
    required this.available,
    this.canRestart = false,
  });
  final bool ready;
  final bool available;
  /// When true the session has dropped and a tap should restart it.
  final bool canRestart;

  @override
  State<_NfcPulseIcon> createState() => _NfcPulseIconState();
}

class _NfcPulseIconState extends State<_NfcPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.90, end: 1.10)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);

    if (!widget.available) {
      return Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.nfc_rounded, size: 36, color: Colors.white24),
      );
    }

    // Session dropped — show a static "tap to restart" state
    if (widget.canRestart) {
      return Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.refresh_rounded, size: 36, color: Colors.white70),
      );
    }

    if (!widget.ready) {
      return Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.nfc_rounded, size: 36, color: Colors.white54),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: teal, width: 2),
            ),
            child: const Icon(Icons.nfc_rounded, size: 38, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status button
// ─────────────────────────────────────────────────────────────────────────────
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status});
  final _ScanStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon, filled) = switch (status) {
      _ScanStatus.added => ('Added', const Color(0xFF16A34A), Icons.check_rounded, true),
      _ScanStatus.alreadyInCart => ('Already in Cart', const Color(0xFF2563EB), Icons.shopping_cart_rounded, false),
      _ScanStatus.notAvailable => ('Not Available', const Color(0xFFD97706), Icons.warning_amber_rounded, false),
      _ScanStatus.failed => ('Failed', const Color(0xFFDC2626), Icons.error_outline_rounded, false),
    };

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
    const ts  = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
    const pad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    const ms  = Size.zero;
    const tt  = MaterialTapTargetSize.shrinkWrap;

    if (filled) {
      return FilledButton.icon(
        onPressed: null,
        icon: Icon(icon, size: 12),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color,
          disabledForegroundColor: Colors.white,
          padding: pad, minimumSize: ms, tapTargetSize: tt, textStyle: ts, shape: shape,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 12),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        backgroundColor: color.withValues(alpha: 0.06),
        padding: pad, minimumSize: ms, tapTargetSize: tt, textStyle: ts, shape: shape,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary chip
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: color.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera error placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _CameraErrorPlaceholder extends StatelessWidget {
  final MobileScannerException error;
  const _CameraErrorPlaceholder({required this.error});

  String get _message => switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'Camera permission denied.\nPlease enable it in Settings.',
        MobileScannerErrorCode.unsupported =>
          'Camera not supported\non this device.',
        _ => 'Camera unavailable.\nPlease try again.',
      };

  @override
  Widget build(BuildContext context) {
    if (error.errorCode != MobileScannerErrorCode.permissionDenied &&
        error.errorCode != MobileScannerErrorCode.unsupported) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0D1117),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white54, size: 28),
            ),
            const SizedBox(height: 12),
            Text(_message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan frame corner painter
// ─────────────────────────────────────────────────────────────────────────────
class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F766E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    const r = 4.0;

    canvas.drawLine(const Offset(r, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, len), paint);
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height - r), paint);
    canvas.drawLine(
        const Offset(r, 0).translate(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
        Offset(size.width - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawLine(
        Offset(size.width, size.height - len), Offset(size.width, size.height - r), paint);

    canvas.drawLine(
      Offset(8, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      Paint()
        ..color = const Color(0xFF0F766E).withValues(alpha: 0.7)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}