import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';

class KeyboardScreen extends StatefulWidget {
  const KeyboardScreen({super.key});

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _macros = ["Hello World", "ls -la", "exit", "sudo su"];

  bool _appendNewline = true;
  final Set<String> _activeModifiers = {};

  void _sendText(String text) {
    if (text.isEmpty) return;

    String payload = text;
    if (_appendNewline) {
      // If we are appending newline, we assume the intention is to "Enter"
      // But if it's a modifier combo, usually applied to a key.
      // If modifiers are active, we treat 'text' as the key if length 1.
      if (!payload.endsWith('\n')) {
        payload += '\n';
      }
    }

    if (_activeModifiers.isNotEmpty) {
      // Send as COMBO
      // Format: COMBO:MOD1,MOD2,KEY
      // Note: If text is a long string + modifiers, it's usually invalid in HID context (modifiers apply to single keystrokes).
      // We will blindly send it and expect firmware to handle or user to know.
      // But practically, "Ctrl" + "c" is valid. "Ctrl" + "Hello" is weird (Ctrl+H, Ctrl+e...).
      // We'll join commands.
      String mods = _activeModifiers.join(",");
      context.read<BleService>().sendCommand("COMBO", "$mods,$payload");

      // Auto-clear modifiers after use (Sticky keys behavior)
      setState(() {
        _activeModifiers.clear();
      });
    } else {
      context.read<BleService>().sendCommand("TYPE", payload);
    }
  }

  void _sendCombo(String combo) {
    context.read<BleService>().sendCommand("COMBO", combo);
  }

