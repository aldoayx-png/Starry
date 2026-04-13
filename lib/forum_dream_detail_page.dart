import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'token_storage.dart';
import 'user_profile_page.dart';

class ForumDreamDetailPage extends StatefulWidget {
  final Dream dream;
  const ForumDreamDetailPage({super.key, required this.dream});

  @override
  State<ForumDreamDetailPage> createState() => _ForumDreamDetailPageState();
}

class _ForumDreamDetailPageState extends State<ForumDreamDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;
  Size _lastSize = Size.zero;
  final TextEditingController _commentController = TextEditingController();
  late List<Comment> _comments;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _stars = [];
    _comments = [...widget.dream.comments];
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

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe un comentario')));
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final token = await TokenStorage.getToken();
      final response = await http.post(
        Uri.parse(
          'http://localhost:3000/api/forum/posts/${widget.dream.id}/comment',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': _commentController.text.trim()}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final updatedComments =
            (json['comments'] as List?)
                ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        setState(() {
          _comments = updatedComments;
          _commentController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Comentario agregado')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al agregar comentario')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  Future<void> _editComment(Comment comment) async {
    final editController = TextEditingController(text: comment.text);

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Editar comentario',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: editController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Edita tu comentario...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.purple.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.purple.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.purple, width: 2),
            ),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, editController.text),
            child: const Text(
              'Guardar',
              style: TextStyle(color: Colors.purple),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final token = await TokenStorage.getToken();
        final response = await http.put(
          Uri.parse(
            'http://localhost:3000/api/forum/posts/${widget.dream.id}/comments/${comment.id}',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'text': result.trim()}),
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final updatedComments =
              (json['comments'] as List?)
                  ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          setState(() {
            _comments = updatedComments;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comentario actualizado')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al editar comentario')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          '¿Eliminar comentario?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final token = await TokenStorage.getToken();
        final response = await http.delete(
          Uri.parse(
            'http://localhost:3000/api/forum/posts/${widget.dream.id}/comments/${comment.id}',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final updatedComments =
              (json['comments'] as List?)
                  ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          setState(() {
            _comments = updatedComments;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comentario eliminado')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al eliminar comentario')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
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
          Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
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
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
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
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
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
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
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
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
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
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
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
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
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
                        const SizedBox(height: 32),
                        // Comentarios
                        if (_comments.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comentarios (${_comments.length})',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._comments.map((comment) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (comment.userId != null &&
                                              comment.username != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    UserProfilePage(
                                                      userId: comment.userId!,
                                                      username:
                                                          comment.username!,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.deepPurpleAccent,
                                                    Colors.blueAccent,
                                                  ],
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.star,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    comment.username ??
                                                        'Anónimo',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    comment.text ?? '',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 14,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  if (comment.createdAt != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8,
                                                          ),
                                                      child: Text(
                                                        _formatDate(
                                                          comment.createdAt!,
                                                        ),
                                                        style: const TextStyle(
                                                          color: Colors.white38,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.white70,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  _editComment(comment);
                                                },
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  _deleteComment(comment);
                                                },
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          )
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'Sin comentarios aún. ¡Sé el primero en comentar!',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              // Formulario compacto estilo Facebook
              Container(
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Escribe un comentario...',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: Colors.purple.withValues(alpha: 0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: Colors.purple.withValues(alpha: 0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.purple,
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurpleAccent,
                                  Colors.blueAccent,
                                ],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isSubmittingComment
                                    ? null
                                    : _submitComment,
                                customBorder: const CircleBorder(),
                                child: _isSubmittingComment
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
              currentIndex: 2,
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
                    Navigator.pop(context);
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} d';
    } else {
      return date.toLocal().toString().split(' ')[0];
    }
  }
}
