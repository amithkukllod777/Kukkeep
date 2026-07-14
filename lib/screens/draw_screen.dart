import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../auth_messages.dart';
import '../note_colors.dart';

// A lightweight freehand drawing canvas. Uses only Flutter's built-in
// CustomPaint + RepaintBoundary (no native plugins), exports the sketch as a PNG
// and returns its bytes so the editor can upload it as an image attachment.
class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});
  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke(this.points, this.color, this.width);
}

class _DrawScreenState extends State<DrawScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  final List<_Stroke> _redo = []; // undone strokes, restorable until a new stroke
  Color _color = Colors.black;
  double _width = 4;
  bool _eraser = false;
  bool _saving = false;

  static const List<Color> _palette = [
    Colors.black, Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFDC2626),
    Color(0xFFF59E0B), Color(0xFF7C3AED),
  ];
  static const List<double> _widths = [3, 6, 12];

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
  }

  void _redoStroke() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
  }

  Future<void> _save() async {
    if (_strokes.isEmpty) { Navigator.pop(context); return; }
    setState(() => _saving = true);
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.pop(context, data?.buffer.asUint8List());
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Drawing', style: TextStyle(color: Colors.black87, fontFamily: kDisplayFont, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.black54),
              tooltip: 'Clear',
              onPressed: _strokes.isEmpty ? null : () => setState(() { _strokes.clear(); _redo.clear(); })),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: kBrandDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          Expanded(
            child: RepaintBoundary(
              key: _canvasKey,
              child: Container(
                color: Colors.white,
                child: GestureDetector(
                  onPanStart: (d) => setState(() {
                    _redo.clear(); // a new stroke invalidates the redo history
                    _strokes.add(_Stroke([d.localPosition], _eraser ? Colors.white : _color, _eraser ? _width * 3 : _width));
                  }),
                  onPanUpdate: (d) => setState(() => _strokes.last.points.add(d.localPosition)),
                  child: CustomPaint(painter: _DrawPainter(_strokes), size: Size.infinite),
                ),
              ),
            ),
          ),
          // ── Tool tray: colors · eraser · stroke sizes ──
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final c in _palette)
                        Semantics(
                          label: 'Pen color',
                          selected: !_eraser && _color == c,
                          button: true,
                          child: GestureDetector(
                            onTap: () => setState(() { _color = c; _eraser = false; }),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10, top: 3, bottom: 3),
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: c, shape: BoxShape.circle,
                                border: Border.all(
                                  color: !_eraser && _color == c ? kBrand : Colors.black26,
                                  width: !_eraser && _color == c ? 3 : 1),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                // Eraser toggle
                Tooltip(
                  message: 'Eraser',
                  child: GestureDetector(
                    onTap: () => setState(() => _eraser = !_eraser),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4, right: 10),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _eraser ? const Color(0xFFE3F2FD) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _eraser ? kBrand : Colors.black26),
                      ),
                      child: Icon(Icons.cleaning_services_outlined, size: 20, color: _eraser ? kBrandDark : Colors.black45),
                    ),
                  ),
                ),
                // Stroke width presets (dot size = stroke size)
                for (final w in _widths)
                  Semantics(
                    label: 'Stroke width $w',
                    selected: _width == w,
                    button: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _width = w),
                      child: Container(
                        width: 30, height: 30,
                        margin: const EdgeInsets.only(right: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _width == w ? const Color(0xFFE3F2FD) : Colors.transparent,
                        ),
                        child: Container(
                          width: 6 + w, height: 6 + w,
                          decoration: BoxDecoration(color: _width == w ? kBrandDark : Colors.black38, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
        // ── Floating undo / redo pill (top-right, like the reference) ──
        Positioned(
          top: 10, right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Undo', icon: const Icon(Icons.undo, size: 20), color: _strokes.isEmpty ? Colors.black26 : Colors.black87,
                  onPressed: _strokes.isEmpty ? null : _undo),
              Container(width: 1, height: 20, color: Colors.black12),
              IconButton(tooltip: 'Redo', icon: const Icon(Icons.redo, size: 20), color: _redo.isEmpty ? Colors.black26 : Colors.black87,
                  onPressed: _redo.isEmpty ? null : _redoStroke),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DrawPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _DrawPainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, s.points, paint..strokeCap = StrokeCap.round);
      } else {
        for (var i = 0; i < s.points.length - 1; i++) {
          canvas.drawLine(s.points[i], s.points[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DrawPainter oldDelegate) => true;
}
