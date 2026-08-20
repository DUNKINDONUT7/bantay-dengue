import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _legsSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-70 -46 140 140">
  <g stroke="#16140F" stroke-width="2.6" fill="none" stroke-linecap="round" opacity="0.9">
    <path d="M-6,4 Q -34,10 -46,2"/>
    <path d="M-6,4 Q -34,26 -50,34"/>
    <path d="M-6,10 Q -30,46 -40,74"/>
    <path d="M6,4 Q 34,10 46,2"/>
    <path d="M6,4 Q 34,26 50,34"/>
    <path d="M6,10 Q 30,46 40,74"/>
  </g>
</svg>
''';

const _bodySvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 -60 60 170">
  <line x1="0" y1="-38" x2="-14" y2="-58" stroke="#16140F" stroke-width="1.6" stroke-linecap="round"/>
  <line x1="0" y1="-38" x2="12" y2="-60" stroke="#16140F" stroke-width="1.6" stroke-linecap="round"/>
  <line x1="0" y1="-30" x2="-2" y2="8" stroke="#16140F" stroke-width="2.6" stroke-linecap="round"/>
  <circle cx="0" cy="-32" r="9" fill="#16140F"/>
  <ellipse cx="0" cy="6" rx="11" ry="46" fill="#16140F"/>
  <path d="M-11,20 Q0,26 11,20" stroke="#F6F1E6" stroke-width="1.4" fill="none" opacity="0.35"/>
  <path d="M-10,38 Q0,44 10,38" stroke="#F6F1E6" stroke-width="1.4" fill="none" opacity="0.35"/>
  <path d="M-8,54 Q0,59 8,54" stroke="#F6F1E6" stroke-width="1.4" fill="none" opacity="0.35"/>
</svg>
''';

const _wingSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 90">
  <path d="M30,84 C4,66 -6,30 14,4 C34,20 44,58 30,84 Z" fill="#16140F" fill-opacity="0.09" stroke="#16140F" stroke-width="1.2"/>
  <path d="M16,20 Q22,44 26,72" stroke="#16140F" stroke-width="0.8" fill="none" opacity="0.5"/>
</svg>
''';

/// A living 3D brand mark for the landing hero: legs, body, and two wings as
/// separate SVG layers held apart by a real perspective matrix, with a slow
/// idle tilt and continuous wing-flap — the same layered artwork used in the
/// design mockup, translated to Flutter's native Transform/Matrix4 instead
/// of CSS 3D (no mouse to drive parallax on a touch device, so the motion is
/// self-driven instead of hover-driven).
class MosquitoHero extends StatefulWidget {
  final double size;

  const MosquitoHero({super.key, this.size = 220});

  @override
  State<MosquitoHero> createState() => _MosquitoHeroState();
}

class _MosquitoHeroState extends State<MosquitoHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        final tilt = math.sin(t * 0.5) * 0.10;
        final flap = math.sin(t * 2.2);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateY(-0.30 + tilt)
            ..rotateX(0.14 + math.sin(t * 0.6) * 0.03),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: SvgPicture.string(_legsSvg, fit: BoxFit.contain),
                ),
                Align(
                  alignment: const Alignment(-0.30, -0.55),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..rotateZ(-0.32)
                      ..scaleByDouble(1.0, 0.94 - flap.abs() * 0.14, 1.0, 1.0),
                    child: SizedBox(
                      width: widget.size * 0.32,
                      height: widget.size * 0.48,
                      child: SvgPicture.string(_wingSvg, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0.30, -0.55),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..rotateZ(0.32)
                      ..scaleByDouble(-1.0, 0.94 - flap.abs() * 0.14, 1.0, 1.0),
                    child: SizedBox(
                      width: widget.size * 0.32,
                      height: widget.size * 0.48,
                      child: SvgPicture.string(_wingSvg, fit: BoxFit.contain),
                    ),
                  ),
                ),
                SizedBox(
                  width: widget.size * 0.7,
                  height: widget.size * 1.05,
                  child: SvgPicture.string(_bodySvg, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
