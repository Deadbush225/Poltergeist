import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';

class MouseScreen extends StatefulWidget {
  const MouseScreen({super.key});

  @override
  State<MouseScreen> createState() => _MouseScreenState();
}

class _MouseScreenState extends State<MouseScreen> {
  Timer? _throttleTimer;
  double _dx = 0;
  double _dy = 0;
  double _sensitivity = 2.0; // Multiplier for mouse movement
  double _scrollAccumulator = 0;

  void _handlePan(DragUpdateDetails details) {
    _dx += details.delta.dx * _sensitivity;
    _dy += details.delta.dy * _sensitivity;

    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _throttleTimer = Timer(const Duration(milliseconds: 30), () {
        _sendMove();
      });
    }
  }

  void _sendMove() {
    // Scale down or up as needed.
    // Assuming device expects integers.
    int x = _dx.round();
    int y = _dy.round();
    if (x != 0 || y != 0) {
      context.read<BleService>().sendCommand("MOVE", "$x,$y");
      _dx = 0;
      _dy = 0;
    }
  }

  void _handleScroll(DragUpdateDetails details) {
    _scrollAccumulator += details.delta.dy;
    // Threshold of 10 pixels for 1 scroll unit to avoid sensitivity
    const double threshold = 10.0;

    if (_scrollAccumulator.abs() >= threshold) {
      int steps = (_scrollAccumulator / threshold).truncate();
      if (steps != 0) {
        context.read<BleService>().sendCommand("SCROLL", "$steps");
        _scrollAccumulator -= steps * threshold;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text("Speed:"),
              Expanded(
                child: Slider(
                  value: _sensitivity,
                  min: 0.5,
                  max: 5.0,
                  onChanged: (val) {
                    setState(() {
                      _sensitivity = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    onPanUpdate: _handlePan,
                    onPanEnd: (_) => _sendMove(), // Send remainder
                    child: Container(
                      color: Colors.transparent, // Hit test
                      child: Center(
                        child: Icon(
                          Icons.touch_app,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      border: Border(
                        left: BorderSide(color: Colors.grey[900]!),
                      ),
                    ),
                    child: GestureDetector(
                      onVerticalDragUpdate: _handleScroll,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.unfold_more, color: Colors.white),
                          Text("Scroll", style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMouseButton("Left", 1),
              _buildMouseButton("Right", 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMouseButton(String label, int buttonCode) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(120, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        context.read<BleService>().sendCommand("CLICK", "$buttonCode");
      },
      child: Text(label),
    );
  }
}
