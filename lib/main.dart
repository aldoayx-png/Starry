import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dream_detail_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'token_storage.dart';
import 'profile_page.dart';
import 'calendar_page.dart';
import 'forum_page.dart';
import 'user_profile_page.dart';
import 'users_page.dart';
import 'settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Diario de Sueños',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/login':
            page = const LoginPage();
            break;
          case '/register':
            page = const RegisterPage();
            break;
          case '/home':
            page = const DreamJournalHome();
            break;
          case '/profile':
            page = const ProfilePage();
            break;
          case '/calendar':
            page = const CalendarPage();
            break;
          case '/forum':
            page = const ForumPage();
            break;
          case '/users':
            page = const UsersPage();
            break;
          case '/settings':
            page = const SettingsPage();
            break;
          case '/user_profile':
            final args = settings.arguments as Map<String, dynamic>?;
            page = UserProfilePage(
              userId: (args?['userId'] as String?) ?? '',
              username: (args?['username'] as String?) ?? 'Usuario',
            );
            break;
          default:
            page = const LoginPage();
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
            final scale = Tween<double>(begin: 1.5, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return Stack(
              children: [
                FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(scale: scale, child: child),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final opacity = (1 - (animation.value - 0.5).abs() * 2)
                          .clamp(0.0, 1.0);
                      return IgnorePointer(
                        child: Container(
                          color: Colors.white.withValues(alpha: opacity * 0.35),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        );
      },
    );
  }
}

class DreamJournalHome extends StatefulWidget {
  const DreamJournalHome({super.key});

  @override
  State<DreamJournalHome> createState() => _DreamJournalHomeState();
}

