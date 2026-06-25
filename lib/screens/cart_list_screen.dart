import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nakshatra/config/db.dart';
import 'package:nakshatra/controller/cart_controller.dart';
import 'package:nakshatra/model/cart/cart.dart';
import 'package:nakshatra/model/cart_status_change/cart_status_model.dart';
import 'package:nakshatra/repo/cart_repo.dart';
import 'package:nakshatra/router/app_router.dart';
import 'package:nakshatra/screens/add_product_screen.dart';
import 'package:nakshatra/service/websocket_service.dart';
import 'package:nakshatra/widgets/cart_details_sheet.dart';

class CartListScreen extends StatefulWidget {
  const CartListScreen({super.key, this.screenType = const []});
  final List<dynamic> screenType;

  @override
  State<CartListScreen> createState() => _CartListScreenState();
}

class _CartListScreenState extends State<CartListScreen> {
  late final _controller =
      CartController(pageSize: 10, screenType: widget.screenType);
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String? _currentUserId;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _controller.init();
    _loadCurrentUserId();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    WebSocketService.instance.connect('cartevents');
    ;
    _wsSub = WebSocketService.instance.messageStream.listen((msg) {
      debugPrint('[CartListScreen] WS message received: $msg');

      // Server echoes back the data payload directly:
      //   removed → {"event":"removed", "cartId":"xxx"}
      //   added   → {"event":"added",   "cart":{...}}
      // Also handles the wrapped form: {"data":{...}}
      final Map<String, dynamic> data =
          (msg['data'] as Map<String, dynamic>?) ?? msg;

      final String? event = data['event'] as String?;
      final String? cartId = data['cartId'] as String?;
      final dynamic cartRaw = data['cart'];

      debugPrint(
          '[CartListScreen] WS event=$event cartId=$cartId hasCart=${cartRaw != null}');

      if (event == 'removed' && cartId != null) {
        // Instantly remove from local list — zero API call
        debugPrint('[CartListScreen] ✓ removeItemLocally cartId=$cartId');
        _controller.removeItemLocally(cartId);
      } else if (event == 'added' && cartRaw is Map<String, dynamic>) {
        // Instantly insert into local list — zero API call
        debugPrint('[CartListScreen] ✓ insertItemLocally');
        try {
          _controller.insertItemLocally(Cart.fromJson(cartRaw));
        } catch (e) {
          debugPrint('[CartListScreen] ✗ Cart.fromJson error: $e');
        }
      } else {
        debugPrint(
            '[CartListScreen] ✗ WS message ignored (unrecognised format)');
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    final user = await LocalDb.getUser();
    if (!mounted) return;
    setState(() => _currentUserId = user?.id?.trim());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    WebSocketService.instance.disconnect('cartevents');
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) _controller.loadMore();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _performSearch(force: false),
    );
  }

  Future<void> _performSearch({required bool force}) async {
    final query = _searchCtrl.text.trim();
    if (_controller.isFirstLoad || _controller.isSearching) return;
    await _controller.search(query: query, force: force);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign out?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalDb.logout();
    if (!mounted) return;
    context.go(AppRouter.login);
  }

