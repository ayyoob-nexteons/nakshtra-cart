import 'package:dartz/dartz.dart';
import 'package:nakshatra/model/add_to_cart_input/add_to_cart_input.dart';
import 'package:nakshatra/model/api_error.dart';
import 'package:nakshatra/model/cart/cart.dart';
import 'package:nakshatra/model/cart_request/cart_request.dart';
import 'package:nakshatra/model/cart_status_change/cart_status_model.dart';
import 'package:nakshatra/model/global_list.dart';
import 'package:nakshatra/model/prodcut_input/product_input.dart';
import 'package:nakshatra/model/product_list/product_list.dart';

import 'package:nakshatra/service/query.dart';
import 'package:nakshatra/service/repository.dart';

class CartRepo {
  static Future<Either<ApiError, GlobalList<Cart>>> fetchCart(
    CartRequest filter,
  ) async {
    var response = await Repository().query(
      request: QueryRequest(
        query: _CartQuery.cart,
        variables: {"customerCartList": filter.toJson()},
      ),
      parser: (data) {
        return GlobalList.fromJson(data['CustomerCart_List'], (item) {
          return Cart.fromJson(item);
        });
      },
    );
    return response.fold(
      (left) {
        return Left(left);
      },
      (right) {
        return Right(right);
      },
    );
  }

  static Future<Either<ApiError, GlobalList<ProductList>>> fetchProduct(
    ProductInput filter,
  ) async {
    var response = await Repository().query(
      request: QueryRequest(
        query: _CartQuery.product,
        variables: {"productList": filter.toJson()},
      ),
      parser: (data) {
        return GlobalList.fromJson(data['Product_List'], (item) {
          return ProductList.fromJson(item);
        });
      },
    );
    return response.fold(
      (left) {
        return Left(left);
      },
      (right) {
        return Right(right);
      },
    );
  }

  static Future<Either<ApiError, String>> addToCart(AddToCartInput input) async {
    var response = await Repository().query(
      request: QueryRequest(
        query: _CartQuery.addToCart,
        variables: {"customerCartCreateBulk": input.toJson()},
      ),
      parser: (data) {
        return data['CustomerCart_CreateBulk']?.toString() ?? '';
      },
    );
    return response.fold(
      (left) {
        return Left(left);
      },
      (right) {
        return Right(right);
      },
    );
  }



  static Future<Either<ApiError, String>> cartStatusChange(CartStatusModel input) async {
    var response = await Repository().query(
      request: QueryRequest(
        query: _CartQuery.cartStatusChange,
        variables: {"customerCartStatusChange": input.toJson()},
      ),
      parser: (data) {
        return data['CustomerCart_StatusChange']?.toString() ?? '';
      },
    );
    return response.fold(
      (left) {
        return Left(left);
      },
      (right) {
        return Right(right);
      },
    );
  }


}

class _CartQuery {
  static const String cart = r'''
mutation CustomerCart_List($customerCartList: ListCustomerCartInput!) {
  CustomerCart_List(CustomerCart_List: $customerCartList) {
    list {
      _id
      _customerId
      _qty
      _status
      _variantId
      variantDetails {
        _displayName
        _id
        _name
        _status
        _sku
        _shortDescription
        _qty
        _productId
        metals {
          _metalId
          _id
          metalDetails {
            _id
            _pricePerGram
          }
          _weight
        }
      }
    }
    totalCount
  }
}
''';


  static const String product =
      r'''mutation Product_List($productList: ListProductsInput!) {
  Product_List(Product_List: $productList) {
       list {
      _id
      variantDetail {
        _id
        _sku
        _displayName
        _storePrice
        _originalPrice

 

        _qty
        _productId
        _isInclusive
                _name

        imageCount
        _isOutOfStockSellable

        images {
          _url
          _id
          _isThumbnail
          __typename
        }

        __typename
      }
      __typename
    }
    __typename
  }
}
  
''';


static const String addToCart = r'''mutation CustomerCart_CreateBulk($customerCartCreateBulk: CreateCustomerCartBulkInput!) {
  CustomerCart_CreateBulk(CustomerCart_CreateBulk: $customerCartCreateBulk)
}''';


static const String cartStatusChange = r'''mutation CustomerCart_StatusChange($customerCartStatusChange: StatusChangeCustomerCartInput!) {
  CustomerCart_StatusChange(CustomerCart_StatusChange: $customerCartStatusChange)
}''';
}