class _DreamJournalHomeState extends State<DreamJournalHome>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;
  final List<Dream> _dreams = [];
  int _currentIndex = 0;
  String? username;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _stars = [];
    _controller.addListener(() {
      _updateStars();
      // No llamamos a setState aquí para evitar repintar todo el widget
    });

    _fetchUsername();
    _fetchDreams();
  }

  Future<void> _fetchUsername() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await http.get(
        Uri.parse('https://starry-1zm8.onrender.com/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          username = data['username'];
        });
      }
    } catch (e) {
      // Error al obtener usuario
    }
  }

  Future<void> _fetchDreams() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await http.get(
        Uri.parse('https://starry-1zm8.onrender.com/api/dreams'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final dreamsList = data.map((e) => Dream.fromJson(e)).toList();
        // Guardar el índice original para desempate
        final indexedDreams = dreamsList
            .asMap()
            .entries
            .map((e) => {'dream': e.value, 'index': e.key})
            .toList();
        indexedDreams.sort((a, b) {
          final Dream da = a['dream'] as Dream;
          final Dream db = b['dream'] as Dream;
          if (da.date == null && db.date == null) {
            return (b['index'] as int) - (a['index'] as int);
          }
          if (da.date == null) return 1;
          if (db.date == null) return -1;
          final cmp = db.date!.compareTo(da.date!);
          if (cmp != 0) return cmp;
          // Si la fecha es igual, el más nuevo (mayor índice) primero
          return (b['index'] as int) - (a['index'] as int);
        });
        setState(() {
          _dreams.clear();
          _dreams.addAll(
            indexedDreams.map((e) => e['dream'] as Dream).toList(),
          );
        });
      } else if (response.statusCode == 401) {
        // Token inválido o expirado
        await TokenStorage.clearToken();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        }
      } else {
        // Manejar error de backend
      }
    } catch (e) {
      // Manejar error de red o parsing
    }
  }

  void _initStars(Size size) {
    final random = Random();
    _stars = List.generate(80, (index) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2.5 + 1.0;
      final speed = random.nextDouble() * 0.8 + 0.2;
      return Star(x, y, radius, speed);
    });
  }

  void _updateStars() {
    if (_stars.isEmpty) return;
    final size = _lastSize;
    for (var star in _stars) {
      star.x += star.speed;
      if (star.x > size.width) {
        star.x = 0;
        star.y = Random().nextDouble() * size.height;
      }
    }
  }

  Size _lastSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _lastSize = size;
    if (_stars.isEmpty) {
      _initStars(size);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          leading: null,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black,
                  Colors.black,
                  Color(0xFF2193b0),
                  Color(0xFF8e2de2),
                ],
                stops: [0.0, 0.25, 0.6, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          title: Container(
            alignment: Alignment.centerLeft,
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: GestureDetector(
              onTap: () {},
              child: Image.asset('assets/logo.png', height: 100, width: 100),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurpleAccent, Colors.blueAccent],
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.star, color: Colors.white, size: 20),
              ),
              tooltip: 'Perfil',
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          CustomPaint(
            size: size,
            painter: StarBackgroundPainter(stars: _stars, repaint: _controller),
          ),
          _dreams.isEmpty
              ? Center(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 80, 77, 77),
                          Color(0xFF2193b0),
                          Color(0xFF8e2de2),
                        ],
                        stops: [0.0, 0.6, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'No hay sueños registrados.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 32,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  itemCount: _dreams.length,
                  itemBuilder: (context, index) {
                    final dream = _dreams[index];
                    return GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DreamDetailPage(dream: dream),
                          ),
                        );
                        if (result != null && result is Map) {
                          if (result['deleted'] == true) {
                            setState(() {
                              _dreams.remove(result['dream']);
                            });
                          } else if (result['edited'] == true &&
                              result['dream'] != null) {
                            setState(() {
                              final idx = _dreams.indexWhere(
                                (d) => d.id == result['dream'].id,
                              );
                              if (idx != -1) {
                                _dreams[idx] = result['dream'];
                              }
                            });
                          }
                        }
                      },
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 900),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(
                                  77,
                                  (Colors.deepPurple.shade900.r * 255.0)
                                      .round()
                                      .clamp(0, 255),
                                  (Colors.deepPurple.shade900.g * 255.0)
                                      .round()
                                      .clamp(0, 255),
                                  (Colors.deepPurple.shade900.b * 255.0)
                                      .round()
                                      .clamp(0, 255),
                                ),
                                Color.fromARGB(
                                  77,
                                  (Colors.blue.shade900.r * 255.0)
                                      .round()
                                      .clamp(0, 255),
                                  (Colors.blue.shade900.g * 255.0)
                                      .round()
                                      .clamp(0, 255),
                                  (Colors.blue.shade900.b * 255.0)
                                      .round()
                                      .clamp(0, 255),
                                ),
                                Color.fromARGB(
                                  26,
                                  (Colors.black.r * 255.0).round().clamp(
                                    0,
                                    255,
                                  ),
                                  (Colors.black.g * 255.0).round().clamp(
                                    0,
                                    255,
                                  ),
                                  (Colors.black.b * 255.0).round().clamp(
                                    0,
                                    255,
                                  ),
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withAlpha(30),
                                blurRadius: 32,
                                offset: Offset(0, 16),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.deepPurpleAccent.withAlpha(60),
                              width: 2.5,
                            ),
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 12,
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.deepPurpleAccent,
                                          Colors.blueAccent,
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          username ?? '',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dream.title ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1.1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (dream.mood != null)
                                    Chip(
                                      label: Text(dream.mood ?? ''),
                                      backgroundColor: Colors.blue.shade700,
                                      labelStyle: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      avatar: const Icon(
                                        Icons.emoji_emotions,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  if (dream.date != null)
                                    Chip(
                                      label: Text(
                                        dream.date!.toLocal().toString().split(
                                          ' ',
                                        )[0],
                                      ),
                                      backgroundColor:
                                          Colors.deepPurple.shade700,
                                      labelStyle: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      avatar: const Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          // FAB flotante sobre el botón de ajustes
          Positioned(
            bottom: 20,
            right: 12,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [Color(0xFF2193b0), Color(0xFF8e2de2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => DreamFormDialog(
                      onSave: (dream) async {
                        final token = await TokenStorage.getToken();
                        final response = await http.post(
                          Uri.parse(
                            'https://starry-1zm8.onrender.com/api/dreams',
                          ),
                          headers: {
                            'Content-Type': 'application/json',
                            if (token != null) 'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({
                            'title': dream.title,
                            'date': dream.date?.toIso8601String(),
                            'mood': dream.mood,
                            'tags': dream.tags,
                            'people': dream.people,
                            'place': dream.place,
                            'clarity': dream.clarity,
                            'notes': dream.notes,
                            'isRecurring': dream.isRecurring,
                            'wokeUp': dream.wokeUp,
                            'dreamInfo': dream.dreamInfo,
                            'isShared': dream.isShared,
                          }),
                        );
                        if (response.statusCode == 201) {
                          final createdDream = Dream.fromJson(
                            jsonDecode(response.body),
                          );

                          // Si está marcado para compartir en el foro, guardar también en el foro
                          if (dream.isShared && createdDream.id != null) {
                            try {
                              await http.post(
                                Uri.parse(
                                  'https://starry-1zm8.onrender.com/api/forum/posts',
                                ),
                                headers: {
                                  'Content-Type': 'application/json',
                                  if (token != null)
                                    'Authorization': 'Bearer $token',
                                },
                                body: jsonEncode({
                                  'dreamId': createdDream.id,
                                  'title': dream.title,
                                  'date': dream.date?.toIso8601String(),
                                  'mood': dream.mood,
                                  'tags': dream.tags,
                                  'people': dream.people,
                                  'place': dream.place,
                                  'clarity': dream.clarity,
                                  'notes': dream.notes,
                                  'isRecurring': dream.isRecurring,
                                  'wokeUp': dream.wokeUp,
                                  'dreamInfo': dream.dreamInfo,
                                }),
                              );
                            } catch (e) {
                              debugPrint('Error al compartir en el foro: $e');
                            }
                          }
                          await _fetchDreams();
                          // Navigation ya maneja el dialog (no hacer pop aquí)
                        } else if (response.statusCode == 401) {
                          // Token inválido o expirado - el dialog se cerrará después del callback
                          await TokenStorage.clearToken();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (Route<dynamic> route) => false,
                            );
                          }
                          return;
                        } else {
                          // Manejar error de guardado
                        }
                      },
                    ),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.add, size: 36, color: Colors.white),
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (index == 1) {
                  Navigator.of(context)
                      .push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const CalendarPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                final fade = Tween<double>(
                                  begin: 0.0,
                                  end: 1.0,
                                ).animate(animation);
                                final scale =
                                    Tween<double>(begin: 1.5, end: 1.0).animate(
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
                                                      (animation.value - 0.5)
                                                              .abs() *
                                                          2)
                                                  .clamp(0.0, 1.0);
                                          return IgnorePointer(
                                            child: Container(
                                              color: Colors.white.withValues(
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
                          transitionDuration: const Duration(milliseconds: 700),
                        ),
                      )
                      .then((value) {
                        // Actualizar los sueños cuando volvemos del calendario
                        _fetchDreams();
                        // Resetear el índice a 0 (Inicio) cuando regresas
                        setState(() {
                          _currentIndex = 0;
                        });
                      });
                } else if (index == 2) {
                  Navigator.of(context)
                      .push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ForumPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                final fade = Tween<double>(
                                  begin: 0.0,
                                  end: 1.0,
                                ).animate(animation);
                                final scale =
                                    Tween<double>(begin: 1.5, end: 1.0).animate(
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
                                                      (animation.value - 0.5)
                                                              .abs() *
                                                          2)
                                                  .clamp(0.0, 1.0);
                                          return IgnorePointer(
                                            child: Container(
                                              color: Colors.white.withValues(
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
                          transitionDuration: const Duration(milliseconds: 700),
                        ),
                      )
                      .then((value) {
                        // Resetear el índice a 0 (Inicio) cuando regresas
                        setState(() {
                          _currentIndex = 0;
                        });
                      });
                } else if (index == 3) {
                  Navigator.of(context)
                      .push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const UsersPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                final fade = Tween<double>(
                                  begin: 0.0,
                                  end: 1.0,
                                ).animate(animation);
                                final scale =
                                    Tween<double>(begin: 1.5, end: 1.0).animate(
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
                                                      (animation.value - 0.5)
                                                              .abs() *
                                                          2)
                                                  .clamp(0.0, 1.0);
                                          return IgnorePointer(
                                            child: Container(
                                              color: Colors.white.withValues(
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
                          transitionDuration: const Duration(milliseconds: 700),
                        ),
                      )
                      .then((value) {
                        // Resetear el índice a 0 (Inicio) cuando regresas
                        setState(() {
                          _currentIndex = 0;
                        });
                      });
                } else if (index == 4) {
                  Navigator.of(context)
                      .push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const SettingsPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                final fade = Tween<double>(
                                  begin: 0.0,
                                  end: 1.0,
                                ).animate(animation);
                                final scale =
                                    Tween<double>(begin: 1.5, end: 1.0).animate(
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
                                                      (animation.value - 0.5)
                                                              .abs() *
                                                          2)
                                                  .clamp(0.0, 1.0);
                                          return IgnorePointer(
                                            child: Container(
                                              color: Colors.white.withValues(
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
                          transitionDuration: const Duration(milliseconds: 700),
                        ),
                      )
                      .then((value) {
                        // Resetear el índice a 0 (Inicio) cuando regresas
                        setState(() {
                          _currentIndex = 0;
                        });
                      });
                }
                // Aquí puedes implementar la navegación o acciones para cada sección si lo deseas
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF8e2de2),
              unselectedItemColor: Colors.white54,
              items: [
                BottomNavigationBarItem(
                  icon: Transform.translate(
                    offset: const Offset(0, 4),
                    child: const Icon(Icons.home),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Transform.translate(
                    offset: const Offset(0, 4),
                    child: const Icon(Icons.calendar_today),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Transform.translate(
                    offset: const Offset(0, 4),
                    child: const Icon(Icons.forum),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Transform.translate(
                    offset: const Offset(0, 4),
                    child: const Icon(Icons.people),
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Transform.translate(
                    offset: const Offset(0, 4),
                    child: const Icon(Icons.settings),
                  ),
                  label: '',
                ),
              ],
              type: BottomNavigationBarType.fixed,
            ),
          ),
        ),
      ),
    );
  }
}

class DreamFormDialog extends StatefulWidget {
  final Function(Dream)? onSave;
  final Dream? initialDream;
  const DreamFormDialog({super.key, this.onSave, this.initialDream});

  @override
  State<DreamFormDialog> createState() => _DreamFormDialogState();
}

class _DreamFormDialogState extends State<DreamFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? title;
  DateTime? date;
  String? mood;
  String? dreamInfo;
  List<String> tags = [];
  String? people;
  String? place;
  double clarity = 5;
  String? notes;
  bool isRecurring = false;
  bool wokeUp = false;
  bool isShared = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDream != null) {
      title = widget.initialDream!.title;
      date = widget.initialDream!.date;
      mood = widget.initialDream!.mood;
      dreamInfo = widget.initialDream!.dreamInfo;
      tags = List<String>.from(widget.initialDream!.tags);
      people = widget.initialDream!.people;
      place = widget.initialDream!.place;
      clarity = widget.initialDream!.clarity;
      notes = widget.initialDream!.notes;
      isRecurring = widget.initialDream!.isRecurring;
      wokeUp = widget.initialDream!.wokeUp;
      isShared = widget.initialDream!.isShared;
    }
  }

  final List<String> moods = [
    'Feliz',
    'Triste',
    'Ansioso',
    'Asustado',
    'Neutral',
  ];
  final List<String> tagOptions = [
    'Lúcido',
    'Pesadilla',
    'Recurrente',
    'Normal',
    'Colorido',
    'Corto',
    'Largo',
  ];

  IconData _getTagIcon(String tag) {
    switch (tag) {
      case 'Lúcido':
        return Icons.lightbulb;
      case 'Pesadilla':
        return Icons.warning;
      case 'Recurrente':
        return Icons.repeat;
      case 'Normal':
        return Icons.nightlight_round;
      case 'Colorido':
        return Icons.palette;
      case 'Corto':
        return Icons.timer;
      case 'Largo':
        return Icons.hourglass_bottom;
      default:
        return Icons.label;
    }
  }

  IconData _getMoodIcon(String moodType) {
    switch (moodType) {
      case 'Feliz':
        return Icons.emoji_emotions;
      case 'Triste':
        return Icons.sentiment_dissatisfied;
      case 'Ansioso':
        return Icons.sentiment_neutral;
      case 'Asustado':
        return Icons.sentiment_very_dissatisfied;
      case 'Neutral':
        return Icons.sentiment_satisfied;
      default:
        return Icons.mood;
    }
  }

  Color _getMoodColor(String moodType) {
    switch (moodType) {
      case 'Feliz':
        return Colors.greenAccent;
      case 'Triste':
        return Colors.blueAccent;
      case 'Ansioso':
        return Colors.orangeAccent;
      case 'Asustado':
        return Colors.redAccent;
      case 'Neutral':
        return Colors.grey;
      default:
        return Colors.white24;
    }
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'Lúcido':
        return Colors.amber.shade700;
      case 'Pesadilla':
        return Colors.red.shade700;
      case 'Recurrente':
        return Colors.purple.shade700;
      case 'Normal':
        return Colors.indigo.shade700;
      case 'Colorido':
        return Colors.pink.shade700;
      case 'Corto':
        return Colors.cyan.shade700;
      case 'Largo':
        return Colors.blue.shade700;
      default:
        return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF1a1a1a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF8e2de2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF8e2de2).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF8e2de2).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bedtime,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Registrar sueño',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Título',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Título del sueño',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.edit,
                              color: Color(0xFF8e2de2),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          initialValue: title ?? '',
                          onSaved: (value) => title = value,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingrese un título'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fecha',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                date = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(255, 255, 255, 0.08),
                              border: Border.all(
                                color: Color(0xFF8e2de2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF8e2de2),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    date == null
                                        ? 'Seleccionar fecha'
                                        : date!.toLocal().toString().split(
                                            ' ',
                                          )[0],
                                    style: TextStyle(
                                      color: date == null
                                          ? Colors.white54
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Estado de ánimo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: moods.map((moodOption) {
                            final selected = mood == moodOption;
                            final moodColor = _getMoodColor(moodOption);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  mood = moodOption;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? LinearGradient(
                                          colors: [
                                            moodColor,
                                            moodColor.withValues(alpha: 0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? moodColor
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: selected ? 2 : 1.5,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: moodColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 12,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getMoodIcon(moodOption),
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      moodOption,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    if (selected)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4.0,
                                        ),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Etiquetas',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: tagOptions.map((tag) {
                            final selected = tags.contains(tag);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    tags.remove(tag);
                                  } else {
                                    tags.add(tag);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? LinearGradient(
                                          colors: [
                                            _getTagColor(tag),
                                            _getTagColor(
                                              tag,
                                            ).withValues(alpha: 0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? _getTagColor(tag)
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: selected ? 2 : 1.5,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: _getTagColor(
                                              tag,
                                            ).withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getTagIcon(tag),
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    if (selected)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4.0,
                                        ),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Personas/Personajes',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Personas o personajes presentes',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.people,
                              color: Color(0xFF8e2de2),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          initialValue: people ?? '',
                          onSaved: (value) => people = value,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lugar/Ambiente',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Lugar o ambiente del sueño',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(
                              Icons.location_on,
                              color: Color(0xFF8e2de2),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          initialValue: place ?? '',
                          onSaved: (value) => place = value,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Claridad/Realismo: ${clarity.round()}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: clarity,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: clarity.round().toString(),
                          activeColor: Color(0xFF8e2de2),
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            setState(() {
                              clarity = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF8e2de2).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.note,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Notas/Interpretación',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Tu interpretación personal del sueño',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          initialValue: notes ?? '',
                          onSaved: (value) => notes = value,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF8e2de2).withValues(alpha: 0.1),
                            border: Border.all(
                              color: Color(0xFF8e2de2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                title: const Text(
                                  '¿Se repitió el sueño?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                value: isRecurring,
                                activeColor: Color(0xFF8e2de2),
                                checkColor: Colors.white,
                                onChanged: (value) => setState(
                                  () => isRecurring = value ?? false,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                              CheckboxListTile(
                                title: const Text(
                                  '¿Despertaste durante el sueño?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                value: wokeUp,
                                activeColor: Color(0xFF8e2de2),
                                checkColor: Colors.white,
                                onChanged: (value) =>
                                    setState(() => wokeUp = value ?? false),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                              CheckboxListTile(
                                title: const Text(
                                  'Compartir en el foro de sueños',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                value: isShared,
                                activeColor: Color(0xFF8e2de2),
                                checkColor: Colors.white,
                                onChanged: (value) =>
                                    setState(() => isShared = value ?? false),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF8e2de2).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.nightlight_round,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Información del sueño',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Describe tu sueño en detalle',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Color.fromRGBO(255, 255, 255, 0.08),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF8e2de2),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          initialValue: dreamInfo ?? '',
                          onSaved: (value) => dreamInfo = value,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Ingrese la información del sueño'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        final dream = Dream(
                          title: title,
                          date: date,
                          mood: mood,
                          tags: List.from(tags),
                          people: people,
                          place: place,
                          clarity: clarity,
                          notes: notes,
                          isRecurring: isRecurring,
                          wokeUp: wokeUp,
                          dreamInfo: dreamInfo,
                          isShared: isShared,
                        );
                        await widget.onSave?.call(dream);
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8e2de2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Guardar sueño',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Dream {
  String? id;
  String? userId;
  String? username;
  String? title;
  DateTime? date;
  String? mood;
  List<String> tags;
  String? people;
  String? place;
  double clarity;
  String? notes;
  bool isRecurring;
  bool wokeUp;
  String? dreamInfo;
  bool isShared;
  List<Comment> comments;

  Dream({
    this.id,
    this.userId,
    this.username,
    this.title,
    this.date,
    this.mood,
    this.tags = const [],
    this.people,
    this.place,
    this.clarity = 5,
    this.notes,
    this.isRecurring = false,
    this.wokeUp = false,
    this.dreamInfo,
    this.isShared = false,
    this.comments = const [],
  });

  factory Dream.fromJson(Map<String, dynamic> json) {
    return Dream(
      id: json['_id'] ?? json['id'],
      userId: json['userId'] is Map
          ? (json['userId'] as Map)['_id']
          : json['userId'],
      username: json['userId'] is Map
          ? (json['userId'] as Map)['username']
          : json['username'],
      title: json['title'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      mood: json['mood'],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      people: json['people'],
      place: json['place'],
      clarity: (json['clarity'] is int)
          ? (json['clarity'] as int).toDouble()
          : (json['clarity'] ?? 5).toDouble(),
      notes: json['notes'],
      isRecurring: json['isRecurring'] ?? false,
      wokeUp: json['wokeUp'] ?? false,
      dreamInfo: json['dreamInfo'],
      isShared: json['isShared'] ?? false,
      comments:
          (json['comments'] as List?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Comment {
  String? id;
  String? userId;
  String? username;
  String? text;
  DateTime? createdAt;

  Comment({this.id, this.userId, this.username, this.text, this.createdAt});

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      userId: json['userId'] ?? json['userId'],
      username: json['username'],
      text: json['text'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class StarBackgroundPainter extends CustomPainter {
  final List<Star> stars;
  StarBackgroundPainter({required this.stars, super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromARGB((0.8 * 255).toInt(), 255, 255, 255)
      ..style = PaintingStyle.fill;
    for (final star in stars) {
      _drawStar(canvas, Offset(star.x, star.y), star.radius, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    const int points = 5;
    final double angle = pi / points;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius / 2;
      final a = i * angle;
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Star {
  double x, y, radius, speed;
  Star(this.x, this.y, this.radius, this.speed);
}