  Future<void> _openAddProduct() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(cartController: _controller),
      ),
    );
  }

  // ── Remove from cart ───────────────────────────────────────────────────────
  Future<void> _removeFromCart(Cart cart) async {
    final cartId = cart.id?.trim() ?? '';
    if (cartId.isEmpty) return;

    SystemSound.play(SystemSoundType.click);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove item?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to remove this item from your cart?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            if ((cart.variantDetails?.displayName ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cart.variantDetails!.displayName!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1117),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Removing item...'),
          ],
        ),
        duration: Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final res = await CartRepo.cartStatusChange(
        CartStatusModel(
          cartId: cartId,
          status: 2,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      res.fold(
        (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.message ?? 'Failed to remove item.'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              behavior: SnackBarBehavior.floating,
            ),
          );
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.vibrate();
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item removed from cart.'),
              backgroundColor: Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.lightImpact();
          // Remove locally — instant UI, no API call
          _controller.removeItemLocally(cartId);
          debugPrint('[CartListScreen] Removed $cartId locally → broadcasting');
          // Tell every other user on this screen to remove the same item
          WebSocketService.instance.broadcast('cartevents', {
            'event': 'removed',
            'cartId': cartId,
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final items = _controller.items;
        final firstLoad = _controller.isFirstLoad;
        final loadingMore = _controller.isLoadingMore;
        final error = _controller.errorMessage;
        final totalCount = _controller.totalCount;

        return Scaffold(
          backgroundColor: Colors.white,

          // ── FAB: Add Product ─────────────────────────────────────────────
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddProduct,
            backgroundColor: teal,
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Add Product',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // ── AppBar ───────────────────────────────────────────────────────
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEF0), width: 1),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Cart',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: Color(0xFF0D1117),
                            ),
                          ),
                          if (totalCount > 0)
                            Text(
                              '$totalCount items',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F766E),
                                letterSpacing: 0.1,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      _NavBtn(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onTap: firstLoad ? null : _controller.refresh,
                      ),
                      const SizedBox(width: 8),
                      _NavBtn(
                        icon: Icons.logout_rounded,
                        tooltip: 'Sign out',
                        onTap: _logout,
                        danger: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          body: RefreshIndicator(
            color: teal,
            onRefresh: _controller.refresh,
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Search ─────────────────────────────────
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(Icons.search_rounded,
                                  size: 19, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (_) =>
                                      _performSearch(force: true),
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Search product / SKU',
                                    hintStyle: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_controller.isSearching)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: teal),
                                  ),
                                )
                              else if (_searchCtrl.text.trim().isNotEmpty)
                                IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _performSearch(force: true);
                                    FocusScope.of(context).unfocus();
                                  },
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                  color: scheme.onSurfaceVariant,
                                )
                              else
                                IconButton(
                                  onPressed: () => _performSearch(force: true),
                                  icon: const Icon(Icons.arrow_forward_rounded,
                                      size: 18),
                                  color: teal,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _CountPill(
                              showing: items.length,
                              total: totalCount,
                            ),
                            if (error != null && error.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (firstLoad)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty &&
                    error != null &&
                    error.trim().isNotEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.error_outline_rounded,
                      iconColor: const Color(0xFFE24B4A),
                      iconBg: const Color(0xFFFCEBEB),
                      title: 'Something went wrong',
                      subtitle: error,
                      action: FilledButton(
                        onPressed: _controller.refresh,
                        style: FilledButton.styleFrom(backgroundColor: teal),
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      iconColor: teal,
                      iconBg: const Color(0xFFE1F5EE),
                      title: 'No items found',
                      subtitle: 'Try a different search or pull to refresh',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
                    sliver: SliverList.separated(
                      itemCount: items.length + (loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index >= items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          );
                        }
                        return GestureDetector(
                          onTap: () => showCartDetailSheet(
                            context,
                            cart: items[index],
                            currentUserId: _currentUserId,
                          ),
                          child: _CartTile(
                            cart: items[index],
                            currentUserId: _currentUserId,
                            onRemove: () => _removeFromCart(items[index]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav button
// ─────────────────────────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF6B7280);
    final bg = danger ? const Color(0xFFFEF2F2) : const Color(0xFFF3F4F6);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count pill
// ─────────────────────────────────────────────────────────────────────────────
class _CountPill extends StatelessWidget {
  const _CountPill({required this.showing, required this.total});
  final int showing;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view_rounded,
              size: 13, color: Color(0xFF0F766E)),
          const SizedBox(width: 5),
          Text(
            'Showing $showing / ${total == 0 ? '-' : total}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 34, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart tile  — onRemove is only wired on "Added by me" cards
// ─────────────────────────────────────────────────────────────────────────────
class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.cart,
    required this.currentUserId,
    this.onRemove, // ← new, optional
  });
  final Cart cart;
  final String? currentUserId;
  final VoidCallback? onRemove; // ← new

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

    return Container(
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
          // ── "Added by me" banner with Remove button ─────────────────────
          if (addedByMe)
            Container(
              color: teal,
              padding:
                  const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  const Text(
                    'Added by me',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

          // ── Main content ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
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
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFEF4444),
                    tooltip: 'Remove from cart',
                  ),
              ],
            ),
          ),

          // ── Stock footer ────────────────────────────────────────────────
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    'Stock',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$stock units',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chips
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFb8daa0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2F6010),
        ),
      ),
    );
  }
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Scanner toast
// ─────────────────────────────────────────────────────────────────────────────
void showScannerToast(
  BuildContext context, {
  required String message,
  required bool warning,
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor:
          warning ? scheme.errorContainer : scheme.primaryContainer,
      behavior: SnackBarBehavior.floating,
    ),
  );
  if (warning) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  } else {
    SystemSound.play(SystemSoundType.click);
  }
}
