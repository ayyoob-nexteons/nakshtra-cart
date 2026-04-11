// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:nakshatra/controller/cart_controller.dart';

// class QrScannerScreen extends StatefulWidget {
//   const QrScannerScreen({
//     super.key,
//     required this.cartController,
//   });

//   final CartController cartController;

//   @override
//   State<QrScannerScreen> createState() => _QrScannerScreenState();
// }

// class _QrScannerScreenState extends State<QrScannerScreen> {
//   final MobileScannerController _scannerController = MobileScannerController();
//   final Set<String> _inflightSkus = <String>{};
//   DateTime? _lastScanAt;

//   int _foundCount = 0;
//   int _notFoundCount = 0;
//   int _duplicateCount = 0;
//   String _lastMessage = 'Scan a QR code to verify SKU';
//   bool _isProcessing = false;

//   @override
//   void dispose() {
//     _scannerController.dispose();
//     super.dispose();
//   }

//   String? _extractSku(String raw) {
//     final trimmed = raw.trim();
//     if (trimmed.isEmpty) return null;
//     final parts = trimmed.split(RegExp(r'[\s,;|/\?=&]+'));
//     for (final p in parts.reversed) {
//       final cleaned = p.trim();
//       if (cleaned.length >= 3) return cleaned;
//     }
//     return trimmed;
//   }

//   bool _isCooldownActive() {
//     final last = _lastScanAt;
//     if (last == null) return false;
//     final diff = DateTime.now().difference(last);
//     return diff < const Duration(milliseconds: 1200);
//   }

//   Future<void> _onDetect(BarcodeCapture capture) async {
//     final raw =
//         capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
//     if (raw == null || raw.trim().isEmpty) return;
//     if (_isCooldownActive()) return;

//     final sku = _extractSku(raw);
//     if (sku == null || sku.isEmpty) return;
//     final normalized = sku.toLowerCase();
//     if (_inflightSkus.contains(normalized)) return;

//     _lastScanAt = DateTime.now();

//     if (widget.cartController.containsSku(sku)) {
//       setState(() {
//         _duplicateCount += 1;
//         _lastMessage = 'Item already in cart.';
//       });
//       _warnFeedback('Item already in cart.');
//       return;
//     }

//     _inflightSkus.add(normalized);
//     setState(() => _isProcessing = true);
//     try {
//       final found = await widget.cartController.verifySkuFromApi(sku);
//       if (!mounted) return;
//       if (found == null) {
//         setState(() {
//           _notFoundCount += 1;
//           _lastMessage = 'Product not available.';
//         });
//         _warnFeedback('Product not available.');
//         return;
//       }

//       widget.cartController.addScannedProduct(found);
//       setState(() {
//         _foundCount += 1;
//         _lastMessage = 'Product added: ${found.variantDetails?.sku ?? sku}';
//       });
//       _successFeedback('Product added successfully.');
//     } finally {
//       _inflightSkus.remove(normalized);
//       if (mounted) {
//         setState(() => _isProcessing = false);
//       }
//     }
//   }

//   void _warnFeedback(String message) {
//     SystemSound.play(SystemSoundType.alert);
//     HapticFeedback.vibrate();
//     _showSnack(message, isError: true);
//   }

//   void _successFeedback(String message) {
//     SystemSound.play(SystemSoundType.click);
//     _showSnack(message, isError: false);
//   }

//   void _showSnack(String message, {required bool isError}) {
//     final scheme = Theme.of(context).colorScheme;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         behavior: SnackBarBehavior.floating,
//         backgroundColor:
//             isError ? scheme.errorContainer : scheme.primaryContainer,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final scheme = Theme.of(context).colorScheme;
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('QR Scanner'),
//         actions: [
//           IconButton(
//             tooltip: 'Toggle Torch',
//             onPressed: () => _scannerController.toggleTorch(),
//             icon: const Icon(Icons.flashlight_on_outlined),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           if (_isProcessing || widget.cartController.isVerifyingSku)
//             const LinearProgressIndicator(minHeight: 2),
//           Expanded(
//             child: Stack(
//               fit: StackFit.expand,
//               children: [
//                 MobileScanner(
//                   controller: _scannerController,
//                   onDetect: _onDetect,
//                 ),
//                 Align(
//                   alignment: Alignment.topCenter,
//                   child: Container(
//                     margin: const EdgeInsets.all(12),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 10),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withValues(alpha: 0.55),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       _lastMessage,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: scheme.surfaceContainerHighest,
//               border: Border(top: BorderSide(color: scheme.outlineVariant)),
//             ),
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               alignment: WrapAlignment.center,
//               children: [
//                 _CountChip(
//                     label: 'Found', value: _foundCount, color: Colors.teal),
//                 _CountChip(
//                     label: 'Not Found',
//                     value: _notFoundCount,
//                     color: Colors.orange),
//                 _CountChip(
//                     label: 'Duplicate',
//                     value: _duplicateCount,
//                     color: Colors.red),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _CountChip extends StatelessWidget {
//   const _CountChip({
//     required this.label,
//     required this.value,
//     required this.color,
//   });

//   final String label;
//   final int value;
//   final Color color;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.15),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         '$label: $value',
//         style: TextStyle(
//           fontWeight: FontWeight.w700,
//           color: color,
//         ),
//       ),
//     );
//   }
// }
