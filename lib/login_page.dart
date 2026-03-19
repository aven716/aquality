import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'signup_page.dart';

// ════════════════════════════════════════════
// LOGIN PAGE
// ════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool    _obscurePassword = true;
  bool    _isLoading       = false;
  String? _errorMessage;

  late AnimationController _blobController;
  late AnimationController _fadeController;
  late Animation<double>   _fadeIn;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _blobController.dispose();
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Firebase Auth Login ───────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AquaMonitorHome(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = switch (e.code) {
          'user-not-found'     => 'No account found for this email.',
          'wrong-password'     => 'Incorrect password.',
          'invalid-email'      => 'Invalid email address.',
          'invalid-credential' => 'Invalid email or password.',
          'user-disabled'      => 'This account has been disabled.',
          'too-many-requests'  => 'Too many attempts. Try again later.',
          _                    => 'Login failed. Please try again.',
        };
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        AnimatedBuilder(
          animation: _blobController,
          builder: (_, __) => CustomPaint(
            size: size,
            painter: _BlobPainter(t: _blobController.value),
          ),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                SizedBox(height: size.height * 0.10),
                _buildLogo(),
                SizedBox(height: size.height * 0.06),
                _buildCard(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLogo() {
    return Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF0055FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.45),
              blurRadius: 28, spreadRadius: 2, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.water_drop, color: Colors.white, size: 34),
      ),
      const SizedBox(height: 18),
      const Text('AQuality',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0)),
      const SizedBox(height: 6),
      Text('Water Quality Monitoring System',
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.40), letterSpacing: 0.3)),
    ]);
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628).withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sign in',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('Access your monitoring dashboard',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.38))),
        const SizedBox(height: 28),

        _label('Email'),
        const SizedBox(height: 8),
        _AqualityTextField(
          controller: _emailController,
          hint: 'you@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your email';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 20),

        _label('Password'),
        const SizedBox(height: 8),
        _AqualityTextField(
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.35), size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter your password';
            if (v.length < 6) return 'Password too short';
            return null;
          },
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              foregroundColor: const Color(0xFF00D4FF),
            ),
            child: const Text('Forgot password?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4444).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFFF4444), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMessage!,
                  style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 8),
        _buildSignInButton(),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.28)))),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
        ]),
        const SizedBox(height: 20),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Don't have an account? ",
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.38))),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SignUpPage(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            ),
            child: const Text('Sign up',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00D4FF))),
          ),
        ]),
      ])),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.55), letterSpacing: 0.4));

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isLoading
              ? LinearGradient(colors: [const Color(0xFF00D4FF).withOpacity(0.5), const Color(0xFF0055FF).withOpacity(0.5)])
              : const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0055FF)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isLoading ? [] : [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.30), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isLoading ? null : _handleLogin,
            child: Center(child: _isLoading
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ])),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// ANIMATED BACKGROUND BLOBS
// ════════════════════════════════════════════

class _BlobPainter extends CustomPainter {
  final double t;
  const _BlobPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void blob(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius,
          Paint()..shader = RadialGradient(colors: [color, Colors.transparent])
              .createShader(Rect.fromCircle(center: center, radius: radius)));
    }
    blob(Offset(w * 0.15 + t * w * 0.08, h * 0.12 + t * h * 0.06), w * 0.55,
        const Color(0xFF00D4FF).withOpacity(0.18));
    blob(Offset(w * 0.88 - t * w * 0.06, h * 0.82 - t * h * 0.04), w * 0.50,
        const Color(0xFF0055FF).withOpacity(0.14));
    blob(Offset(w * 0.75, h * 0.30 + t * h * 0.05), w * 0.35,
        const Color(0xFF00FF88).withOpacity(0.07));
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

// ════════════════════════════════════════════
// CUSTOM TEXT FIELD
// ════════════════════════════════════════════

class _AqualityTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AqualityTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_AqualityTextField> createState() => _AqualityTextFieldState();
}

class _AqualityTextFieldState extends State<_AqualityTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _focused ? const Color(0xFF00D4FF).withOpacity(0.6) : Colors.white.withOpacity(0.09),
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.12), blurRadius: 12)]
            : [],
      ),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.22), fontSize: 14),
            prefixIcon: Icon(widget.icon,
                color: _focused ? const Color(0xFF00D4FF) : Colors.white.withOpacity(0.30), size: 19),
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
          ),
        ),
      ),
    );
  }
}