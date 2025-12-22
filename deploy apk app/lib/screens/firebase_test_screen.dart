import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

// removed Firestore listener - this screen now uses the lightweight RTDB REST client
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../firebase_options.dart';
import '../firebase_custom.dart';
import '../services/realtime_db_service.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  // Use the default URL from service (sourced from dart-define or baked-in).
  bool _initialized = false;
  bool _loading = false;
  String _status = 'Not initialized';
  String? _uid;
  String? _lastError;
  // Light control + measured latency (microseconds)
  bool _lightOn = false;
  int? _latencyMicros;

  // Connectivity & Firestore listener
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _setupConnectivity();
  }

  void _setupConnectivity() {
    // Initial connectivity
    Connectivity().checkConnectivity().then((r) => _onConnectivityChanged(r));
    // Listen for changes
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    final online = result != ConnectivityResult.none;
    if (online == _isOnline) return;
    setState(() => _isOnline = online);
    // no firestore listeners here; we only enable/disable interactive buttons when online
  }

  // no Firestore listeners — simplified control screen

  Future<void> _reloadAcOnce() async {
    // removed (no Firestore AC reload)
    _showMessage('Reload not available');
  }

  Future<void> _initFirebase() async {
    try {
      setState(() => _status = 'Initializing...');
      // Prefer a custom set of FirebaseOptions if provided in `firebase_custom.dart`.
      final opts = FirebaseCustomOptions.options ??
          DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(
        options: opts,
      );
      // Try to sign in anonymously if not already signed in.
      await _ensureSignedIn();
      setState(() {
        _initialized = true;
        _status = 'Firebase initialized';
      });
      // initialization complete
    } catch (e) {
      setState(() => _status = 'Init error: $e');
    }
  }

  Future<void> _ensureSignedIn() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        // Attempt anonymous sign-in (requires Anonymous sign-in enabled in Firebase Console)
        final cred = await auth.signInAnonymously();
        _uid = cred.user?.uid;
      } else {
        _uid = auth.currentUser?.uid;
      }
      setState(() {});
    } catch (e) {
      // don't block initialization — just record error for debugging
      _lastError = 'Auth error: $e';
      setState(() {});
    }
  }

  Future<void> _sendData() async {
    // Send to Realtime Database instead of Firestore
    final baseUrl = RealtimeDbService.defaultBaseUrl;
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    if (name.isEmpty || ageText.isEmpty) {
      return _showMessage('Please fill both');
    }
    final age = int.tryParse(ageText);
    if (age == null) return _showMessage('Age must be a whole number');

    setState(() => _loading = true);
    try {
      // Patch at /test/user (creates keys if not present)
      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/',
        data: {
          'light': name,
          'AC': age,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      setState(() => _loading = false);
      _showMessage('Sent to Realtime DB');
      _nameController.clear();
      _ageController.clear();
    } catch (e) {
      setState(() => _loading = false);
      _lastError = 'Realtime DB error: $e';
      _showMessage('Error: $e');
      setState(() {});
    }
  }

  // Send the single light state to RTDB and measure latency in microseconds
  Future<void> _sendLightAndMeasureLatency() async {
    if (!_initialized) return _showMessage('Firebase not initialized');
    if (!_isOnline) return _showMessage('No connectivity');

    setState(() => _loading = true);
    try {
      final baseUrl = RealtimeDbService.defaultBaseUrl;

      // record start in microseconds
      final int start = DateTime.now().microsecondsSinceEpoch;

      // Use PUT to set the /light node (this corresponds to RTDB set())
      await RealtimeDbService.put(
        baseUrl: baseUrl,
        path: '/light',
        data: {
          'state': _lightOn ? 'on' : 'off',
          'ts': DateTime.now().millisecondsSinceEpoch, // epoch ms
          'datetime': DateTime.now().toIso8601String(), // human-readable
        },
      );

      // record end in microseconds immediately after completion
      final int end = DateTime.now().microsecondsSinceEpoch;
      final int latency = end - start; // microseconds

      // Persist measured latency at root/latency (so it's visible in RTDB) using patch
      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/',
        data: {
          'latency': latency, // microseconds (kept for compatibility)
          'latency_us': latency,
          'latency_ms': latency ~/ 1000,
        },
      );

      setState(() {
        _latencyMicros = latency;
      });

      _showMessage('Light state sent — latency ${latency} μs');
    } catch (e) {
      _lastError = 'Realtime DB error: $e';
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Small probe writer to help diagnose permission issues
  Future<void> _probeWrite() async {
    if (!_initialized) return _showMessage('Firebase not initialized');
    try {
      final baseUrl = RealtimeDbService.defaultBaseUrl;
      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/probe',
        data: {'ok': true, 'time': DateTime.now().toIso8601String()},
      );
      _showMessage('Probe write OK (RTDB)');
    } catch (e) {
      _lastError = 'Probe write error: $e';
      setState(() {});
      _showMessage('Probe failed');
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (years)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _sendData,
              icon: _loading ? const SizedBox.shrink() : const Icon(Icons.send),
              label: Text(_loading ? 'Sending...' : 'Send to Realtime DB'),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            // Simplified control: single light toggle + latency measurement
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Light Control',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_lightOn ? 'On' : 'Off',
                                  style: const TextStyle(fontSize: 18)),
                              Switch(
                                value: _lightOn,
                                onChanged: (v) => setState(() => _lightOn = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Text(
                          //     'Latency: ${_latencyMicros != null ? '${_latencyMicros} μs' : '—'}'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_loading || !_isOnline)
                      ? null
                      : _sendLightAndMeasureLatency,
                  child: Text(
                      _loading ? 'Sending...' : 'Send light & measure latency'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Notes:'),
            const SizedBox(height: 8),
            const Text(
                '- This screen initializes Firebase for web/android/ios using firebase_options.dart.'),
            const Text(
                '- It writes to Realtime Database path /test/user with fields: name(string), age(number), updatedAt(ISO string).'),
            const SizedBox(height: 8),
            const Text(
                '- If you see errors, check your Realtime Database URL, rules, and optional RTDB_AUTH (use --dart-define).'),
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            // Show which FirebaseOptions are in use to help debugging
            Builder(builder: (ctx) {
              // Access DefaultFirebaseOptions.currentPlatform safely
              String pid = '(unknown)';
              String api = '(unknown)';
              try {
                final opts = DefaultFirebaseOptions.currentPlatform;
                pid = opts.projectId;
                api = opts.apiKey;
              } catch (_) {}
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firebase projectId: $pid'),
                  Text(
                      'Firebase apiKey: ${api.substring(0, api.length > 8 ? 8 : api.length)}...'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _initialized ? _probeWrite : null,
                    child: const Text('Try probe write to test/probe'),
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Text('Auth uid: ${_uid ?? "(not signed in)"}'),
            if (_lastError != null) ...[
              const SizedBox(height: 8),
              Text('Last error: $_lastError',
                  style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
