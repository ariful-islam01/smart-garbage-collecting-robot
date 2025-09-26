// main.dart
// Professional, animated, glassy UI with responsive custom navbar (no logo in navbar).
// Features: Bluetooth pairing, Mode selection, Manual control (live angles), Voice mode with bn/en toggle.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'voice_control_page.dart';

/* ========================= Entry & Theme ========================= */

void main() => runApp(const GRCApp());

class GRCApp extends StatefulWidget {
  const GRCApp({super.key});
  @override
  State<GRCApp> createState() => _GRCAppState();
}

class _GRCAppState extends State<GRCApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2F7CF6);
    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF7F8FB),
      textTheme: Typography.blackCupertino,
    );
    final dark = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      textTheme: Typography.whiteCupertino,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Garbage Robot Controller',
      theme: light,
      darkTheme: dark,
      themeMode: _mode,
      home: DeviceListPage(
        onToggleTheme: (isDark) => setState(() => _mode = isDark ? ThemeMode.dark : ThemeMode.light),
      ),
    );
  }
}

/* ========================= Glassy Responsive Navbar ========================= */

class GlassNavShell extends StatelessWidget {
  final String title;
  final List<Widget> actions; // ছোট স্ক্রিনে এগুলো "More" এ ভাঁজ হবে
  final Widget body;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const GlassNavShell({
    super.key,
    required this.title,
    required this.actions,
    required this.body,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(.06), cs.secondary.withOpacity(.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _GlassNavBar(
                title: title,
                isDark: isDark,
                onToggleTheme: onToggleTheme,
                actions: actions,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const _GlassNavBar({
    required this.title,
    required this.actions,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final maxW = c.maxWidth;
                final canShowAll = maxW > 420; // ব্রেকপয়েন্ট

                final headActions = <Widget>[
                  IconButton(
                    tooltip: isDark ? 'Light mode' : 'Dark mode',
                    onPressed: onToggleTheme,
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  ),
                  if (canShowAll) ...actions,
                  if (!canShowAll && actions.isNotEmpty) _MoreMenu(actions: actions),
                ];

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Row(children: headActions),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final List<Widget> actions;
  const _MoreMenu({required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => List.generate(actions.length, (i) {
        final w = actions[i];
        String label = 'Action ${i + 1}';
        IconData? icon;
        if (w is IconButton) {
          if (w.icon is Icon) icon = (w.icon as Icon).icon;
          label = w.tooltip ?? label;
        }
        return PopupMenuItem<int>(
          value: i,
          child: Row(
            children: [
              if (icon != null) Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
            ],
          ),
        );
      }),
      onSelected: (i) {
        final w = actions[i];
        if (w is IconButton && w.onPressed != null) w.onPressed!();
      },
    );
  }
}

/* ========================= Reusable UI ========================= */

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double blur;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.blur = 10,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cs.surface.withOpacity(.6),
              border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool big;
  const GradientButton({super.key, required this.label, required this.icon, required this.onPressed, this.big = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () { HapticFeedback.mediumImpact(); onPressed(); },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [cs.primary, cs.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: cs.primary.withOpacity(.25), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: big ? 18 : 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final bool ok;
  const StatusPill({super.key, required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final c = ok ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: c.withOpacity(.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline, size: 18, color: c),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/* ========================= Device List ========================= */

class DeviceListPage extends StatefulWidget {
  final void Function(bool) onToggleTheme;
  const DeviceListPage({super.key, required this.onToggleTheme});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> with SingleTickerProviderStateMixin {
  List<BluetoothDevice> _devices = [];
  bool _loading = true;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _initBluetooth();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    setState(() => _loading = true);
    final statuses = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    if (statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      _toast('Bluetooth permissions denied'); setState(() => _loading = false); return;
    }
    final enabled = await FlutterBluetoothSerial.instance.requestEnable();
    if (enabled != true) { _toast('Bluetooth disabled'); setState(() => _loading = false); return; }
    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() { _devices = bonded; _loading = false; });
    } catch (e) { _toast('Failed to load devices: $e'); setState(() => _loading = false); }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GlassNavShell(
      title: 'Select Device',
      isDark: isDark,
      onToggleTheme: () => widget.onToggleTheme(!isDark),
      actions: [
        IconButton(tooltip: 'Scan', icon: const Icon(Icons.refresh), onPressed: _initBluetooth),
        IconButton(tooltip: 'Help', icon: const Icon(Icons.help_outline), onPressed: () {}),
      ],
      body: Column(
        children: [
          GlassCard(
            child: Row(
              children: [
                ScaleTransition(
                    scale: Tween(begin: .95, end: 1.05).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                    child: Image.asset('assets/logo.png', height: 44)),
                const SizedBox(width: 12),
                Expanded(child: Text('Garbage Robot Controller', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _initBluetooth,
                  icon: const Icon(Icons.search),
                  label: const Text('Scan'),
                  style: FilledButton.styleFrom(
                      backgroundColor: cs.primaryContainer, foregroundColor: cs.onPrimaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const _LoadingState(label: 'Scanning paired devices…')
                : _devices.isEmpty
                ? const _EmptyState(icon: Icons.bluetooth_disabled, title: 'No paired devices found')
                : ListView.separated(
              padding: const EdgeInsets.only(top: 4),
              itemCount: _devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = _devices[i];
                return _DeviceTile(
                  device: d,
                  onTap: () => Navigator.push(
                    context,
                    _fadeRoute(ModeSelectionPage(device: d, onToggleTheme: widget.onToggleTheme)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;
  const _DeviceTile({required this.device, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      blur: 12,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: Container(
            decoration: BoxDecoration(color: cs.primary.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.bluetooth, color: cs.primary)),
        title: Text(device.name ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(device.address),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String label;
  const _LoadingState({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      const CircularProgressIndicator(),
      const SizedBox(height: 12),
      Text(label),
    ]));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  const _EmptyState({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ]),
      ),
    );
  }
}

/* ========================= Mode Selection ========================= */

class ModeSelectionPage extends StatefulWidget {
  final BluetoothDevice device;
  final void Function(bool) onToggleTheme;
  const ModeSelectionPage({super.key, required this.device, required this.onToggleTheme});
  @override
  State<ModeSelectionPage> createState() => _ModeSelectionPageState();
}

class _ModeSelectionPageState extends State<ModeSelectionPage> {
  BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;
  bool _connected = false;
  String _status = 'Connecting…';

  @override
  void initState() { super.initState(); _connect(); }
  @override
  void dispose() { _sub?.cancel(); _conn?.dispose(); super.dispose(); }

  Future<void> _connect() async {
    setState(() => _status = 'Connecting to ${widget.device.name}…');
    try {
      final c = await BluetoothConnection.toAddress(widget.device.address);
      _conn = c;
      _sub = c.input?.listen((_) {}, onDone: () => setState((){ _connected = false; _status='Disconnected'; }));
      setState(() { _connected = true; _status = 'Connected'; });
    } catch (e) {
      setState(() { _connected = false; _status = 'Connection Failed: $e'; });
    }
  }

  void _send(String s) {
    final c = _conn;
    if (c == null || !c.isConnected) { _toast('Not connected'); return; }
    c.output.add(Uint8List.fromList(s.codeUnits));
    c.output.allSent;
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassNavShell(
      title: 'Choose Mode',
      isDark: isDark,
      onToggleTheme: () => widget.onToggleTheme(!isDark),
      actions: [
        // status pill as tooltip (icon only)
        IconButton(
          tooltip: _status,
          icon: Icon(_connected ? Icons.check_circle : Icons.error_outline,
              color: _connected ? Colors.green : Colors.orange),
          onPressed: () {},
        ),
      ],
      body: _connected
          ? Column(
        children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.device.name ?? 'Unknown Device',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(widget.device.address, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ]),
          ),
          const SizedBox(height: 6),
          GlassCard(child: const Text('Select how you want to operate the robot.')),
          const Spacer(),
          GradientButton(label: 'Automatic Mode', icon: Icons.auto_awesome, big: true, onPressed: () { _send('0'); _toast('Automatic Mode Activated'); }),
          const SizedBox(height: 12),
          GradientButton(label: 'Manual Control', icon: Icons.gamepad, big: true, onPressed: () {
            _send('z');
            Navigator.of(context).push(_fadeRoute(ControlPage(connection: _conn!, onToggleTheme: widget.onToggleTheme)));
          }),
        ],
      )
          : Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _LoadingState(label: 'Connecting…'),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _connect, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      ),
    );
  }
}

/* ========================= Control (Manual) ========================= */

class ControlPage extends StatefulWidget {
  final BluetoothConnection connection;
  final void Function(bool) onToggleTheme;
  const ControlPage({super.key, required this.connection, required this.onToggleTheme});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  late final Animation<double> _btnScale = Tween<double>(begin: .97, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  ServoAngles _angles = ServoAngles();

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _send(String s) {
    if (!widget.connection.isConnected) { _toast('Disconnected'); return; }
    widget.connection.output.add(Uint8List.fromList(s.codeUnits));
    widget.connection.output.allSent;
  }

  void _applyLocalAngle(String cmd) {
    switch (cmd) {
      case '5': _angles.base += 5; break;
      case '6': _angles.base -= 5; break;
      case '7': _angles.shoulder += 5; break;
      case '8': _angles.shoulder -= 5; break;
      case '9': _angles.elbow += 5; break;
      case 'A': _angles.elbow -= 5; break;
      case 'B': _angles.gripper += 5; break;
      case 'C': _angles.gripper -= 5; break;
      default: return;
    }
    _angles.clampAll(); setState(() {});
  }

  Widget _ctl(String label, IconData icon, String cmd) => ScaleTransition(
    scale: _btnScale,
    child: FilledButton.tonal(
      onPressed: () { HapticFeedback.lightImpact(); _send(cmd); _applyLocalAngle(cmd); },
      style: FilledButton.styleFrom(minimumSize: const Size(120, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), const SizedBox(height: 6), Text(label)]),
    ),
  );

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassNavShell(
      title: 'Manual Control',
      isDark: isDark,
      onToggleTheme: () => widget.onToggleTheme(!isDark),
      actions: [
        IconButton(
          tooltip: 'Voice Mode',
          icon: const Icon(Icons.mic),
          onPressed: () => Navigator.push(context,
              _fadeRoute(VoiceControlPage(connection: widget.connection, onToggleTheme: widget.onToggleTheme))),
        ),
        IconButton(
          tooltip: widget.connection.isConnected ? 'Connected' : 'Disconnected',
          icon: Icon(widget.connection.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
          onPressed: () {},
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Movement
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Movement', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Column(children: [
                _ctl('Forward', Icons.arrow_upward, '1'),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _ctl('Left', Icons.arrow_back, '3'),
                  const SizedBox(width: 12),
                  _ctl('Stop', Icons.stop, 'S'),
                  const SizedBox(width: 12),
                  _ctl('Right', Icons.arrow_forward, '4'),
                ]),
                const SizedBox(height: 8),
                _ctl('Backward', Icons.arrow_downward, '2'),
              ]),
            ])),
            // Live angles
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arm Angles', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              AnglePanel(angles: _angles),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(onPressed: () => setState(() => _angles = ServoAngles()), icon: const Icon(Icons.restore), label: const Text('Reset (90°)')),
              ]),
            ])),
            // Arm controls
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arm Controls', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.1, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [
                _ctl('Base Left', Icons.rotate_left, '5'),
                _ctl('Base Right', Icons.rotate_right, '6'),
                _ctl('Shoulder Down', Icons.arrow_downward, '7'),
                _ctl('Shoulder Up', Icons.arrow_upward, '8'),
                _ctl('Elbow Down', Icons.arrow_downward, '9'),
                _ctl('Elbow Up', Icons.arrow_upward, 'A'),
                _ctl('Gripper Close', Icons.close, 'B'),
                _ctl('Gripper Open', Icons.open_in_full, 'C'),
              ]),
            ])),
          ],
        ),
      ),
    );
  }
}

/* ========================= Angle Model + Panel ========================= */

class ServoAngles {
  int base, shoulder, elbow, gripper;
  ServoAngles({this.base = 90, this.shoulder = 90, this.elbow = 90, this.gripper = 90});
  void clampAll(){ base = base.clamp(0, 180); shoulder = shoulder.clamp(0, 180); elbow = elbow.clamp(0, 180); gripper = gripper.clamp(0, 180); }
}

class AnglePanel extends StatelessWidget {
  final ServoAngles angles;
  const AnglePanel({super.key, required this.angles});

  Widget _row(BuildContext ctx, String label, int v, IconData icon) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('$v°', style: Theme.of(ctx).textTheme.titleMedium),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _row(context, 'Base', angles.base, Icons.rotate_right),
      _row(context, 'Shoulder', angles.shoulder, Icons.swap_vert),
      _row(context, 'Elbow', angles.elbow, Icons.linear_scale),
      _row(context, 'Gripper', angles.gripper, Icons.open_in_full),
    ]);
  }
}

/* ========================= Route Transition ========================= */

PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 320),
  pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: page),
);
