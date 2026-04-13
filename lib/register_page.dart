import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'login_page.dart';
import 'email_verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String? email;
  String? password;
  String? username;
  bool isLoading = false;
  String? errorMessage;
  // Usar el repositorio global de usuarios
  // Eliminar referencia a usuarios locales

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo con degradado morado
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black, // negro arriba
              Colors.black, // negro arriba
              Color(0xFF4A00E0), // morado azulado
              Color(0xFF4A00E0), // morado azulado
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
                // Logo de la app completamente pegado arriba
                Image.asset(
                  'assets/logo.png', // Cambia la ruta si tu logo está en otro lugar
                  height: 140,
                ),
                // Eliminar cualquier espacio entre logo y contenedor
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
                    color: Color.fromRGBO(255, 255, 255, 0.10), // más blanco
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
                          'Crear cuenta',
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
                          '¡Regístrate para comenzar!',
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
                            labelText: 'Usuario',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Colors.white54,
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingresa un usuario'
                              : null,
                          onSaved: (value) => username = value,
                        ),
                        const SizedBox(height: 18),
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
                              ), // fondo claro
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  30,
                                ), // más redondeado
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.1, // igual que el contenedor
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
                                      // Llamada a la API de registro
                                      http.Response response;
                                      try {
                                        response = await http.post(
                                          Uri.parse(
                                            'https://starry-1zm8.onrender.com/api/register',
                                          ),
                                          headers: {
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({
                                            'email': email,
                                            'password': password,
                                            'username': username,
                                          }),
                                        );
                                        if (response.statusCode == 201) {
                                          try {
                                            final responseData = jsonDecode(
                                              response.body,
                                            );
                                            final requiresVerification =
                                                responseData['requiresVerification'] ??
                                                false;

                                            if (requiresVerification) {
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
                                                        ) =>
                                                            EmailVerificationPage(
                                                              email: email!,
                                                            ),
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
                                                              ).animate(
                                                                animation,
                                                              );
                                                          return FadeTransition(
                                                            opacity: fade,
                                                            child: child,
                                                          );
                                                        },
                                                    transitionDuration:
                                                        const Duration(
                                                          milliseconds: 500,
                                                        ),
                                                  ),
                                                );
                                              }
                                            } else {
                                              setState(() {
                                                errorMessage =
                                                    'Error al crear la cuenta';
                                                isLoading = false;
                                              });
                                            }
                                          } catch (e) {
                                            setState(() {
                                              errorMessage =
                                                  'Error al procesar el registro';
                                              isLoading = false;
                                            });
                                          }
                                        } else {
                                          final error =
                                              jsonDecode(
                                                response.body,
                                              )['error'] ??
                                              'Unknown error';
                                          setState(() {
                                            errorMessage = error;
                                            isLoading = false;
                                          });
                                        }
                                      } catch (e) {
                                        setState(() {
                                          errorMessage =
                                              'Network or server error';
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
                                    'REGISTRARME',
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
                                        LoginPage(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
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
                            '¿Ya tienes una cuenta? Inicia sesión',
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
