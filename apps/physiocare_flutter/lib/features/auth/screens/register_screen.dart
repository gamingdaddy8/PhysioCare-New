import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routes/app_routes.dart';

enum RegisterRole { patient, therapist }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const Color kPrimary = Color(0xFF1FC7B6);
  static const Color kDarkText = Color(0xFF0F172A);
  static const Color kSubText = Color(0xFF64748B);
  static const Color kCardBorder = Color(0xFFE2E8F0);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final supabase = Supabase.instance.client;

  RegisterRole _role = RegisterRole.patient;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Patient
  final _patientPhone = TextEditingController();
  final _familyPhone = TextEditingController();
  final _address = TextEditingController();

  // Therapist
  final _therapistPhone = TextEditingController();

  // Therapist selection (for patient registration)
  List<Map<String, dynamic>> _therapists = [];
  String? _selectedTherapistId;
  bool _loadingTherapists = false;

  bool _loading = false;
  bool _obscure = true;

    @override
  void initState() {
    super.initState();
    _loadTherapists();
  }

  Future<void> _loadTherapists() async {
    setState(() => _loadingTherapists = true);

    try {
      final rows = await supabase
          .from("profiles")
          .select("id, full_name")
          .eq("role", "therapist")
          .order("full_name", ascending: true);

      _therapists = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Auto-select first therapist if available (optional)
      if (_therapists.isNotEmpty && _selectedTherapistId == null) {
        _selectedTherapistId = _therapists.first["id"]?.toString();
      }
    } catch (e) {
      // Don't block registration UI, just show a toast
      if (mounted) _toast("Failed to load therapists");
    } finally {
      if (mounted) setState(() => _loadingTherapists = false);
    }
  }

@override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _patientPhone.dispose();
    _familyPhone.dispose();
    _address.dispose();
    _therapistPhone.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  bool _isValidEmail(String email) {
    return email.contains("@") && email.contains(".");
  }

  Future<void> _register() async {
    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (fullName.isEmpty) {
      _toast("Enter full name");
      return;
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      _toast("Enter a valid email");
      return;
    }
    if (password.length < 6) {
      _toast("Password must be at least 6 characters");
      return;
    }

    // role fields validation
    if (_role == RegisterRole.patient) {
      if (_patientPhone.text.trim().isEmpty) {
        _toast("Enter patient phone number");
        return;
      }
      if (_familyPhone.text.trim().isEmpty) {
        _toast("Enter family phone number");
        return;
      }
      if (_address.text.trim().isEmpty) {
        _toast("Enter patient address");
        return;
      }
      if (_selectedTherapistId == null || _selectedTherapistId!.isEmpty) {
        _toast("Select your physiotherapist");
        return;
      }
    } else {
      if (_therapistPhone.text.trim().isEmpty) {
        _toast("Enter therapist phone number");
        return;
      }
    }

    setState(() => _loading = true);

    try {
      // 1) signup (Option B: Email confirmation ON)
      // Store profile info in user_metadata. We'll create the profiles row on first login.
      final roleStr = _role == RegisterRole.patient ? "patient" : "therapist";

      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          "role": roleStr,
          "full_name": fullName,
          "phone": _role == RegisterRole.patient
              ? _patientPhone.text.trim()
              : _therapistPhone.text.trim(),
          "alt_phone":
              _role == RegisterRole.patient ? _familyPhone.text.trim() : null,
          "address": _role == RegisterRole.patient ? _address.text.trim() : null,
          "assigned_therapist_id":
              _role == RegisterRole.patient ? _selectedTherapistId : null,
        },
      );
if (!mounted) return;

      _toast("Account created ✅ Please login");

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
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
          // background glow
          Positioned(
            left: -140,
            top: 120,
            child: Container(
              height: 420,
              width: 420,
              decoration: BoxDecoration(
                color: RegisterScreen.kPrimary.withOpacity(0.12),
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
                color: RegisterScreen.kPrimary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: RegisterScreen.kCardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: RegisterScreen.kPrimary,
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
                              color: RegisterScreen.kDarkText,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: RegisterScreen.kDarkText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Join PhysioCare to start your recovery",
                        style: TextStyle(
                          color: RegisterScreen.kSubText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Role selector
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              selected: _role == RegisterRole.patient,
                              icon: Icons.person_outline,
                              title: "Patient",
                              onTap: () {
                                setState(() => _role = RegisterRole.patient);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _RoleCard(
                              selected: _role == RegisterRole.therapist,
                              icon: Icons.medical_services_outlined,
                              title: "Physiotherapist",
                              onTap: () {
                                setState(() => _role = RegisterRole.therapist);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _Label("Full Name"),
                      const SizedBox(height: 8),
                      _TextField(controller: _fullName, hint: "John Doe"),
                      const SizedBox(height: 14),

                      _Label("Email"),
                      const SizedBox(height: 8),
                      _TextField(
                        controller: _email,
                        hint: "you@example.com",
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

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
                            color: RegisterScreen.kSubText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_role == RegisterRole.patient) ...[
                        _Label("Phone Number (Patient)"),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _patientPhone,
                          hint: "9876543210",
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),

                        _Label("Family Phone Number (Alternate)"),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _familyPhone,
                          hint: "9876543210",
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),

                        _Label("Address"),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _address,
                          hint: "House no, street, city, state",
                          maxLines: 2,
                        ),

                          const SizedBox(height: 14),

                        _Label("Select Your Physiotherapist"),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: RegisterScreen.kCardBorder),
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedTherapistId,
                              hint: const Text("Choose physiotherapist"),
                              items: _therapists
                                  .map(
                                    (t) => DropdownMenuItem<String>(
                                      value: t["id"]?.toString(),
                                      child: Text(
                                        (t["full_name"] ?? "Unnamed").toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _loadingTherapists
                                  ? null
                                  : (value) {
                                      setState(() => _selectedTherapistId = value);
                                    },
                            ),
                          ),
                        ),
                        if (_loadingTherapists) ...[
                          const SizedBox(height: 10),
                          const Text(
                            "Loading physiotherapists...",
                            style: TextStyle(
                              fontSize: 12,
                              color: RegisterScreen.kSubText,
                            ),
                          ),
                        ],
                      ] else ...[
                        _Label("Phone Number (Therapist)"),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _therapistPhone,
                          hint: "9876543210",
                          keyboardType: TextInputType.phone,
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RegisterScreen.kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _register,
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
                                  "Create Account",
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
                            "Already have an account? ",
                            style: TextStyle(color: RegisterScreen.kSubText),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.login);
                            },
                            child: const Text(
                              "Sign in",
                              style: TextStyle(
                                color: RegisterScreen.kPrimary,
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

class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? RegisterScreen.kPrimary.withOpacity(0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? RegisterScreen.kPrimary
                : RegisterScreen.kCardBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? RegisterScreen.kPrimary
                  : RegisterScreen.kSubText,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected
                    ? RegisterScreen.kPrimary
                    : RegisterScreen.kSubText,
              ),
            ),
          ],
        ),
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
          color: RegisterScreen.kDarkText,
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
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RegisterScreen.kCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RegisterScreen.kCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: RegisterScreen.kPrimary, width: 1.6),
        ),
      ),
    );
  }
}