import 'package:flutter/foundation.dart';
import 'package:nakshatra/model/add_to_cart_input/add_to_cart_input.dart';
import 'package:nakshatra/model/add_to_cart_input/item.dart';
import 'package:nakshatra/config/db.dart';
import 'package:nakshatra/model/cart/cart.dart';
import 'package:nakshatra/model/cart_request/cart_request.dart';
import 'package:nakshatra/model/global_list.dart';
import 'package:nakshatra/model/prodcut_input/product_input.dart';
import 'package:nakshatra/model/product_list/product_list.dart';
import 'package:nakshatra/repo/cart_repo.dart';

class CartController extends ChangeNotifier {
  CartController({this.pageSize = 10, this.screenType = const []});

  final int pageSize;
  final List<dynamic> screenType;

  final List<Cart> _items = [];
  int _totalCount = 0;
  bool _isFirstLoad = false;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  bool _isVerifyingSku = false;
  String? _errorMessage;

  String _searchText = '';
  int _requestSerial = 0;

  List<Cart> get items => List.unmodifiable(_items);
  int get totalCount => _totalCount;
  bool get isFirstLoad => _isFirstLoad;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSearching => _isSearching;
  bool get isVerifyingSku => _isVerifyingSku;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _items.length < _totalCount;

  void setSearchText(String value) {
    _searchText = value;
  }

  String get searchText => _searchText;

  Future<String?> _resolveBranchId() async {
    final linkings = await LocalDb.getUserBranchLinkings();
    if (linkings.isEmpty) return null;
    return linkings.first.branchId ?? linkings.first.branchDetails?.id;
  }

  CartRequest _buildRequest({required int skip}) {
    return CartRequest(
      skip: skip,
      limit: pageSize,
      searchingText: '',
      skuSearch: _searchText,
      statusArray: const [1, 0],
      branchIds: _branchId == null ? [] : [_branchId!],
      cartIds: const [],
      customerIds: const [],
      productIds: const [],
      screenType: screenType,
      sortType: 0,
      sortOrder: -1,
      variantIds: const [],
    );
  }

  String? _branchId;
  String? get branchId => _branchId;

  Future<void> init() async {
    _isFirstLoad = true;
    notifyListeners();
    _branchId = await _resolveBranchId();
    _isFirstLoad = false;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isFirstLoad) return;
    final localSerial = ++_requestSerial;
    _errorMessage = null;
    _isFirstLoad = true;
    _isSearching = _searchText.trim().isNotEmpty;
    notifyListeners();
    try {
      _items.clear();
      _totalCount = 0;

      final res = await CartRepo.fetchCart(_buildRequest(skip: 0));
      if (localSerial != _requestSerial) return;
      await res.fold((err) async {
        _errorMessage = err.message;
      }, (GlobalList<Cart> data) async {
        _items.addAll(data.list ?? const []);
        _totalCount = data.totalCount ?? _items.length;
      });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (localSerial != _requestSerial) return;
      _isFirstLoad = false;
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isFirstLoad || _isLoadingMore) return;
    if (!hasMore) return;

    _errorMessage = null;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final res = await CartRepo.fetchCart(_buildRequest(skip: _items.length));
      await res.fold((err) async {
        _errorMessage = err.message;
      }, (GlobalList<Cart> data) async {
        _items.addAll(data.list ?? const []);
        _totalCount = data.totalCount ?? _totalCount;
      });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> search({
    required String query,
    bool force = false,
  }) async {
    final normalized = query.trim();
    if (!force && normalized == _searchText.trim()) return;
    _searchText = normalized;
    await refresh();
  }

  bool containsSku(String sku) {
    final normalized = sku.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _items.any(
      (e) => (e.variantDetails?.sku ?? '').trim().toLowerCase() == normalized,
    );
  }

