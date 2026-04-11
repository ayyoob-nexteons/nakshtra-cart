import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nakshatra/controller/auth_controller.dart';
import 'package:nakshatra/router/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'guppyai.dev@gmail.com');
  final _passCtrl = TextEditingController(text: '123456');
  final _controller = AuthController();
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await _controller.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (success) {
      context.go(AppRouter.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage ?? 'Login failed'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showComingSoon(String provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComingSoonSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    const softGrey = Color(0xFFF7F8FA);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final loading = _controller.isLoading;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 56),

                        // ── Logo ──────────────────────────────────────
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: teal.withOpacity(0.28),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Nakshatra',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: Color(0xFF0D1117),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Welcome back! Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Colors.grey[500],
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Email Field ───────────────────────────────
                        _FieldLabel(label: 'Email address'),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _emailCtrl,
                          enabled: !loading,
                          hintText: 'you@example.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty) return 'Email is required';
                            if (!val.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // ── Password Field ────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _FieldLabel(label: 'Password'),
                            
                          ],
                        ),
                        const SizedBox(height: 8),
                        _InputField(
                          controller: _passCtrl,
                          enabled: !loading,
                          hintText: '••••••••',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            onPressed: loading
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: const Color(0xFFADB5BD),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return 'Password is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        // ── Sign In Button ────────────────────────────
                        SizedBox(
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: loading
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF0F766E),
                                        Color(0xFF0D9488),
                                      ],
                                    ),
                              color: loading ? Color(0xFFB2DFDB) : null,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: loading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: teal.withOpacity(0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Divider ───────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                  color: Colors.grey[200], thickness: 1),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'or continue with',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey[400],
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                  color: Colors.grey[200], thickness: 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Social Buttons ────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _SocialButton(
                                icon: Icons.apple,
                                label: 'Apple',
                                onTap: () => _showComingSoon('Apple'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SocialButton(
                                icon: Icons.g_mobiledata_rounded,
                                label: 'Google',
                                onTap: () => _showComingSoon('Google'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Reusable field label ──────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Reusable styled input ─────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF0D1117),
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFCBD5E0),
          fontSize: 15,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(prefixIcon, size: 20, color: const Color(0xFFADB5BD)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

// ── Social button ─────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: const Color(0xFF374151)),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ── Coming Soon bottom sheet ───────────────────────────────────────────────────
class _ComingSoonSheet extends StatelessWidget {
  final String provider;
  const _ComingSoonSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // pill handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: teal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: teal,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '$provider Sign-In',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D1117),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re working on $provider authentication.\nIt\'ll be available very soon!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}