import 'package:go_router/go_router.dart';
import 'package:nakshatra/screens/add_product_screen.dart';
import 'package:nakshatra/screens/cart_list_screen.dart';
import 'package:nakshatra/screens/login_screen.dart';
import 'package:nakshatra/screens/splash_screen.dart';

class AppRouter {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const addProduct = '/add-product';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const CartListScreen(),
      ),
      GoRoute(
        path: addProduct,
        builder: (context, state) => const AddProductScreen(),
      ),
    ],
  );
}
