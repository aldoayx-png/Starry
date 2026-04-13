import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _codeController = TextEditingController();
  bool isVerifying = false;
  bool isResending = false;
  String? successMessage;
  String? errorMessage;

  Future<void> verifyCode() async {
    if (_codeController.text.isEmpty) {
      setState(() {
        errorMessage = 'Ingresa el código de verificación';
      });
      return;
    }

    if (_codeController.text.length != 6) {
      setState(() {
        errorMessage = 'El código debe tener 6 dígitos';
      });
      return;
    }

    setState(() {
      isVerifying = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'code': _codeController.text}),
      );

      if (response.statusCode == 200) {
        setState(() {
          successMessage = 'Cuenta verificada correctamente. Redirigiendo...';
          isVerifying = false;
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  LoginPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    final fade = Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(animation);
                    return FadeTransition(opacity: fade, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Error en la verificación';
        setState(() {
          errorMessage = error;
          isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de red. Intenta más tarde.';
        isVerifying = false;
      });
    }
  }

  Future<void> resendCode() async {
    setState(() {
      isResending = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        setState(() {
          successMessage = 'Código reenviado. Revisa tu bandeja de entrada.';
          isResending = false;
        });
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Error al reenviar';
        setState(() {
          errorMessage = error;
          isResending = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de red. Intenta más tarde.';
        isResending = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              Colors.black,
              Color(0xFF4A00E0),
              Color(0xFF4A00E0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 140),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  constraints: const BoxConstraints(
                    maxWidth: 320,
                    minWidth: 260,
                  ),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 255, 255, 0.10),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Color.fromRGBO(255, 255, 255, 0.7),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Verifica tu código',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hemos enviado un código a:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(255, 255, 255, 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color.fromRGBO(255, 255, 255, 0.2),
                          ),
                        ),
                        child: Text(
                          widget.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Ingresa el código de 6 dígitos. Expira en 15 minutos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Código',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (successMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              successMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.lightGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(
                              255,
                              255,
                              255,
                              0.10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shadowColor: Color.fromRGBO(0, 0, 0, 0.15),
                          ),
                          onPressed: isVerifying ? null : verifyCode,
                          child: isVerifying
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'VERIFICAR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1.1,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: isResending ? null : resendCode,
                          child: isResending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white70,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Reenviar código',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 1.0,
                                    color: Colors.white70,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
