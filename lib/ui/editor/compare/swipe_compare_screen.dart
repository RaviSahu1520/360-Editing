import 'dart:typed_data';

import 'package:flutter/material.dart';

class SwipeCompareScreen extends StatefulWidget {
  const SwipeCompareScreen({
    super.key,
    required this.before,
    required this.after,
    required this.title,
  });

  final Uint8List before;
  final Uint8List after;
  final String title;

  @override
  State<SwipeCompareScreen> createState() => _SwipeCompareScreenState();
}

class _SwipeCompareScreenState extends State<SwipeCompareScreen> {
  double _position = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _position = ((_position * width) + details.delta.dx) / width;
                _position = _position.clamp(0.0, 1.0);
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.memory(widget.after, fit: BoxFit.contain),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _position,
                    child: Image.memory(widget.before, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  left: width * _position - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _chip('Before'),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _chip('After'),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _chip('Swipe to compare'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
