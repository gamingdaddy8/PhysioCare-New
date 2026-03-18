import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDarkText = Color(0xFF0F172A);
  static const Color kSubText = Color(0xFF64748B);
  static const Color kCardBorder = Color(0xFFE2E8F0);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;

  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _toast("Please enter email and password");
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Login
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) {
        _toast("Login failed");
        return;
      }

      // 2) Ensure profile exists + role is correct (Option B)
      final existingProfile = await supabase
          .from("profiles")
          .select()
          .eq("id", user.id)
          .maybeSingle();

      final meta = user.userMetadata ?? {};
      final metaRole = (meta["role"] ?? "patient").toString();

      if (existingProfile == null) {
        // First login after email verification
        await supabase.from("profiles").insert({
          "id": user.id,
          "role": metaRole,
          "full_name": meta["full_name"] ?? "Unnamed",
          "phone": meta["phone"],
          "alt_phone": meta["alt_phone"],
          "address": meta["address"],
          "assigned_therapist_id": meta["assigned_therapist_id"],
        });
      } else {
        // If profile exists but role is missing/wrong, fix it from metadata
        final dbRole = (existingProfile["role"] ?? "").toString();

        if (dbRole.isEmpty || (dbRole != "patient" && dbRole != "therapist")) {
          await supabase
              .from("profiles")
              .update({"role": metaRole})
              .eq("id", user.id);
        }
      }

      // 3) Fetch role from profiles (source of truth)
      final profile = await supabase
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .single();

      final role = (profile["role"] ?? "patient").toString();

      if (!mounted) return;

      // 4) Navigate based on role
      if (role == "therapist") {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.therapistHome,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.patientHome,
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // soft glow background
          Positioned(
            left: -140,
            top: 120,
            child: Container(
              height: 420,
              width: 420,
              decoration: BoxDecoration(
                color: LoginScreen.kPrimary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -170,
            bottom: 100,
            child: Container(
              height: 520,
              width: 520,
              decoration: BoxDecoration(
                color: LoginScreen.kPrimary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: LoginScreen.kCardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: LoginScreen.kPrimary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.monitor_heart,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "PhysioCare",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: LoginScreen.kDarkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: LoginScreen.kDarkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Sign in to continue your recovery journey",
                        style: TextStyle(
                          color: LoginScreen.kSubText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),

                      _Label("Email"),
                      const SizedBox(height: 8),
                      _TextField(
                        controller: _email,
                        hint: "you@example.com",
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      _Label("Password"),
                      const SizedBox(height: 8),
                      _TextField(
                        controller: _password,
                        hint: "••••••••",
                        obscure: _obscure,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() => _obscure = !_obscure);
                          },
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: LoginScreen.kSubText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LoginScreen.kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: LoginScreen.kSubText),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.register);
                            },
                            child: const Text(
                              "Sign up",
                              style: TextStyle(
                                color: LoginScreen.kPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: LoginScreen.kDarkText,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _TextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LoginScreen.kCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LoginScreen.kCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: LoginScreen.kPrimary, width: 1.6),
        ),
      ),
    );
  }
}