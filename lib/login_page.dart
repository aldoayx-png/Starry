import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_page.dart';
import 'main.dart';
import 'token_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? password;
  bool isLoading = false;
  String? errorMessage;
  // Eliminar referencia a usuarios locales

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
                    vertical: 24,
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¡Bienvenido de nuevo!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.email,
                              color: Colors.white54,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingresa tu correo electrónico'
                              : null,
                          onSaved: (value) => email = value,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.white54,
                            ),
                          ),
                          obscureText: true,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingresa tu contraseña'
                              : null,
                          onSaved: (value) => password = value,
                        ),
                        const SizedBox(height: 24),
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
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
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      _formKey.currentState!.save();
                                      setState(() {
                                        errorMessage = null;
                                        isLoading = true;
                                      });
                                      // Llamada a la API de login
                                      http.Response response;
                                      try {
                                        response = await http.post(
                                          Uri.parse(
                                            'http://localhost:3000/api/login',
                                          ),
                                          headers: {
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({
                                            'email': email,
                                            'password': password,
                                          }),
                                        );
                                        if (response.statusCode == 200) {
                                          final responseData = jsonDecode(
                                            response.body,
                                          );
                                          final token = responseData['token'];
                                          final userId = responseData['userId'];
                                          // Limpiar cualquier token anterior
                                          await TokenStorage.clearToken();
                                          // Guardar el nuevo token y userId
                                          await TokenStorage.saveToken(token);
                                          if (userId != null) {
                                            await TokenStorage.saveUserId(
                                              userId,
                                            );
                                          }
                                          setState(() => isLoading = false);
                                          if (mounted) {
                                            Navigator.of(
                                              context,
                                            ).pushReplacement(
                                              PageRouteBuilder(
                                                pageBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                    ) => DreamJournalHome(),
                                                transitionsBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                      child,
                                                    ) {
                                                      final fade =
                                                          Tween<double>(
                                                            begin: 0.0,
                                                            end: 1.0,
                                                          ).animate(animation);
                                                      final scale =
                                                          Tween<double>(
                                                            begin: 1.5,
                                                            end: 1.0,
                                                          ).animate(
                                                            CurvedAnimation(
                                                              parent: animation,
                                                              curve: Curves
                                                                  .easeOutCubic,
                                                            ),
                                                          );
                                                      return Stack(
                                                        children: [
                                                          FadeTransition(
                                                            opacity: fade,
                                                            child:
                                                                ScaleTransition(
                                                                  scale: scale,
                                                                  child: child,
                                                                ),
                                                          ),
                                                          Positioned.fill(
                                                            child: AnimatedBuilder(
                                                              animation:
                                                                  animation,
                                                              builder: (context, _) {
                                                                final opacity =
                                                                    (1 -
                                                                            (animation.value -
                                                                                        0.5)
                                                                                    .abs() *
                                                                                2)
                                                                        .clamp(
                                                                          0.0,
                                                                          1.0,
                                                                        );
                                                                return IgnorePointer(
                                                                  child: Container(
                                                                    color: Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              opacity *
                                                                              0.35,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                transitionDuration:
                                                    const Duration(
                                                      milliseconds: 700,
                                                    ),
                                              ),
                                            );
                                          }
                                        } else {
                                          final error =
                                              jsonDecode(
                                                response.body,
                                              )['error'] ??
                                              'Error desconocido';
                                          setState(() {
                                            errorMessage = error;
                                            isLoading = false;
                                          });
                                        }
                                      } catch (e) {
                                        setState(() {
                                          errorMessage =
                                              'Error de red o servidor';
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.1,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        RegisterPage(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      // Animación tipo "destello espacial": fade + scale + color overlay
                                      final fade = Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(animation);
                                      final scale =
                                          Tween<double>(
                                            begin: 1.5,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          );
                                      return Stack(
                                        children: [
                                          FadeTransition(
                                            opacity: fade,
                                            child: ScaleTransition(
                                              scale: scale,
                                              child: child,
                                            ),
                                          ),
                                          // Overlay de destello blanco con opacidad animada
                                          Positioned.fill(
                                            child: AnimatedBuilder(
                                              animation: animation,
                                              builder: (context, _) {
                                                final opacity =
                                                    (1 -
                                                            (animation.value -
                                                                        0.5)
                                                                    .abs() *
                                                                2)
                                                        .clamp(0.0, 1.0);
                                                return IgnorePointer(
                                                  child: Container(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: opacity * 0.35,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                transitionDuration: const Duration(
                                  milliseconds: 700,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            '¿No tienes cuenta? Regístrate',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
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