  Future<Cart?> verifySkuFromApi(String sku) async {
    final normalized = sku.trim();
    if (normalized.isEmpty) return null;
    _isVerifyingSku = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final req = CartRequest(
        skip: 0,
        limit: 1,
        searchingText: '',
        skuSearch: normalized,
        statusArray: const [1, 0],
        branchIds: _branchId == null ? [] : [_branchId!],
        cartIds: const [],
        customerIds: const [],
        productIds: const [],
        screenType: const [],
        sortType: 0,
        sortOrder: -1,
        variantIds: const [],
      );

      final res = await CartRepo.fetchCart(req);
      Cart? item;
      await res.fold((err) async {
        _errorMessage = err.message;
      }, (data) async {
        final list = data.list ?? const [];
        if (list.isNotEmpty) {
          item = list.first;
        }
      });
      return item;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isVerifyingSku = false;
      notifyListeners();
    }
  }

  /// Remove an item from the local list by [cartId] — zero API calls.
  /// If the item is not in the list (already removed), this is a no-op.
  void removeItemLocally(String cartId) {
    final id = cartId.trim();
    if (id.isEmpty) return;
    final before = _items.length;
    _items.removeWhere((e) => (e.id ?? '').trim() == id);
    if (_items.length != before) {
      _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;
      debugPrint('[CartController] removeItemLocally id=$id ✓ totalCount=$_totalCount');
      notifyListeners();
    } else {
      debugPrint('[CartController] removeItemLocally id=$id ✗ not found (already removed)');
    }
  }

  /// Insert [cart] at the front of the local list — zero API calls.
  /// Silently skips if an item with the same id already exists (prevents
  /// duplicate from WS self-echo after the sender's own refresh).
  void insertItemLocally(Cart cart) {
    final id = (cart.id ?? '').trim();
    if (id.isNotEmpty && _items.any((e) => (e.id ?? '').trim() == id)) {
      debugPrint('[CartController] insertItemLocally id=$id ✗ already present (skip)');
      return;
    }
    _items.insert(0, cart);
    _totalCount += 1;
    debugPrint('[CartController] insertItemLocally id=$id ✓ totalCount=$_totalCount');
    notifyListeners();
  }

  void addScannedProduct(Cart item) {
    _items.insert(0, item);
    _totalCount += 1;
    notifyListeners();
  }

  Future<bool> isSkuAlreadyInCart(String sku) async {
    final normalized = sku.trim();
    if (normalized.isEmpty) return false;
    _isVerifyingSku = true;
    _errorMessage = null;
    notifyListeners();
    try {
      int skip = 0;
      const int pageSize = 50;
      while (true) {
        final req = CartRequest(
          skip: skip,
          limit: pageSize,
          searchingText: '',
          skuSearch: normalized,
          statusArray: const [1, 0],
          branchIds: _branchId == null ? [] : [_branchId!],
          cartIds: const [],
          customerIds: const [],
          productIds: const [],
          screenType: const [],
          sortType: 0,
          sortOrder: -1,
          variantIds: const [],
        );
        final res = await CartRepo.fetchCart(req);
        bool hasError = false;
        bool found = false;
        int totalCount = 0;
        int currentCount = 0;
        await res.fold((err) async {
          _errorMessage = err.message;
          hasError = true;
        }, (data) async {
          final list = data.list ?? const [];
          totalCount = data.totalCount ?? list.length;
          currentCount = list.length;
          found = list.any(
            (e) =>
                (e.variantDetails?.sku ?? '').trim().toLowerCase() ==
                normalized.toLowerCase(),
          );
        });
        if (hasError) return false;
        if (found) return true;
        if (currentCount == 0) return false;
        skip += currentCount;
        if (skip >= totalCount) return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isVerifyingSku = false;
      notifyListeners();
    }
  }

  Future<ProductList?> fetchProductBySku(String sku) async {
    final normalized = sku.trim();
    if (normalized.isEmpty) return null;
    _isVerifyingSku = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final req = ProductInput(
        limit: 1,
        skip: 0,
        searchingText: normalized,
        sortOrder: -1,
        sortType: 0,
        statusArray: const [1],
        productsIds: const [],
        screenType: const [101, 102, 103],
        brandIds: const [],
        categoryIds: const [],
        collectionIds: const [],
        isPublished: const [1],
        priceRangeEnd: -1,
        priceRangeStart: -1,
        specifications: const [],
        tagIds: const [],
        variantIds: const [],
        branchIds: _branchId == null ? [] : [_branchId!],
        collection: const [],
        tag: const [],
        brand: const [],
        category: const [],
        imageLimit: 1,
      );
      final res = await CartRepo.fetchProduct(req);
      ProductList? item;
      await res.fold((err) async {
        _errorMessage = err.message;
      }, (data) async {
        final list = data.list ?? const [];
        if (list.isNotEmpty) item = list.first;
      });
      return item;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isVerifyingSku = false;
      notifyListeners();
    }
  }

  Future<bool> addProductsToCart(List<ProductList> products) async {
    if (products.isEmpty) return false;
    final branch = _branchId;
    if (branch == null || branch.trim().isEmpty) {
      _errorMessage = 'Branch not found for current user.';
      notifyListeners();
      return false;
    }
    final items = <Item>[];
    for (final p in products) {
      final v = p.variantDetail;
      if (v?.id == null || v?.productId == null) continue;
      items.add(Item(productId: v!.productId, variantId: v.id, qty: 1));
    }
    if (items.isEmpty) {
      _errorMessage = 'No valid product selected.';
      notifyListeners();
      return false;
    }
    _isVerifyingSku = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await CartRepo.addToCart(
        AddToCartInput(
          branchId: branch,
          customerId: '',
          items: items,
        ),
      );
      bool ok = false;
      await res.fold((err) async {
        _errorMessage = err.message;
      }, (_) async {
        ok = true;
      });
      if (ok) {
        await refresh();
      }
      return ok;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isVerifyingSku = false;
      notifyListeners();
    }
  }
}
