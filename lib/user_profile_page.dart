import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart' as main_module show Star, StarBackgroundPainter, Dream;
import 'forum_dream_detail_page.dart';
import 'token_storage.dart';
import 'forum_page.dart' as forum;
import 'calendar_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<main_module.Star> _stars;
  Size _lastSize = Size.zero;
  List<dynamic> _userDreams = [];
  bool _isLoading = false;
  DateTime? _userCreatedAt;
  Map<String, bool> _likedPosts = {};
  Map<String, int> _likeCount = {};
  Set<String> _processingLikes = {};

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
    _fetchUserDreams();
    _fetchUserEmail();
  }

  void _initStars(Size size) {
    final random = Random();
    _stars = List.generate(80, (index) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2.5 + 1.0;
      final speed = random.nextDouble() * 0.8 + 0.2;
      return main_module.Star(x, y, radius, speed);
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

  Future<void> _fetchUserDreams() async {
    final token = await TokenStorage.getToken();
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/forum/posts'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> allPosts = jsonDecode(response.body);
        final userPosts = allPosts
            .where(
              (post) => post['userId'] is Map
                  ? (post['userId'] as Map)['_id'] == widget.userId
                  : post['userId'] == widget.userId,
            )
            .toList();

        setState(() {
          _userDreams = userPosts;
          _likedPosts = {};
          _likeCount = {};
          _processingLikes = {};
          // Inicializar los conteos de likes desde el servidor
          for (var post in userPosts) {
            final postId = post['_id'] ?? 'unknown';
            _likeCount[postId] = post['likes'] ?? 0;
            // Usar userHasLiked del servidor
            _likedPosts[postId] = post['userHasLiked'] ?? false;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserEmail() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/users/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        setState(() {
          _userCreatedAt = user['createdAt'] != null
              ? DateTime.parse(user['createdAt'] as String)
              : null;
        });
      } else {
        // Error: no hacer nada
      }
    } catch (e) {
      // Ignorar error
    }
  }

  Future<void> _toggleLike(String postId, bool isCurrentlyLiked) async {
    final token = await TokenStorage.getToken();
    try {
      final endpoint = isCurrentlyLiked
          ? '/api/forum/posts/$postId/unlike'
          : '/api/forum/posts/$postId/like';

      final response = await http.post(
        Uri.parse('http://localhost:3000$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _likeCount[postId] = data['likes'] ?? 0;
          _processingLikes.remove(postId);
        });
      } else {
        setState(() {
          _processingLikes.remove(postId);
        });
      }
    } catch (e) {
      setState(() {
        _processingLikes.remove(postId);
      });
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
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
              painter: main_module.StarBackgroundPainter(
                stars: _stars,
                repaint: _controller,
              ),
            ),
            SingleChildScrollView(
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
                          'Perfil de usuario',
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
                          widget.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userCreatedAt != null
                              ? 'Se unió en: ${_userCreatedAt!.day}/${_userCreatedAt!.month}/${_userCreatedAt!.year}'
                              : '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 24,
                      left: 24,
                      right: 24,
                      bottom: 16,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sueños compartidos (${_userDreams.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF8e2de2),
                        ),
                      ),
                    )
                  else if (_userDreams.isEmpty)
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
                            'Este usuario aún no ha compartido sueños.',
                            style: TextStyle(
                              fontSize: 14,
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
                        top: 32,
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      itemCount: _userDreams.length,
                      itemBuilder: (context, index) {
                        final post = _userDreams[index];
                        return GestureDetector(
                          onTap: () {
                            final dream = main_module.Dream.fromJson(post);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ForumDreamDetailPage(dream: dream),
                              ),
                            );
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
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (post['mood'] != null)
                                        Chip(
                                          label: Text(post['mood'] ?? ''),
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
                                      if (post['date'] != null)
                                        Chip(
                                          label: Text(
                                            DateTime.parse(post['date'])
                                                .toLocal()
                                                .toString()
                                                .split(' ')[0],
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
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    spacing: 32,
                                    children: [
                                      Opacity(
                                        opacity:
                                            (_processingLikes).contains(
                                              post['_id'] ?? 'unknown',
                                            )
                                            ? 0.5
                                            : 1.0,
                                        child: GestureDetector(
                                          onTap:
                                              (_processingLikes).contains(
                                                post['_id'] ?? 'unknown',
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
                                                    _processingLikes.add(
                                                      postId,
                                                    );
                                                  });
                                                  _toggleLike(
                                                    postId,
                                                    isCurrentlyLiked,
                                                  );
                                                },
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                width: 30,
                                                height: 30,
                                                child: CustomPaint(
                                                  painter:
                                                      forum.CrescentMoonPainter(
                                                        isLiked:
                                                            _likedPosts[post['_id'] ??
                                                                'unknown'] ??
                                                            false,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '${_likeCount[post['_id'] ?? 'unknown'] ?? 0}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Icon(
                                            Icons.comment_outlined,
                                            color: Colors.white70,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${(post['comments'] as List?)?.length ?? 0}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
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
                currentIndex: 3,
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
                  } else if (index == 2) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/forum',
                      (Route<dynamic> route) => false,
                    );
                  } else if (index == 3) {
                    Navigator.of(context).pushNamed('/users');
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
      ),
    );
  }
}