  Widget _keyButton(String label, String key) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        minimumSize: const Size(40, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () => _sendCombo(key),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Options Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text("EOL \\n"),
              Checkbox(
                value: _appendNewline,
                onChanged: (v) => setState(() => _appendNewline = v!),
              ),
              const Spacer(),
              SegmentedButton<TargetOS>(
                segments: const [
                  ButtonSegment(
                    value: TargetOS.windows,
                    icon: Icon(Icons.window),
                    label: Text("Win"),
                  ),
                  ButtonSegment(
                    value: TargetOS.linux,
                    icon: Icon(Icons.terminal),
                    label: Text("Linux"),
                  ),
                ],
                selected: {context.watch<BleService>().targetOS},
                onSelectionChanged: (Set<TargetOS> newSelection) {
                  context.read<BleService>().setTargetOS(newSelection.first);
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Real-time typing area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: "Type to send...",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  _sendText(_controller.text);
                  _controller.clear();
                },
              ),
            ),
            onChanged: (val) {
              // Optional: Live typing logic here
            },
            onSubmitted: (val) {
              _sendText(val);
              _controller.clear();
            },
            textInputAction: TextInputAction.send,
          ),
        ),

        const Divider(),

        // Quick Actions / Macros
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Quick Actions",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: context.watch<BleService>().targetOS == TargetOS.windows
                ? _windowsActions()
                : _linuxActions(),
          ),
        ),

        const Divider(),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Text Control",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionButton("Select All", () => _sendCombo("CTRL,a")),
                      _actionButton("Copy", () => _sendCombo("CTRL,c")),
                      _actionButton("Cut", () => _sendCombo("CTRL,x")),
                      _actionButton("Paste", () => _sendCombo("CTRL,v")),
                      _actionButton("Undo", () => _sendCombo("CTRL,z")),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    "Special Keys",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _keyButton("ESC", "ESC"),
                      _keyButton("TAB", "TAB"),
                      _keyButton("INS", "INSERT"),
                      _keyButton("HOME", "HOME"),
                      _keyButton("END", "END"),
                      _keyButton("PGUP", "PAGEUP"),
                      _keyButton("PGDN", "PAGEDOWN"),
                      _keyButton("ENTER", "ENTER"),
                      _keyButton("BKSP", "BACKSPACE"),
                      _keyButton("DEL", "DELETE"),
                      _keyButton("GUI", "GUI"),
                      _keyButton("PRTSC", "PRINTSCREEN"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: List.generate(
                      12,
                      (index) => _keyButton("F${index + 1}", "F${index + 1}"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_keyButton("↑", "UP")],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _keyButton("←", "LEFT"),
                      _keyButton("↓", "DOWN"),
                      _keyButton("→", "RIGHT"),
                    ],
                  ),
                ],
              ),
              const Divider(),

              Text("Macros", style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _macros
                    .map(
                      (macro) => ActionChip(
                        label: Text(macro.replaceAll("\n", "⏎")),
                        onPressed: () => _sendText(macro),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),

              Text(
                "Modifiers (Toggles)",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _modifierButton("CTRL"),
                  _modifierButton("ALT"),
                  _modifierButton("SHIFT"),
                  _modifierButton("GUI"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ), // Rectangular
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _modifierButton(String label) {
    final bool isActive = _activeModifiers.contains(label);
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ), // Rectangular
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primary
            : null,
        foregroundColor: isActive
            ? Theme.of(context).colorScheme.onPrimary
            : null,
      ),
      onPressed: () {
        setState(() {
          if (isActive) {
            _activeModifiers.remove(label);
          } else {
            _activeModifiers.add(label);
          }
        });
      },
      child: Text(label),
    );
  }

  List<Widget> _windowsActions() {
    return [
      _actionButton("Term", () async {
        await context.read<BleService>().sendCommand("COMBO", "GUI,r");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand("TYPE", "cmd\n");
      }),
      _actionButton("WiFi Pass", () async {
        await context.read<BleService>().sendCommand("COMBO", "GUI,r");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "powershell -NoP -NoExit -c \"netsh wlan show profiles name=* key=clear\"\n",
        );
      }),
      _actionButton("Sys Info", () async {
        await context.read<BleService>().sendCommand("COMBO", "GUI,r");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "cmd /k systeminfo\n",
        );
      }),
      _actionButton("List Tasks", () async {
        await context.read<BleService>().sendCommand("COMBO", "GUI,r");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "cmd /k tasklist\n",
        );
      }),
      _actionButton("Task View", () {
        context.read<BleService>().sendCommand("COMBO", "GUI,TAB");
      }),
      _actionButton("Close Win", () {
        context.read<BleService>().sendCommand("COMBO", "ALT,F4");
      }),
      _actionButton("Fake Update", () async {
        await context.read<BleService>().sendCommand("COMBO", "GUI,r");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "https://fakeupdate.net/win10ue/\n",
        );
        // Wait for browser to open
        await Future.delayed(const Duration(seconds: 4));
        // Spam F11
        await context.read<BleService>().sendCommand("COMBO", "F11");
      }),
      _actionButton("Rickroll", () async {
        await context.read<BleService>().sendCommand("COMBO", "GUI,r");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "https://www.youtube.com/watch?v=dQw4w9WgXcQ\n",
        );
        await Future.delayed(const Duration(seconds: 3));
        await context.read<BleService>().sendCommand("COMBO", "f");
      }),
      _actionButton("Desktop", () {
        context.read<BleService>().sendCommand("COMBO", "GUI,d");
      }),
      _actionButton("Task Mgr", () {
        context.read<BleService>().sendCommand("COMBO", "CTRL,SHIFT,ESC");
      }),
      _actionButton("Lock PC", () {
        context.read<BleService>().sendCommand("COMBO", "GUI,l");
      }),
    ];
  }

  List<Widget> _linuxActions() {
    return [
      _actionButton("Terminal", () async {
        await context.read<BleService>().sendCommand("COMBO", "CTRL,ALT,t");
      }),
      _actionButton("Run...", () async {
        await context.read<BleService>().sendCommand("COMBO", "ALT,F2");
      }),
      _actionButton("List Tasks", () async {
        await context.read<BleService>().sendCommand("COMBO", "CTRL,ALT,t");
        await Future.delayed(const Duration(seconds: 1));
        // 'top' is interactive, maybe just ps aux?
        // user asked for "list, running task". top is good.
        await context.read<BleService>().sendCommand("TYPE", "top\n");
      }),
      _actionButton("Sys Info", () async {
        await context.read<BleService>().sendCommand("COMBO", "CTRL,ALT,t");
        await Future.delayed(const Duration(seconds: 1));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "neofetch || uname -a\n",
        );
      }),
      _actionButton("Fake Update", () async {
        await context.read<BleService>().sendCommand("COMBO", "ALT,F2");
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<BleService>().sendCommand(
          "TYPE",
          "xdg-open https://fakeupdate.net/win10ue/\n",
        );
        await Future.delayed(const Duration(seconds: 4)); // Increased delay
        await context.read<BleService>().sendCommand("COMBO", "F11");
      }),
      _actionButton("Close Win", () {
        context.read<BleService>().sendCommand("COMBO", "ALT,F4");
      }),
      _actionButton("Copy", () {
        context.read<BleService>().sendCommand("COMBO", "CTRL,c");
      }),
      _actionButton("Lock PC", () {
        context.read<BleService>().sendCommand("COMBO", "CTRL,ALT,l");
      }),
    ];
  }
}
