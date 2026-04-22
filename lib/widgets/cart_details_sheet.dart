import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nakshatra/model/cart/cart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────
void showCartDetailSheet(
  BuildContext context, {
  required Cart cart,
  required String? currentUserId,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // useSafeArea keeps the sheet off the home indicator
    useSafeArea: true,
    builder: (_) => _CartDetailSheet(cart: cart, currentUserId: currentUserId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero tag — icon only; text heroes are slow and not worth it
// ─────────────────────────────────────────────────────────────────────────────
String _heroIconTag(String? id) => 'cart_icon_${id ?? 'unknown'}';

// ─────────────────────────────────────────────────────────────────────────────
// CartTileWithHero  —  drop-in replacement for the old GestureDetector+_CartTile
//
// Usage in cart_list_screen.dart itemBuilder:
//   CartTileWithHero(cart: items[index], currentUserId: _currentUserId)
// ─────────────────────────────────────────────────────────────────────────────
class CartTileWithHero extends StatelessWidget {
  const CartTileWithHero({
    super.key,
    required this.cart,
    required this.currentUserId,
  });

  final Cart cart;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const teal = Color(0xFF0F766E);
    const tealLight = Color(0xFFE1F5EE);

    final v = cart.variantDetails;
    final title = (v?.displayName?.trim().isNotEmpty ?? false)
        ? v!.displayName!
        : (v?.name ?? 'Product');
    final subtitle = (v?.shortDescription ?? '').trim();
    final stock = v?.qty;
    final sku = (v?.sku ?? '').trim();

    final addedByMe = (cart.customerId ?? '').trim().isNotEmpty &&
        (currentUserId ?? '').trim().isNotEmpty &&
        cart.customerId!.trim() == currentUserId!.trim();

    return GestureDetector(
      onTap: () => showCartDetailSheet(
        context,
        cart: cart,
        currentUserId: currentUserId,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: addedByMe ? teal : scheme.outlineVariant,
            width: addedByMe ? 1.5 : 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── "Added by me" banner ──────────────────────────────
            if (addedByMe)
              Container(
                color: teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: const [
                    Icon(Icons.person_rounded, size: 14, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      'Added by me',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero: icon only (lightweight) ─────────────
                  Hero(
                    tag: _heroIconTag(cart.id),
                    // Keep the hero alive when the user swipes the sheet
                    transitionOnUserGestures: true,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: addedByMe ? teal : tealLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 22,
                          color: addedByMe ? Colors.white : teal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (sku.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SkuChip(text: 'SKU: $sku'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stock footer ──────────────────────────────────────
            if (stock != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  color: addedByMe
                      ? teal.withValues(alpha: 0.04)
                      : scheme.surfaceContainerLowest,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.layers_outlined,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text('Stock',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 5),
                    Text('$stock units',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3DE),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFb8daa0)),
                      ),
                      child: const Text(
                        'In stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F6010),
                        ),
                      ),
                    ),
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
// Detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CartDetailSheet extends StatelessWidget {
  final Cart cart;
  final String? currentUserId;

  const _CartDetailSheet({required this.cart, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);

    final v = cart.variantDetails;
    final title = (v?.displayName?.trim().isNotEmpty ?? false)
        ? v!.displayName!
        : (v?.name ?? 'Product');
    final subtitle = (v?.shortDescription ?? '').trim();
    final sku = (v?.sku ?? '').trim();
    final stock = v?.qty;
    final qty = cart.qty;
    final productId = (v?.productId ?? '').trim();

    final addedByMe = (cart.customerId ?? '').trim().isNotEmpty &&
        (currentUserId ?? '').trim().isNotEmpty &&
        cart.customerId!.trim() == currentUserId!.trim();

    // Determine which row is first (for border radius)
    final firstField = sku.isNotEmpty
        ? 'sku'
        : qty != null
            ? 'qty'
            : stock != null
                ? 'stock'
                : 'productId';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main scrollable content
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14), // Space for the close button

                // ── Hero icon (only hero — no text hero to avoid jank) ────
                Center(
                  child: Hero(
                    tag: _heroIconTag(cart.id),
                    transitionOnUserGestures: true,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: addedByMe
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF0F766E),
                                    Color(0xFF14B8A6)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: addedByMe ? null : const Color(0xFFE1F5EE),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: addedByMe
                              ? [
                                  BoxShadow(
                                    color: teal.withOpacity(0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 30,
                          color: addedByMe ? Colors.white : teal,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Title + subtitle (plain widgets, no Hero on text) ─────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1117),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (addedByMe) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: teal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_rounded,
                                  size: 13, color: Color(0xFF0F766E)),
                              SizedBox(width: 5),
                              Text(
                                'Added by me',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Detail card ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SKU — tappable copy
                        if (sku.isNotEmpty)
                          _DetailRow(
                            icon: Icons.qr_code_rounded,
                            label: 'SKU',
                            value: sku,
                            isFirst: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: sku));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      const Text('SKU copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            trailing: const Icon(Icons.copy_rounded,
                                size: 14, color: Color(0xFF0F766E)),
                          ),

                        // Cart qty
                        if (qty != null)
                          _DetailRow(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Cart Qty',
                            value: '$qty units',
                            isFirst: firstField == 'qty',
                          ),

                        // Stock
                        if (stock != null)
                          _DetailRow(
                            icon: Icons.layers_outlined,
                            label: 'In Stock',
                            value: '$stock units',
                            isFirst: firstField == 'stock',
                            valueColor: stock > 0
                                ? const Color(0xFF2F6010)
                                : const Color(0xFFEF4444),
                          ),

                        // Product ID — multi-line selectable, tappable copy
                        if (productId.isNotEmpty)
                          _DetailRowMultiline(
                            icon: Icons.tag_rounded,
                            label: 'Product ID',
                            value: productId,
                            isFirst: firstField == 'productId',
                            isLast: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: productId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Product ID copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            trailing: const Icon(Icons.copy_rounded,
                                size: 14, color: Color(0xFF0F766E)),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // Top-right circular close button
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single-line detail row
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _RowIcon(icon: icon),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF0D1117),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );

    return _RowShell(
      isFirst: isFirst,
      isLast: isLast,
      onTap: onTap,
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-line detail row — for long values like Product ID
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRowMultiline extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _DetailRowMultiline({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              _RowIcon(icon: icon),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Value — full width, wraps, monospace
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1117),
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    return _RowShell(
      isFirst: isFirst,
      isLast: isLast,
      onTap: onTap,
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared shell: divider + optional InkWell with correct border radius
// ─────────────────────────────────────────────────────────────────────────────
class _RowShell extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget child;

  const _RowShell({
    required this.isFirst,
    required this.isLast,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isFirst)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE2E8F0),
            indent: 14,
            endIndent: 14,
          ),
        onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.vertical(
                  top: isFirst ? const Radius.circular(15) : Radius.zero,
                  bottom: isLast ? const Radius.circular(15) : Radius.zero,
                ),
                child: child,
              )
            : child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon box reused in rows
// ─────────────────────────────────────────────────────────────────────────────
class _RowIcon extends StatelessWidget {
  final IconData icon;
  const _RowIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Icon(icon, size: 15, color: const Color(0xFF0F766E)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKU chip
// ─────────────────────────────────────────────────────────────────────────────
class _SkuChip extends StatelessWidget {
  const _SkuChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
