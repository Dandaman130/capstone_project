import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as dartmath;
import 'screens/scan.dart';
import 'screens/search.dart';
import 'screens/community_screen.dart';
import 'services/local_product_loader.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart'; // Import global colors

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalProductLoader.load();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Botanical',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SearchScreen(),
    const ScanScreen(),
    const CommunityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Uses the global scaffold background color
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: _BotanicalNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// ─── Botanical Nav Bar ────────────────────────────────────────────────────────
class _BotanicalNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BotanicalNavBar({required this.currentIndex, required this.onTap});

  @override
  State<_BotanicalNavBar> createState() => _BotanicalNavBarState();
}

class _BotanicalNavBarState extends State<_BotanicalNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _indicatorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _indicatorAnim = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_BotanicalNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _indicatorAnim = Tween<double>(
        begin: old.currentIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const icons = [
      Icons.search_rounded,
      Icons.qr_code_scanner_rounded,
      Icons.people_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: CustomPaint(
        painter: _VineBorderPainter(),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.forestDeep.withOpacity(0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.mossGreen.withOpacity(0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepShadow.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _indicatorAnim,
            builder: (context, child) {
              return CustomPaint(
                painter: _NavIndicatorPainter(
                  progress: _indicatorAnim.value,
                  itemCount: 3,
                ),
                child: child,
              );
            },
            child: Row(
              children: List.generate(3, (index) {
                final isSelected = widget.currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.center,
                      child: Icon(
                        icons[index],
                        size: 26,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Indicator Painter ────────────────────────────────────────────────────
class _NavIndicatorPainter extends CustomPainter {
  final double progress;
  final int itemCount;

  _NavIndicatorPainter({required this.progress, required this.itemCount});

  @override
  void paint(Canvas canvas, Size size) {
    final itemWidth = size.width / itemCount;
    final centerX = itemWidth * progress + itemWidth / 2;
    final centerY = size.height / 2;
    final radius = itemWidth * 0.38;

    final pillPaint = Paint()
      ..color = AppColors.mossGreen
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: radius * 2,
        height: size.height * 0.72,
      ),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, pillPaint);

    final stemPaint = Paint()
      ..color = AppColors.mossGreen.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final stemPath = Path();
    stemPath.moveTo(16, size.height - 8);
    for (double x = 16; x <= size.width - 16; x += 2) {
      final t = (x - 16) / (size.width - 32);
      final y = size.height - 8 + 3 * dartmath.sin(t * dartmath.pi * 4);
      stemPath.lineTo(x, y);
    }
    canvas.drawPath(stemPath, stemPaint);

    final leafPaint = Paint()
      ..color = AppColors.fernGreen.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    for (int i = 1; i < itemCount; i++) {
      final lx = itemWidth * i;
      final ly = size.height - 8;
      final leafPath = Path()
        ..moveTo(lx, ly)
        ..cubicTo(lx + 6, ly - 5, lx + 10, ly - 2, lx + 8, ly + 3)
        ..cubicTo(lx + 6, ly + 6, lx + 2, ly + 4, lx, ly);
      canvas.drawPath(leafPath, leafPaint);
    }
  }

  @override
  bool shouldRepaint(_NavIndicatorPainter old) => old.progress != progress;
}

// ─── Vine Border Painter ──────────────────────────────────────────────────────
class _VineBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = AppColors.fernGreen.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final leafPaint = Paint()
      ..color = AppColors.mossGreen
      ..style = PaintingStyle.fill;

    final accentLeafPaint = Paint()
      ..color = AppColors.agedGold
      ..style = PaintingStyle.fill;

    // Drawing logic remains same, but using AppColors
    final topStem = Path()..moveTo(12, -2);
    for (double x = 12; x <= size.width - 12; x += 2) {
      final t = (x - 12) / (size.width - 24);
      final y = -2 + 3 * dartmath.sin(t * dartmath.pi * 5);
      topStem.lineTo(x, y);
    }
    canvas.drawPath(topStem, stemPaint);

    final botStem = Path()..moveTo(12, size.height + 2);
    for (double x = 12; x <= size.width - 12; x += 2) {
      final t = (x - 12) / (size.width - 24);
      final y = size.height + 2 + 3 * dartmath.sin(t * dartmath.pi * 5 + 1.0);
      botStem.lineTo(x, y);
    }
    canvas.drawPath(botStem, stemPaint);

    _drawLeaves(canvas, size, leafPaint, accentLeafPaint);
    _drawCorners(canvas, size, stemPaint, leafPaint);
  }

  void _drawLeaves(Canvas canvas, Size size, Paint leaf, Paint accent) {
    final topPos = [0.08, 0.22, 0.38, 0.5, 0.62, 0.78, 0.92];
    for (int i = 0; i < topPos.length; i++) {
      final lx = 12 + (size.width - 24) * topPos[i];
      final ly = -2 + 3 * dartmath.sin(topPos[i] * dartmath.pi * 5);
      _drawLeaf(canvas, lx, ly, i.isEven ? -1.0 : 1.0, i % 3 == 0 ? accent : leaf);
    }
  }

  void _drawLeaf(Canvas canvas, double cx, double cy, double side, Paint paint) {
    canvas.save();
    canvas.translate(cx, cy);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(side * 10, -8, side * 18, -3, side * 15, 6)
      ..cubicTo(side * 12, 10, side * 4, 7, 0, 0);
    canvas.drawPath(leaf, paint);
    canvas.restore();
  }

  void _drawCorners(Canvas canvas, Size size, Paint stem, Paint leaf) {
    _drawCornerVine(canvas, 8, 4, stem, leaf);
    _drawCornerVine(canvas, size.width - 8, 4, stem, leaf);
    _drawCornerVine(canvas, 8, size.height - 4, stem, leaf);
    _drawCornerVine(canvas, size.width - 8, size.height - 4, stem, leaf);
  }

  void _drawCornerVine(Canvas canvas, double cx, double cy, Paint stem, Paint leaf) {
    final path = Path()..moveTo(cx, cy);
    for (double t = 0; t <= 1.0; t += 0.05) {
      final angle = t * dartmath.pi * 2.5;
      final r = t * 14;
      path.lineTo(cx + r * dartmath.cos(angle), cy - r * dartmath.sin(angle));
    }
    canvas.drawPath(path, stem);
    _drawLeaf(canvas, cx, cy, 1.0, leaf);
  }

  @override
  bool shouldRepaint(_VineBorderPainter old) => false;
}