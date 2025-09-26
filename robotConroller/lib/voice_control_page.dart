// REPLACE your previous VoiceControlPage with this one.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'main.dart';


/* ========================= Voice Control (BN/EN, robust) ========================= */

class VoiceControlPage extends StatefulWidget {
  final BluetoothConnection connection;
  final void Function(bool) onToggleTheme;
  const VoiceControlPage({super.key, required this.connection, required this.onToggleTheme});
  @override
  State<VoiceControlPage> createState() => _VoiceControlPageState();
}

class _VoiceControlPageState extends State<VoiceControlPage> {
  late final stt.SpeechToText _speech;
  bool _engineReady = false, _listening = false, _autoSend = true;
  String _status = 'idle', _partial = '', _final = '', _lastSent = '';
  double _level = 0;
  String? _selectedLocale;
  List<stt.LocaleName> _locales = const [];
  bool _wantsToListen = false; Timer? _restartTimer;

  @override
  void initState() { super.initState(); _speech = stt.SpeechToText(); _initEngine(); }
  @override
  void dispose() { _restartTimer?.cancel(); _speech.stop(); super.dispose(); }

  Future<void> _initEngine() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) { _snack('Microphone permission denied'); return; }
    final ok = await _speech.initialize(
      onError: (e) { setState(()=>_status='error: ${e.errorMsg}'); },
      onStatus: (s) { setState(()=>_status=s); if (_wantsToListen && s=='notListening'){ _scheduleRestart(); } },
    );
    if (!ok) { _snack('Speech service not available'); return; }
    _locales = await _speech.locales();
    final hasBn = _locales.any((l)=>l.localeId.toLowerCase().contains('bn_bd'));
    final hasEn = _locales.any((l)=>l.localeId.toLowerCase()=='en_us');
    _selectedLocale = hasBn ? 'bn_BD' : (hasEn ? 'en_US' : _locales.first.localeId);
    setState(()=>_engineReady = true);
  }

  void _scheduleRestart(){ _restartTimer?.cancel(); _restartTimer = Timer(const Duration(milliseconds: 250), () { if(mounted && _wantsToListen && !_listening){ _start(); } }); }

  Future<void> _toggle() async {
    if(!_engineReady){ await _initEngine(); if(!_engineReady) return; }
    if(_listening){ _wantsToListen=false; await _speech.stop(); setState(()=>_listening=false); }
    else { _wantsToListen=true; await _start(); }
  }

  Future<void> _start() async {
    _partial=''; _final=''; setState((){});
    final ok = await _speech.listen(
      localeId: _selectedLocale,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      onSoundLevelChange: (lvl){ setState(()=>_level=(lvl/50).clamp(0,1)); },
      onResult: (res){
        setState(()=>_partial = res.recognizedWords);
        if(res.finalResult){ setState(()=>_final = res.recognizedWords); _handle(_final); }
      },
      pauseFor: const Duration(seconds: 2), listenFor: const Duration(minutes: 1),
    );
    setState(()=>_listening = ok);
    if(!ok) _snack('Failed to start listening');
  }

  String? _match(String text){
    final s = text.toLowerCase().trim();
    if (s.contains('forward') || s.contains('go forward') || s.contains('go ahead')) return '1';
    if (s.contains('back') || s.contains('backward') || s.contains('go back')) return '2';
    if (s.contains('turn right') || s == 'right' || s.endsWith(' right')) return 'D';
    if (s.contains('turn left') || s == 'left' || s.endsWith(' left')) return 'E';
    if (s.contains('সামনে') || s.contains('এগাও') || s.contains('আগাও') || s.contains('samne') || s.contains('shamne') || s.contains('agao')) return '1';
    if (s.contains('পেছনে') || s.contains('পিছনে') || s.contains('উল্টো') || s.contains('pichone') || s.contains('pechone')) return '2';
    if (s.contains('ডান') || s.contains('dan')) return 'D';
    if (s.contains('বাম') || s.contains('bam')) return 'E';
    if (s == 'stop' || s.contains('থাম') || s.contains('থামো')) return 'S';
    return null;
  }

  void _handle(String phrase){
    final cmd = _match(phrase);
    if (cmd == null) { _snack('No command matched'); return; }
    if (_autoSend) { _send(cmd); }
  }

  void _send(String cmd){
    if(!widget.connection.isConnected){ _snack('Bluetooth disconnected'); return; }
    widget.connection.output.add(Uint8List.fromList(cmd.codeUnits));
    widget.connection.output.allSent;
    setState(()=>_lastSent = cmd);
    HapticFeedback.selectionClick();
  }

  void _reinitVoice() async {
    _restartTimer?.cancel(); _wantsToListen=false;
    await _speech.cancel(); await _speech.stop();
    setState((){ _listening=false; _engineReady=false; _status='reinitializing…'; });
    await _initEngine(); _snack('Voice engine reinitialized');
  }

  void _snack(String m)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = _match(_final.isNotEmpty ? _final : _partial);

    return GlassNavShell(
      title: 'Voice Mode',
      isDark: isDark,
      onToggleTheme: () => widget.onToggleTheme(!isDark),
      actions: [
        IconButton(tooltip: 'Re-initialize', icon: const Icon(Icons.restart_alt), onPressed: _reinitVoice),
      ],
      body: Column(
        children: [
          Row(children: [
            Expanded(child: _LocaleDropdown(
              locales: _locales, selected: _selectedLocale,
              onChanged: (v){ setState(()=>_selectedLocale=v); if(_listening){ _speech.stop(); _start(); } },
            )),
            const SizedBox(width: 12),
            Row(children: [
              const Text('Auto-send'), Switch(value: _autoSend, onChanged: (v)=>setState(()=>_autoSend=v)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            StatusPill(text: 'Status: $_status', ok: _listening),
            const SizedBox(width: 12),
            Expanded(child: _LevelBar(level: _level)),
          ]),
          const SizedBox(height: 12),
          GlassCard(child: _KV('You said (live)', _partial.isEmpty ? '—' : _partial)),
          GlassCard(child: _KV('Final phrase', _final.isEmpty ? '—' : _final)),
          GlassCard(child: _KV('Matched command', preview ?? '—')),
          GlassCard(child: _KV('Last sent', _lastSent.isEmpty ? '—' : _lastSent)),
          const Spacer(),
          Row(children: [
            Expanded(child: GradientButton(label: _listening ? 'Listening… Tap to stop' : 'Tap to speak', icon: Icons.mic, onPressed: _toggle, big: true)),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: preview==null ? null : ()=>_send(preview),
              icon: const Icon(Icons.send), label: const Text('Send'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),
          ]),
        ],
      ),
    );
  }
}

/* ---------- Voice small UI ---------- */

class _LocaleDropdown extends StatelessWidget {
  final List<stt.LocaleName> locales;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _LocaleDropdown({required this.locales, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [...locales];
    items.sort((a, b) {
      int score(stt.LocaleName l) {
        final id = l.localeId.toLowerCase();
        if (id.contains('bn_bd')) return 0;
        if (id == 'en_us') return 1;
        return 2;
      } return score(a).compareTo(score(b));
    });
    return DropdownButtonFormField<String>(
      value: selected,
      isExpanded: true,
      items: items.map((l)=>DropdownMenuItem(value: l.localeId, child: Text('${l.name} (${l.localeId})'))).toList(),
      decoration: InputDecoration(
        labelText: 'Language',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}

class _LevelBar extends StatelessWidget {
  final double level;
  const _LevelBar({required this.level});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: level.clamp(0,1), minHeight: 10, backgroundColor: Colors.black12),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k, v;
  const _KV(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(width: 12),
      Expanded(child: Text(v, textAlign: TextAlign.right)),
    ]);
  }
}
