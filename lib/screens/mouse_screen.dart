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

  void _handlePan(DragUpdateDetails details) {
    _dx += details.delta.dx;
    _dy += details.delta.dy;

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
     int scrollAmount = (details.delta.dy / 5).round(); 
     if (scrollAmount != 0) {
        // NOTE: The C++ code provided does not strictly handle SCROLL.
        // Standard Arduino Mouse.move takes 3 args: x, y, wheel.
        // But the C++ parser only reads 2.
        // Sending a new command "SCROLL:amount" which the user can implement.
        context.read<BleService>().sendCommand("SCROLL", "$scrollAmount");
     }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                        child: Icon(Icons.touch_app, size: 64, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      border: Border(left: BorderSide(color: Colors.grey[900]!)),
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
