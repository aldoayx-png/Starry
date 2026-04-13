import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'token_storage.dart';
import 'calendar_page.dart';
import 'forum_page.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  String? username;
  DateTime? createdAt;
  int totalDreams = 0;
  int streakDays = 0;
  Map<String, int> tagCounts = {};
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> weeklyMood = [];
  double recurringPercentage = 0.0;
  double wokeUpPercentage = 0.0;
  double averageClarity = 0.0;
  late AnimationController _controller;
  late List<Star> _stars;
  Size _lastSize = Size.zero;

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
    });
    _fetchProfile();
    _fetchWeeklyMood();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    final token = await TokenStorage.getToken();
    try {
      final response = await http.get(
        Uri.parse('https://starry-1zm8.onrender.com/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Obtener estadísticas
        final statsResponse = await http.get(
          Uri.parse('https://starry-1zm8.onrender.com/api/profile/stats'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

        if (statsResponse.statusCode == 200) {
          final statsData = jsonDecode(statsResponse.body);
          setState(() {
            username = data['username'];
            createdAt = data['createdAt'] != null
                ? DateTime.parse(data['createdAt'] as String)
                : null;
            totalDreams = statsData['totalDreams'] ?? 0;
            streakDays = statsData['streakDays'] ?? 0;
            tagCounts = Map<String, int>.from(statsData['tagCounts'] ?? {});
            recurringPercentage = (statsData['recurringPercentage'] ?? 0)
                .toDouble();
            wokeUpPercentage = (statsData['wokeUpPercentage'] ?? 0).toDouble();
            averageClarity = (statsData['averageClarity'] ?? 0).toDouble();
            isLoading = false;
          });
        } else if (statsResponse.statusCode == 401) {
          // Token inválido o expirado
          await TokenStorage.clearToken();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (Route<dynamic> route) => false,
            );
          }
        } else {
          setState(() {
            error = 'No se pudo cargar las estadísticas';
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        // Token inválido o expirado
        await TokenStorage.clearToken();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        }
      } else {
        setState(() {
          error = 'No se pudo cargar el perfil';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error de red';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchWeeklyMood() async {
    final token = await TokenStorage.getToken();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    try {
      final response = await http.get(
        Uri.parse('https://starry-1zm8.onrender.com/api/dreams'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> moods = List.generate(7, (i) {
          final day = startOfWeek.add(Duration(days: i));
          final dreams = data.where((d) {
            final date = d['date'] != null
                ? DateTime.tryParse(d['date'])
                : null;
            return date != null &&
                date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          }).toList();
          String? mood;
          if (dreams.isNotEmpty) {
            mood = dreams.last['mood'];
          }
          return {'day': day, 'mood': mood};
        });
        setState(() {
          weeklyMood = moods;
        });
      } else if (response.statusCode == 401) {
        // Token inválido o expirado
        await TokenStorage.clearToken();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        }
      }
    } catch (_) {}
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchProfile();
    _fetchWeeklyMood();
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
      body: Stack(
        children: [
          CustomPaint(
            size: size,
            painter: StarBackgroundPainter(stars: _stars, repaint: _controller),
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 60, bottom: 32),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                          gradient: LinearGradient(
                            colors: [Color(0xFF2193b0), Color(0xFF8e2de2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Mi Perfil',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.deepPurpleAccent,
                                    Colors.blueAccent,
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              username ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              createdAt != null
                                  ? 'Se unió en: ${createdAt!.day}/${createdAt!.month}/${createdAt!.year}'
                                  : '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estadísticas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Sueños totales',
                                    totalDreams.toString(),
                                    Icons.nightlight_round,
                                    const Color(0xFF2193b0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Racha de días',
                                    streakDays.toString(),
                                    Icons.local_fire_department,
                                    const Color(0xFF8e2de2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Sueños recurrentes',
                                    '${recurringPercentage.toStringAsFixed(1)}%',
                                    Icons.repeat,
                                    const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Despertares',
                                    '${wokeUpPercentage.toStringAsFixed(1)}%',
                                    Icons.bedtime,
                                    const Color(0xFF8B5CF6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Claridad promedio',
                                    '${averageClarity.toStringAsFixed(1)}/10',
                                    Icons.brightness_4,
                                    const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Sueños por etiqueta',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (tagCounts.isEmpty)
                              const Text(
                                'Sin etiquetas registradas',
                                style: TextStyle(color: Colors.white54),
                              )
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: tagCounts.entries.map((entry) {
                                  return _buildTagCard(entry.key, entry.value);
                                }).toList(),
                              ),
                            const SizedBox(height: 24),
                            const Text(
                              'Estado de ánimo semanal',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildWeeklyMood(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
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
              onTap: (index) {
                switch (index) {
                  case 0:
                    Navigator.of(context).pushAndRemoveUntil(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const DreamJournalHome(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final fade = Tween<double>(
                                begin: 0.0,
                                end: 1.0,
                              ).animate(animation);
                              final scale = Tween<double>(begin: 1.5, end: 1.0)
                                  .animate(
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
                      (route) => false,
                    );
                    break;
                  case 1:
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const CalendarPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final fade = Tween<double>(
                                begin: 0.0,
                                end: 1.0,
                              ).animate(animation);
                              final scale = Tween<double>(begin: 1.5, end: 1.0)
                                  .animate(
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
                    );
                    break;
                  case 2:
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ForumPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final fade = Tween<double>(
                                begin: 0.0,
                                end: 1.0,
                              ).animate(animation);
                              final scale = Tween<double>(begin: 1.5, end: 1.0)
                                  .animate(
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
                    );
                    break;
                  case 3:
                    Navigator.of(context).pushNamed('/users');
                    break;
                  case 4:
                    Navigator.of(context).pushNamed('/settings');
                    break;
                }
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white10,
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(String tag, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2193b0).withValues(alpha: 0.2),
            const Color(0xFF8e2de2).withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF2193b0).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            tag,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.87),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyMood() {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final moodIcons = {
      'Feliz': Icons.emoji_emotions,
      'Triste': Icons.sentiment_dissatisfied,
      'Ansioso': Icons.sentiment_neutral,
      'Asustado': Icons.sentiment_very_dissatisfied,
      'Neutral': Icons.sentiment_satisfied,
    };
    final moodColors = {
      'Feliz': Colors.greenAccent,
      'Triste': Colors.blueAccent,
      'Ansioso': Colors.orangeAccent,
      'Asustado': Colors.redAccent,
      'Neutral': Colors.grey,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final mood = weeklyMood.length > i ? weeklyMood[i]['mood'] : null;
        final icon = moodIcons[mood] ?? Icons.help_outline;
        final color = moodColors[mood] ?? Colors.white24;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  days[i],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(icon, color: color, size: 28),
              ],
            ),
          ),
        );
      }),
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
