import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'calendar_page.dart';
import 'token_storage.dart';
import 'main.dart';
import 'forum_dream_detail_page.dart';
import 'dream_notifier.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;
  Size _lastSize = Size.zero;
  List<dynamic> _forumPosts = [];
  List<dynamic> _filteredPosts = [];
  bool _isLoading = false;
  String? _currentUserId;
  String _currentFilter = 'todas'; // todas, misSueños, likes, comentarios
  final Map<String, bool> _likedPosts = {};
  final Map<String, int> _likeCount = {};
  final Set<String> _processingLikes = {};
  bool _isRefreshingPosts = false;
  bool _didInitialize = false; // Flag para evitar refresh múltiple en initState

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
    // Escuchar cambios en sueños para refrescar el foro
    dreamChangeNotifier.addListener(_onDreamChanged);
    _initializeData();
    _didInitialize = true;
  }

  void _onDreamChanged() {
    debugPrint(
      '🔔 ForumPage: Notificación de cambio en sueños - Refrescando posts',
    );
    _fetchForumPosts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Solo refrescar si ya hemos inicializado (para evitar refresh doble en startup)
    if (_didInitialize && !_isRefreshingPosts) {
      debugPrint(
        '🔄 didChangeDependencies: Foro - Refrescando posts desde retorno...',
      );
      // Limpiar caché local para asegurar datos frescos
      _likedPosts.clear();
      _likeCount.clear();
      _fetchForumPosts();
    }
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _fetchForumPosts();
  }

  Future<void> _loadUserData() async {
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
          _currentUserId = data['_id'] ?? data['id'];
        });
      }
    } catch (e) {
      // Error al obtener usuario
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

  Future<void> _fetchForumPosts() async {
    setState(() {
      _isLoading = true;
      _isRefreshingPosts = true;
    });
    try {
      final token = await TokenStorage.getToken();
      final response = await http.get(
        Uri.parse('https://starry-1zm8.onrender.com/api/forum/posts'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _forumPosts = data;
          _applyFilter(_currentFilter);
          // Inicializar conteo de likes desde el servidor
          for (var post in data) {
            final postId = post['_id'] ?? 'unknown';
            _likeCount[postId] = post['likes'] ?? 0;
            // Usar userHasLiked del servidor
            _likedPosts[postId] = post['userHasLiked'] ?? false;
          }
          _isLoading = false;
          _isRefreshingPosts = false;
          debugPrint('🔄 Foro: Posts refrescados exitosamente');
        });
      } else {
        setState(() {
          _isLoading = false;
          _isRefreshingPosts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshingPosts = false;
      });
    }
  }

  Future<void> _toggleLike(String postId, bool isLiked) async {
    // Prevenir múltiples clicks
    if (_processingLikes.contains(postId)) return;

    setState(() {
      _processingLikes.add(postId);
    });

    try {
      final token = await TokenStorage.getToken();
      final endpoint = isLiked ? 'unlike' : 'like';
      final response = await http.post(
        Uri.parse(
          'https://starry-1zm8.onrender.com/api/forum/posts/$postId/$endpoint',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final updatedPost = jsonDecode(response.body);
        setState(() {
          _likeCount[postId] = updatedPost['likes'] ?? 0;
          // No reviertas el estado local, solo sincroniza el contador
        });
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error'] ?? '';

        // Si el error es "Ya likeaste", significa que SÍ está likeado
        if (errorMessage.contains('Ya likeaste')) {
          setState(() {
            _likedPosts[postId] = true;
          });
        } else if (errorMessage.contains('No has likeado')) {
          setState(() {
            _likedPosts[postId] = false;
          });
        } else {
          // Para otros errores, revertir cambio
          setState(() {
            _likedPosts[postId] = !(_likedPosts[postId] ?? false);
          });
        }
      }
    } catch (e) {
      // Revertir cambio si hay error
      setState(() {
        _likedPosts[postId] = !(_likedPosts[postId] ?? false);
      });
    } finally {
      setState(() {
        _processingLikes.remove(postId);
      });
    }
  }

  void _applyFilter(String filterType) {
    setState(() {
      _currentFilter = filterType;
      if (filterType == 'todas') {
        _filteredPosts = List.from(_forumPosts);
      } else if (filterType == 'misSueños') {
        _filteredPosts = _forumPosts
            .where(
              (post) =>
                  post['userId']?['_id'] == _currentUserId ||
                  post['userId'] == _currentUserId,
            )
            .toList();
      } else if (filterType == 'likes') {
        _filteredPosts = List.from(_forumPosts);
        _filteredPosts.sort(
          (a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0),
        );
      } else if (filterType == 'comentarios') {
        _filteredPosts = List.from(_forumPosts);
        _filteredPosts.sort(
          (a, b) => ((b['comments'] as List?)?.length ?? 0).compareTo(
            ((a['comments'] as List?)?.length ?? 0),
          ),
        );
      }
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
            left: BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
            right: BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filtrar Sueños',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildFilterOption('Todas', Icons.forum, 'todas'),
                  const SizedBox(height: 12),
                  _buildFilterOption('Tus Sueños', Icons.favorite, 'misSueños'),
                  const SizedBox(height: 12),
                  _buildFilterOption('Más Likes', Icons.star, 'likes'),
                  const SizedBox(height: 12),
                  _buildFilterOption(
                    'Más Comentarios',
                    Icons.comment,
                    'comentarios',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, IconData icon, String filterType) {
    final isActive = _currentFilter == filterType;
    return GestureDetector(
      onTap: () {
        _applyFilter(filterType);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF8e2de2), Color(0xFF2193b0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
          border: Border.all(
            color: isActive
                ? Colors.deepPurpleAccent
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (filterType == 'likes')
              SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(painter: CrescentMoonPainter(isLiked: true)),
              )
            else
              Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDreamCard({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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

  @override
  void dispose() {
    _controller.dispose();
    dreamChangeNotifier.removeListener(_onDreamChanged);
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
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8e2de2), Color(0xFF2193b0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.forum,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Foro de Sueños',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Comparte y descubre experiencias oníificas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8e2de2),
                      ),
                    ),
                  )
                else if (_filteredPosts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                          'Aún no hay sueños compartidos en el foro.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      top: 8,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    itemCount: _filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = _filteredPosts[index];
                      return GestureDetector(
                        onTap: () async {
                          final dream = Dream.fromJson(post);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ForumDreamDetailPage(dream: dream),
                            ),
                          );
                          // didChangeDependencies se encargará de refrescar automáticamente
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
                            padding: const EdgeInsets.only(
                              top: 24,
                              left: 24,
                              right: 24,
                              bottom: 12,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final userId = post['userId'] is Map
                                            ? (post['userId'] as Map)['_id']
                                            : post['userId'];
                                        final username = post['userId'] is Map
                                            ? (post['userId']
                                                  as Map)['username']
                                            : 'Usuario';
                                        Navigator.pushNamed(
                                          context,
                                          '/user_profile',
                                          arguments: {
                                            'userId': userId,
                                            'username': username,
                                          },
                                        );
                                      },
                                      child: Container(
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
                                          Icons.star,
                                          color: Colors.white,
                                          size: 22,
                                        ),
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
                                            post['userId']?['username'] ??
                                                'Anónimo',
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
                                            post['title'] ?? 'Sin título',
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
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Centro: Ánimo y Fecha
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        if (post['mood'] != null)
                                          _buildDreamCard(
                                            icon: Icons.emoji_emotions,
                                            label: post['mood'] ?? '',
                                            color: _getMoodColor(
                                              post['mood'] ?? '',
                                            ),
                                          ),
                                        if (post['date'] != null)
                                          _buildDreamCard(
                                            icon: Icons.calendar_today,
                                            label: () {
                                              final raw =
                                                  post['date'].toString().trim();
                                              // Treat as date-only to avoid timezone shifting (off-by-one day).
                                              final ymd = raw.length >= 10
                                                  ? raw.substring(0, 10)
                                                  : raw;
                                              final parsed =
                                                  DateTime.tryParse(ymd) ??
                                                  DateTime.tryParse(raw);
                                              final d = parsed == null
                                                  ? null
                                                  : DateTime(
                                                      parsed.year,
                                                      parsed.month,
                                                      parsed.day,
                                                    );
                                              if (d == null) return '';
                                              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
                                            }(),
                                            color: Colors.purpleAccent,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Abajo: Likes y Comentarios
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap:
                                              _processingLikes.contains(
                                                post['_id'],
                                              )
                                              ? null
                                              : () {
                                                  final postId =
                                                      post['_id'] ?? 'unknown';
                                                  final isCurrentlyLiked =
                                                      _likedPosts[postId] ??
                                                      false;
                                                  setState(() {
                                                    _likedPosts[postId] =
                                                        !(_likedPosts[postId] ??
                                                            false);
                                                  });
                                                  _toggleLike(
                                                    postId,
                                                    isCurrentlyLiked,
                                                  );
                                                },
                                          child: Opacity(
                                            opacity:
                                                _processingLikes.contains(
                                                  post['_id'],
                                                )
                                                ? 0.5
                                                : 1.0,
                                            child: _buildDreamCard(
                                              icon: Icons.nightlight_round,
                                              label:
                                                  '${_likeCount[post['_id'] ?? 'unknown'] ?? 0}',
                                              color:
                                                  (_likeCount[post['_id'] ??
                                                              'unknown'] ??
                                                          0) >
                                                      0
                                                  ? Colors.deepPurpleAccent
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        _buildDreamCard(
                                          icon: Icons.comment_outlined,
                                          label:
                                              '${(post['comments'] as List?)?.length ?? 0}',
                                          color: Colors.cyanAccent,
                                        ),
                                      ],
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
                const SizedBox(height: 32),
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
              currentIndex: 2,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (Route<dynamic> route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).push(
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withAlpha(40),
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
            _showFilterOptions();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.search, size: 28, color: Colors.white),
          shape: const CircleBorder(),
        ),
      ),
    );
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
}

class Star {
  double x, y, radius, speed;
  Star(this.x, this.y, this.radius, this.speed);
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

class CrescentMoonPainter extends CustomPainter {
  final bool isLiked;

  CrescentMoonPainter({required this.isLiked});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    if (isLiked) {
      // Media luna llena de blanco
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // Dibuja la media luna usando dos círculos
      final largeCircle = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));

      final smallCircle = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(center.dx + radius * 0.4, center.dy),
            radius: radius * 0.85,
          ),
        );

      canvas.drawPath(
        Path.combine(PathOperation.difference, largeCircle, smallCircle),
        paint,
      );
    } else {
      // Media luna con solo bordes blancos (outline)
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // Dibuja la media luna usando dos círculos con outline
      final largeCircle = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));

      final smallCircle = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(center.dx + radius * 0.4, center.dy),
            radius: radius * 0.85,
          ),
        );

      canvas.drawPath(
        Path.combine(PathOperation.difference, largeCircle, smallCircle),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
