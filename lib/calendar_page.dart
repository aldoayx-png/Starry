import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'token_storage.dart';
import 'dream_detail_page.dart';
import 'forum_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with TickerProviderStateMixin {
  late DateTime _currentDate;
  List<Dream> _allDreams = [];
  DateTime? _selectedDate;
  int _currentIndex = 1;
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
    _currentDate = DateTime.now();
    _selectedDate = DateTime(
      _currentDate.year,
      _currentDate.month,
      _currentDate.day,
    );
    _fetchDreams();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        setState(() {
          _allDreams = data.map((e) => Dream.fromJson(e)).toList();
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
    } catch (e) {
      // Error al obtener sueños
    }
  }

  List<Dream> _getDreamsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _allDreams.where((dream) {
      if (dream.date == null) return false;
      final dreamDateOnly = DateTime(
        dream.date!.year,
        dream.date!.month,
        dream.date!.day,
      );
      return dreamDateOnly == dateOnly;
    }).toList();
  }

  bool _hasDreamsOnDate(DateTime date) {
    return _getDreamsForDate(date).isNotEmpty;
  }

  List<DateTime> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final daysInMonth = lastDay.day;
    final dayOfWeek = firstDay.weekday;

    List<DateTime> days = [];
    // Días vacíos al inicio
    for (int i = 1; i < dayOfWeek; i++) {
      days.add(DateTime(date.year, date.month, 1 - (dayOfWeek - i)));
    }
    // Días del mes
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(date.year, date.month, i));
    }
    // Días vacíos al final
    final remainingDays = 42 - days.length;
    for (int i = 1; i <= remainingDays; i++) {
      days.add(DateTime(date.year, date.month + 1, i));
    }
    return days;
  }

  void _previousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_currentDate);
    final monthName = _getMonthName(_currentDate.month);
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
          SingleChildScrollView(
            child: Column(
              children: [
                // Encabezado del calendario con fondo degradado
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Calendario',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withAlpha(30),
                            border: Border.all(
                              color: Colors.white.withAlpha(100),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: _previousMonth,
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      monthName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentDate.year.toString(),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: _nextMonth,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Grid del calendario (centrado y con ancho máximo)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.black.withValues(alpha: 0.1),
                              border: Border.all(
                                color: Colors.deepPurpleAccent.withAlpha(40),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Encabezados de días de la semana
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children:
                                      [
                                            'Dom',
                                            'Lun',
                                            'Mar',
                                            'Mié',
                                            'Jue',
                                            'Vie',
                                            'Sáb',
                                          ]
                                          .map(
                                            (day) => Text(
                                              day,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                                const SizedBox(height: 12),
                                // Grid de días
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        childAspectRatio: 1.2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                      ),
                                  itemCount: daysInMonth.length,
                                  itemBuilder: (context, index) {
                                    final day = daysInMonth[index];
                                    final isCurrentMonth =
                                        day.month == _currentDate.month;
                                    final isSelected =
                                        _selectedDate != null &&
                                        day.year == _selectedDate!.year &&
                                        day.month == _selectedDate!.month &&
                                        day.day == _selectedDate!.day;
                                    final hasDreams = _hasDreamsOnDate(day);

                                    return GestureDetector(
                                      onTap: isCurrentMonth
                                          ? () {
                                              setState(() {
                                                _selectedDate = DateTime(
                                                  day.year,
                                                  day.month,
                                                  day.day,
                                                );
                                              });
                                            }
                                          : null,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: isSelected
                                              ? Colors.deepPurple.shade700
                                              : isCurrentMonth
                                              ? Colors.white.withAlpha(5)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: !isCurrentMonth
                                                ? Colors.transparent
                                                : isSelected
                                                ? Colors.deepPurpleAccent
                                                : hasDreams
                                                ? Colors.deepPurpleAccent
                                                      .withAlpha(80)
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Center(
                                              child: Text(
                                                day.day.toString(),
                                                style: TextStyle(
                                                  color: !isCurrentMonth
                                                      ? Colors.white30
                                                      : isSelected
                                                      ? Colors.white
                                                      : Colors.white,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (hasDreams && !isSelected)
                                              Positioned(
                                                bottom: 2,
                                                child: Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Color(
                                                          0xFF8e2de2,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Sueños del día seleccionado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _selectedDate != null
                      ? _buildDreamsForSelectedDate()
                      : Container(),
                ),
                const SizedBox(height: 20),
              ],
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
                if (index == 0) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (Route<dynamic> route) => false,
                  );
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
                        setState(() {
                          _currentIndex = 1;
                        });
                      });
                } else if (index == 3) {
                  Navigator.of(context).pushNamed('/users');
                } else if (index == 4) {
                  Navigator.of(context).pushNamed('/settings');
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

  Widget _buildDreamsForSelectedDate() {
    final dreams = _getDreamsForDate(_selectedDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 16),
          child: Text(
            'Sueños del ${_selectedDate!.day} de ${_getMonthName(_selectedDate!.month)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (dreams.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No hay sueños registrados',
                style: TextStyle(
                  color: Colors.white.withAlpha(128),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          Column(
            children: dreams.map((dream) {
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
                        _allDreams.removeWhere((d) => d.id == dream.id);
                      });
                    } else if (result['edited'] == true &&
                        result['dream'] != null) {
                      setState(() {
                        final idx = _allDreams.indexWhere(
                          (d) => d.id == dream.id,
                        );
                        if (idx != -1) {
                          _allDreams[idx] = result['dream'];
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
                            (Colors.blue.shade900.r * 255.0).round().clamp(
                              0,
                              255,
                            ),
                            (Colors.blue.shade900.g * 255.0).round().clamp(
                              0,
                              255,
                            ),
                            (Colors.blue.shade900.b * 255.0).round().clamp(
                              0,
                              255,
                            ),
                          ),
                          Color.fromARGB(
                            26,
                            (Colors.black.r * 255.0).round().clamp(0, 255),
                            (Colors.black.g * 255.0).round().clamp(0, 255),
                            (Colors.black.b * 255.0).round().clamp(0, 255),
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withAlpha(30),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
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
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.deepPurpleAccent,
                                    Colors.blueAccent,
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.nightlight_round,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Text(
                                dream.title ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
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
                                backgroundColor: Colors.deepPurple.shade700,
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
            }).toList(),
          ),
      ],
    );
  }

  String _getMonthName(int month) {
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
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
