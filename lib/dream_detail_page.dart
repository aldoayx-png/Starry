import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

// Constants
const String _baseUrl = 'https://starry-1zm8.onrender.com/api/dreams';

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

  /// Builds the dream info chips section with better organization
  Widget _buildDreamInfoChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalles del Sueño',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (widget.dream.mood != null)
              _DreamInfoChip(
                icon: _getMoodIcon(widget.dream.mood!),
                label: widget.dream.mood!,
                color: _getMoodColor(widget.dream.mood!),
              ),
            if (widget.dream.date != null)
              _DreamInfoChip(
                icon: Icons.calendar_today,
                label: widget.dream.date!.toLocal().toString().split(' ')[0],
                color: Colors.deepPurple.shade700,
              ),
            if (widget.dream.people != null && widget.dream.people!.isNotEmpty)
              _DreamInfoChip(
                icon: Icons.people,
                label: widget.dream.people!,
                color: Colors.indigo.shade700,
              ),
            if (widget.dream.place != null && widget.dream.place!.isNotEmpty)
              _DreamInfoChip(
                icon: Icons.location_on,
                label: widget.dream.place!,
                color: Colors.red.shade700,
              ),
            _DreamInfoChip(
              icon: Icons.visibility,
              label: widget.dream.clarity.round().toString(),
              color: const Color(0xFF10B981),
            ),
            _DreamInfoChip(
              icon: Icons.repeat,
              label: widget.dream.isRecurring ? 'Recurrente' : 'Única',
              color: Colors.purple.shade900,
            ),
            _DreamInfoChip(
              icon: Icons.alarm,
              label: widget.dream.wokeUp ? 'Despertó' : 'Continuó',
              color: Colors.indigo.shade900,
            ),
            ...widget.dream.tags.map(
              (tag) => _DreamInfoChip(
                icon: _getTagIcon(tag),
                label: tag,
                color: _getTagColor(tag),
              ),
            ),
          ],
        ),
        if (widget.dream.notes != null && widget.dream.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.blueGrey.shade900.withValues(alpha: 0.4),
              border: Border.all(
                color: Colors.blueGrey.shade700.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note, color: Colors.blueGrey, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.dream.notes!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Builds the dream description section
  Widget _buildDreamDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción del Sueño',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [Colors.black87, Colors.black.withValues(alpha: 0.7)],
            ),
            border: Border.all(color: Colors.white10, width: 1),
          ),
          child: Text(
            widget.dream.dreamInfo!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  /// Syncs dream updates to forum post if shared
  Future<void> _syncForumPost(String? token, Dream updatedDream) async {
    if (token == null || widget.dream.id == null) {
      debugPrint(
        '⚠ No se puede sincronizar: token=${token != null}, dreamId=${widget.dream.id}',
      );
      return;
    }

    debugPrint(
      '🔄 Iniciando sincronización de Forum Post para dreamId: ${widget.dream.id}',
    );

    final postData = jsonEncode({
      'title': updatedDream.title,
      'date': updatedDream.date?.toIso8601String(),
      'mood': updatedDream.mood,
      'tags': updatedDream.tags,
      'people': updatedDream.people,
      'place': updatedDream.place,
      'clarity': updatedDream.clarity,
      'notes': updatedDream.notes,
      'isRecurring': updatedDream.isRecurring,
      'wokeUp': updatedDream.wokeUp,
      'dreamInfo': updatedDream.dreamInfo,
    });

    // Intentar endpoints en orden de preferencia
    final endpoints = [
      // Endpoint que busca el post por dreamId (recomendado)
      'https://starry-1zm8.onrender.com/api/forum/dreams/${widget.dream.id}',
      // Endpoints alternativos
      'https://starry-1zm8.onrender.com/api/forum/posts/${widget.dream.id}',
      'https://starry-1zm8.onrender.com/api/forum/${widget.dream.id}',
    ];

    bool synced = false;
    for (final endpoint in endpoints) {
      try {
        debugPrint('📤 Intentando sincronizar en: $endpoint');
        final response = await http
            .put(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: postData,
            )
            .timeout(const Duration(seconds: 5));

        debugPrint('📥 Respuesta: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('✓ Post del foro actualizado desde: $endpoint');
          debugPrint('✓ Respuesta: ${response.body}');
          synced = true;
          break;
        } else if (response.statusCode == 404) {
          debugPrint('✗ 404: Post no encontrado - Info: ${response.body}');
          continue;
        } else if (response.statusCode == 403) {
          debugPrint('✗ 403: No autorizado - ${response.body}');
          break;
        } else {
          debugPrint('✗ Error ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('✗ Excepción al sincronizar desde $endpoint: $e');
        continue;
      }
    }

    if (synced) {
      debugPrint('✅ Sincronización completada exitosamente');
    } else {
      debugPrint(
        '⚠ No se pudo sincronizar con el foro, pero el sueño fue actualizado localmente',
      );
    }
  }

  /// Handles dream editing
  Future<void> _handleEditDream() async {
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
        await _updateDreamOnBackend(editedDream);
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error inesperado al editar');
        }
      }
    }
  }

  /// Updates dream on backend and updates local state
  Future<void> _updateDreamOnBackend(Dream editedDream) async {
    try {
      final token = await TokenStorage.getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/${widget.dream.id}'),
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
        final updatedDream = Dream.fromJson(jsonDecode(response.body));
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
          widget.dream.isShared = updatedDream.isShared;
        });

        // Si el sueño es compartido, actualizar también el post del foro
        if (updatedDream.isShared && widget.dream.id != null) {
          await _syncForumPost(token, updatedDream);
        }

        if (mounted) {
          Navigator.of(context).pop({'edited': true, 'dream': widget.dream});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sueño actualizado correctamente'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        await TokenStorage.clearToken();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        }
      } else {
        _showErrorSnackBar('Error al editar en el servidor');
      }
    } catch (e) {
      _showErrorSnackBar('Error de conexión al editar');
    }
  }

  /// Handles dream deletion
  Future<void> _handleDeleteDream() async {
    final confirm = await _showDeleteConfirmDialog();
    if (confirm == true) {
      try {
        await _deleteDreamOnBackend();
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error inesperado al eliminar');
        }
      }
    }
  }

  /// Shows delete confirmation dialog
  Future<bool?> _showDeleteConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF1a1a1a)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFd32f2f), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFd32f2f).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFd32f2f).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFd32f2f),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Eliminar sueño',
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd32f2f).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFd32f2f).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    '⚠️ Esta acción es irreversible. Este sueño se eliminará permanentemente.',
                    style: TextStyle(
                      color: Color(0xFFffb3b3),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
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
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFd32f2f),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
    );
  }

  /// Deletes dream from backend
  Future<void> _deleteDreamOnBackend() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/${widget.dream.id}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop({'deleted': true, 'dream': widget.dream});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sueño eliminado correctamente'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        await TokenStorage.clearToken();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        }
      } else {
        _showErrorSnackBar('Error al eliminar el sueño');
      }
    } catch (e) {
      _showErrorSnackBar('Error de conexión al eliminar');
    }
  }

  /// Shows error snack bar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade900,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Gets the appropriate icon for a tag
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

  /// Gets the appropriate icon for a mood
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

  /// Gets the appropriate color for a mood
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

  /// Gets the appropriate color for a tag
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
            color: Colors.black.withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            onSelected: (value) {
              if (value == 'edit') {
                _handleEditDream();
              } else if (value == 'delete') {
                _handleDeleteDream();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Editar',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ],
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
          CustomPaint(
            size: size,
            painter: StarBackgroundPainter(stars: _stars, repaint: _controller),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dream Title with Icon
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.dream.title ?? 'Sin título',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Dream Info Chips
                  _buildDreamInfoChips(),
                  const SizedBox(height: 36),

                  // Dream Description
                  if (widget.dream.dreamInfo != null &&
                      widget.dream.dreamInfo!.isNotEmpty)
                    _buildDreamDescription(),
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

/// Custom widget for dream info chips
class _DreamInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DreamInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
