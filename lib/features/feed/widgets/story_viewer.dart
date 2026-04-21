import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de historia
// ─────────────────────────────────────────────────────────────────────────────

class StoryModel {
  final String docId;
  final String authorId;
  final String username;
  final String? avatarUrl;
  final String mediaUrl;
  final String? caption;
  final String? location;
  final DateTime createdAt;
  final List<String> viewedBy;

  bool get isViewedBy =>
      viewedBy.contains(FirebaseAuth.instance.currentUser?.uid ?? '');

  const StoryModel({
    required this.docId,
    required this.authorId,
    required this.username,
    this.avatarUrl,
    required this.mediaUrl,
    this.caption,
    this.location,
    required this.createdAt,
    required this.viewedBy,
  });

  factory StoryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StoryModel(
      docId: doc.id,
      authorId: d['authorId'] as String? ?? '',
      username: d['username'] as String? ?? '',
      avatarUrl: d['avatarUrl'] as String?,
      mediaUrl: d['mediaUrl'] as String? ?? '',
      caption: d['caption'] as String?,
      location: d['location'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewedBy: List<String>.from(d['viewedBy'] ?? []),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StoryViewer — pantalla fullscreen
//
// [allGroups]    lista de grupos de historias agrupados por autor
//                (índice 0 = primer usuario, etc.)
// [initialGroup] índice del grupo con el que se abre
// ─────────────────────────────────────────────────────────────────────────────

class StoryViewer extends StatefulWidget {
  final List<List<StoryModel>> allGroups;
  final int initialGroup;

  const StoryViewer({
    super.key,
    required this.allGroups,
    required this.initialGroup,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressCtrl;

  int _groupIndex = 0;
  int _storyIndex = 0;
  bool _isPaused = false;

  static const _storyDuration = Duration(seconds: 5);

  final String? _myId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroup;
    _pageController = PageController(initialPage: widget.initialGroup);

    _progressCtrl = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startStory();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Navegación ─────────────────────────────────────────────────────────────

  List<StoryModel> get _currentGroup => widget.allGroups[_groupIndex];

  StoryModel get _currentStory => _currentGroup[_storyIndex];

  void _startStory() {
    _progressCtrl.reset();
    _progressCtrl.forward();
    _markAsViewed(_currentStory);
  }

  void _nextStory() {
    if (_storyIndex < _currentGroup.length - 1) {
      setState(() => _storyIndex++);
      _startStory();
    } else {
      _nextUser();
    }
  }

  void _prevStory() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _startStory();
    } else {
      _prevUser();
    }
  }

  void _nextUser() {
    if (_groupIndex < widget.allGroups.length - 1) {
      setState(() {
        _groupIndex++;
        _storyIndex = 0;
      });
      _pageController.animateToPage(
        _groupIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevUser() {
    if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _storyIndex = 0;
      });
      _pageController.animateToPage(
        _groupIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    }
  }

  void _pause() {
    if (!_isPaused) {
      _progressCtrl.stop();
      setState(() => _isPaused = true);
    }
  }

  void _resume() {
    if (_isPaused) {
      _progressCtrl.forward();
      setState(() => _isPaused = false);
    }
  }

  // ── Marcar como vista ──────────────────────────────────────────────────────

  Future<void> _markAsViewed(StoryModel story) async {
    if (_myId == null) return;
    if (story.viewedBy.contains(_myId)) return;
    try {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(story.docId)
          .update({
            'viewedBy': FieldValue.arrayUnion([_myId]),
          });
    } catch (e) {
      debugPrint('[StoryViewer] Error marcando vista: $e');
    }
  }

  // ── Formato de tiempo ──────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.allGroups.length,
        itemBuilder: (_, pageIndex) {
          if (pageIndex != _groupIndex) {
            return const SizedBox.shrink();
          }

          final story = _currentStory;
          final group = _currentGroup;

          return GestureDetector(
            onTapDown: (_) => _pause(),
            onTapUp: (details) {
              _resume();
              final w = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < w / 3) {
                _prevStory();
              } else {
                _nextStory();
              }
            },
            onLongPressStart: (_) => _pause(),
            onLongPressEnd: (_) => _resume(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Imagen ────────────────────────────────────────────────
                Image.network(
                  story.mediaUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    _pause();
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                    if (frame != null && _isPaused) _resume();
                    return child;
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),

                // ── Gradiente superior ────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 160,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Gradiente inferior ────────────────────────────────────
                if (story.caption != null || story.location != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 160,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.65),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Barras de progreso ────────────────────────────────────
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: List.generate(group.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _ProgressBar(
                            progress: i < _storyIndex
                                ? 1.0
                                : i == _storyIndex
                                ? null // animado
                                : 0.0,
                            animation: i == _storyIndex ? _progressCtrl : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Header: avatar + nombre + tiempo + cerrar ─────────────
                Positioned(
                  top: MediaQuery.of(context).padding.top + 22,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: story.avatarUrl != null
                            ? NetworkImage(story.avatarUrl!)
                            : null,
                        child: story.avatarUrl == null
                            ? Text(
                                story.username.isNotEmpty
                                    ? story.username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      // Nombre + tiempo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _timeAgo(story.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Cerrar
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── Caption + ubicación ───────────────────────────────────
                if (story.caption != null || story.location != null)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (story.location != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Colors.white70,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                story.location!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        if (story.caption != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            story.caption!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de progreso individual
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  /// Si [animation] != null, usa el AnimationController para animar.
  /// Si [progress] != null (0.0 o 1.0), muestra estático.
  final double? progress;
  final AnimationController? animation;

  const _ProgressBar({this.progress, this.animation});

  @override
  Widget build(BuildContext context) {
    if (animation != null) {
      return AnimatedBuilder(
        animation: animation!,
        builder: (_, __) => _bar(animation!.value),
      );
    }
    return _bar(progress ?? 0.0);
  }

  Widget _bar(double value) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: value,
      backgroundColor: Colors.white.withOpacity(0.35),
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      minHeight: 2.5,
    ),
  );
}
