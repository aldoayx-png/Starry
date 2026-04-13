import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class DreamDetailPage extends StatefulWidget {
  final Dream dream;
  const DreamDetailPage({super.key, required this.dream});

  @override
  State<DreamDetailPage> createState() => _DreamDetailPageState();
}

class _DreamDetailPageState extends State<DreamDetailPage>
    with TickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _lastSize = size;
    if (_stars.isEmpty) {
      _initStars(size);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: SizedBox(
          height: 100,
          width: 100,
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
            height: 100,
            width: 100,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.black.withValues(alpha: 0.7),
            onSelected: (value) async {
              if (value == 'edit') {
                final editedDream = await showDialog<Dream>(
                  context: context,
                  builder: (context) => DreamFormDialog(
                    initialDream: widget.dream,
                    onSave: (dream) {
                      Navigator.of(context).pop(dream);
                    },
                  ),
                );
                if (editedDream != null) {
                  try {
                    final token = await TokenStorage.getToken();
                    final response = await http.put(
                      Uri.parse(
                        'http://localhost:3000/api/dreams/${widget.dream.id}',
                      ),
                      headers: {
                        'Content-Type': 'application/json',
                        if (token != null) 'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode({
                        'title': editedDream.title,
                        'date': editedDream.date?.toIso8601String(),
                        'mood': editedDream.mood,
                        'tags': editedDream.tags,
                        'people': editedDream.people,
                        'place': editedDream.place,
                        'clarity': editedDream.clarity,
                        'notes': editedDream.notes,
                        'isRecurring': editedDream.isRecurring,
                        'wokeUp': editedDream.wokeUp,
                        'dreamInfo': editedDream.dreamInfo,
                      }),
                    );
                    if (response.statusCode == 200) {
                      final updatedDream = Dream.fromJson(
                        jsonDecode(response.body),
                      );
                      setState(() {
                        widget.dream.title = updatedDream.title;
                        widget.dream.date = updatedDream.date;
                        widget.dream.mood = updatedDream.mood;
                        widget.dream.tags = updatedDream.tags;
                        widget.dream.people = updatedDream.people;
                        widget.dream.place = updatedDream.place;
                        widget.dream.clarity = updatedDream.clarity;
                        widget.dream.notes = updatedDream.notes;
                        widget.dream.isRecurring = updatedDream.isRecurring;
                        widget.dream.wokeUp = updatedDream.wokeUp;
                        widget.dream.dreamInfo = updatedDream.dreamInfo;
                      });
                      // Devuelve el sueño editado a la pantalla anterior para actualizar la lista
                      Navigator.of(
                        context,
                      ).pop({'edited': true, 'dream': widget.dream});
                      // Si quieres mostrar el SnackBar, hazlo en la pantalla anterior después de actualizar la lista
                    } else if (response.statusCode == 401) {
                      // Token inválido o expirado
                      await TokenStorage.clearToken();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (Route<dynamic> route) => false,
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al editar en el backend'),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error de red al editar')),
                    );
                  }
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar sueño'),
                    content: const Text(
                      '¿Estás seguro de que deseas eliminar este sueño?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  // Llamada DELETE al backend usando el id
                  try {
                    final token = await TokenStorage.getToken();
                    final response = await http.delete(
                      Uri.parse(
                        'http://localhost:3000/api/dreams/${widget.dream.id}',
                      ),
                      headers: {
                        'Content-Type': 'application/json',
                        if (token != null) 'Authorization': 'Bearer $token',
                      },
                    );
                    if (response.statusCode == 200) {
                      Navigator.of(
                        context,
                      ).pop({'deleted': true, 'dream': widget.dream});
                    } else if (response.statusCode == 401) {
                      // Token inválido o expirado
                      await TokenStorage.clearToken();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (Route<dynamic> route) => false,
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al eliminar en el backend'),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error de red al eliminar')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit, color: Colors.white70),
                  title: Text('Editar', style: TextStyle(color: Colors.white)),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.redAccent),
                  title: Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(
                      77,
                      (Colors.deepPurple.shade900.r * 255.0).round().clamp(
                        0,
                        255,
                      ),
                      (Colors.deepPurple.shade900.g * 255.0).round().clamp(
                        0,
                        255,
                      ),
                      (Colors.deepPurple.shade900.b * 255.0).round().clamp(
                        0,
                        255,
                      ),
                    ),
                    Color.fromARGB(
                      77,
                      (Colors.blue.shade900.r * 255.0).round().clamp(0, 255),
                      (Colors.blue.shade900.g * 255.0).round().clamp(0, 255),
                      (Colors.blue.shade900.b * 255.0).round().clamp(0, 255),
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
              ),
            ),
          ),
          CustomPaint(
            size: size,
            painter: StarBackgroundPainter(stars: _stars, repaint: _controller),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
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
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.dream.title ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      if (widget.dream.mood != null)
                        Chip(
                          label: Text('Ánimo: ${widget.dream.mood}'),
                          backgroundColor: Colors.blue.shade700,
                          labelStyle: const TextStyle(color: Colors.white),
                          avatar: const Icon(
                            Icons.emoji_emotions,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      if (widget.dream.date != null)
                        Chip(
                          label: Text(
                            'Fecha: ${widget.dream.date!.toLocal().toString().split(' ')[0]}',
                          ),
                          backgroundColor: Colors.deepPurple.shade700,
                          labelStyle: const TextStyle(color: Colors.white),
                          avatar: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      if (widget.dream.tags.isNotEmpty)
                        ...widget.dream.tags.map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.purple.shade700,
                            labelStyle: const TextStyle(color: Colors.white),
                            avatar: const Icon(
                              Icons.label,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      if (widget.dream.people != null &&
                          widget.dream.people!.isNotEmpty)
                        Chip(
                          label: Text('Personas: ${widget.dream.people}'),
                          backgroundColor: Colors.indigo.shade700,
                          labelStyle: const TextStyle(color: Colors.white),
                          avatar: const Icon(
                            Icons.people,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      if (widget.dream.place != null &&
                          widget.dream.place!.isNotEmpty)
                        Chip(
                          label: Text('Lugar: ${widget.dream.place}'),
                          backgroundColor: Colors.black87,
                          labelStyle: const TextStyle(color: Colors.white),
                          avatar: const Icon(
                            Icons.place,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      Chip(
                        label: Text('Claridad: ${widget.dream.clarity}'),
                        backgroundColor: Colors.deepPurple.shade900,
                        labelStyle: const TextStyle(color: Colors.white),
                        avatar: const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      if (widget.dream.notes != null &&
                          widget.dream.notes!.isNotEmpty)
                        Chip(
                          label: Text('Notas: ${widget.dream.notes}'),
                          backgroundColor: Colors.blueGrey.shade700,
                          labelStyle: const TextStyle(color: Colors.white),
                          avatar: const Icon(
                            Icons.note,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      Chip(
                        label: Text(
                          '¿Recurrente?: ${widget.dream.isRecurring ? "Sí" : "No"}',
                        ),
                        backgroundColor: Colors.purple.shade900,
                        labelStyle: const TextStyle(color: Colors.white),
                        avatar: const Icon(
                          Icons.repeat,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Chip(
                        label: Text(
                          '¿Despertó?: ${widget.dream.wokeUp ? "Sí" : "No"}',
                        ),
                        backgroundColor: Colors.indigo.shade900,
                        labelStyle: const TextStyle(color: Colors.white),
                        avatar: const Icon(
                          Icons.alarm,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (widget.dream.dreamInfo != null &&
                      widget.dream.dreamInfo!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sueño',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.dream.dreamInfo!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
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
              currentIndex: 0,
              onTap: (index) {
                switch (index) {
                  case 0:
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                    break;
                  case 1:
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/calendar',
                      (route) => false,
                    );
                    break;
                  case 2:
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/forum',
                      (route) => false,
                    );
                    break;
                  case 3:
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/users',
                      (route) => false,
                    );
                    break;
                  case 4:
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/settings',
                      (route) => false,
                    );
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
}
