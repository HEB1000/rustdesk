// R-TECH DESK: the data behind the main screen - the computers I connected to, the screen
// pictures on their tiles, groups and notes, and the chosen design.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const List<String> kRtechGroups = ['בית', 'עבודה', 'משפחה', 'לקוחות'];

const Map<String, Color> kRtechGroupColors = {
  'בית': Color(0xFF1565C0),
  'עבודה': Color(0xFF00796B),
  'משפחה': Color(0xFF6A1B9A),
  'לקוחות': Color(0xFFD84315),
};

const Map<String, String> kRtechDesigns = {
  'f1': 'ע1 · לוח טכנאי',
  'f4': 'ע4 · כרטיסי עבודה',
  'n2': 'נ2 · נאומורפי כהה',
  'simple': 'מצב פשוט לקרובים',
  'orig': 'המסך המקורי של RustDesk',
};

// The number and the code always have their own colors, different from each other and from
// the rest of the text.
const Color kRtechIdOnDark = Color(0xFFFFB74D);
const Color kRtechCodeOnDark = Color(0xFF4FC3F7);
const Color kRtechIdOnLight = Color(0xFFA9622B);
const Color kRtechCodeOnLight = Color(0xFF1565C0);
const Color kRtechOnline = Color(0xFF2E9E4F);
const Color kRtechOffline = Color(0xFF9E9E9E);

class RtechExtra {
  String group;
  String note;
  RtechExtra({this.group = '', this.note = ''});
}

class RtechThumb {
  final DateTime time;
  final Uint8List bytes;
  RtechThumb(this.time, this.bytes);
}

class RtechData extends ChangeNotifier {
  RtechData._();
  static final RtechData instance = RtechData._();

  static const String _designKey = 'rtech-design';
  static const String _extrasKey = 'rtech-peers';

  String design = 'f1';
  String groupFilter = '';
  String statusFilter = '';
  String search = '';
  String selectedId = '';
  final TextEditingController connectController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  final Map<String, RtechExtra> _extras = {};
  final Map<String, RtechThumb> _thumbs = {};
  String _thumbsDir = '';
  Timer? _timer;
  int _users = 0;
  int _ticks = 0;
  bool _refreshing = false;

  Peers get peers => gFFI.recentPeersModel;

  void attach() {
    _users += 1;
    if (_users > 1) return;
    final saved = bind.mainGetLocalOption(key: _designKey);
    design = kRtechDesigns.containsKey(saved) ? saved : 'f1';
    _loadExtras();
    try {
      _thumbsDir = bind.mainGetRtechThumbsDir();
    } catch (_) {
      _thumbsDir = '';
    }
    peers.addListener(_onPeers);
    bind.mainLoadRecentPeers();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void detach() {
    _users -= 1;
    if (_users > 0) return;
    _users = 0;
    _timer?.cancel();
    _timer = null;
    peers.removeListener(_onPeers);
  }

  void _onPeers() {
    if (peers.event == UpdateEvent.load) {
      _queryOnlines();
      _refreshThumbs();
    }
  }

  void _tick() {
    _ticks += 1;
    _refreshThumbs();
    if (_ticks % 2 == 0) _queryOnlines();
    if (_ticks % 12 == 0) bind.mainLoadRecentPeers();
  }

  void reload() {
    bind.mainLoadRecentPeers();
  }

  void _queryOnlines() {
    final ids =
        peers.peers.map((p) => p.id).where((id) => id.isNotEmpty).toList();
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  // ---------------------------------------------------------------- design and filters

  void setDesign(String value) {
    if (!kRtechDesigns.containsKey(value)) return;
    design = value;
    bind.mainSetLocalOption(key: _designKey, value: value);
    notifyListeners();
  }

  void setGroupFilter(String value) {
    groupFilter = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    statusFilter = value;
    notifyListeners();
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void select(String id) {
    if (selectedId == id) return;
    selectedId = id;
    notifyListeners();
  }

  List<Peer> visiblePeers() {
    final query = search.trim().toLowerCase();
    final digits = query.replaceAll(' ', '');
    return peers.peers.where((p) {
      if (p.id.isEmpty) return false;
      final extra = extraOf(p.id);
      if (groupFilter.isNotEmpty && extra.group != groupFilter) return false;
      if (statusFilter == 'on' && !p.online) return false;
      if (statusFilter == 'off' && p.online) return false;
      if (query.isEmpty) return true;
      return nameOf(p).toLowerCase().contains(query) ||
          (digits.isNotEmpty && p.id.contains(digits)) ||
          extra.note.toLowerCase().contains(query) ||
          p.hostname.toLowerCase().contains(query);
    }).toList();
  }

  int get onlineCount => peers.peers.where((p) => p.online).length;

  static String nameOf(Peer p) {
    if (p.alias.isNotEmpty) return p.alias;
    if (p.hostname.isNotEmpty) return p.hostname;
    return formatID(p.id);
  }

  static String statusOf(Peer p) => p.online ? 'מחובר לרשת' : 'כבוי';

  // ---------------------------------------------------------------- groups and notes

  RtechExtra extraOf(String id) => _extras[id] ?? RtechExtra();

  Future<void> setGroup(String id, String group) async {
    final extra = _extras.putIfAbsent(id, () => RtechExtra());
    extra.group = group;
    await _saveExtras();
    notifyListeners();
  }

  Future<void> setNote(String id, String note) async {
    final extra = _extras.putIfAbsent(id, () => RtechExtra());
    extra.note = note;
    await _saveExtras();
    notifyListeners();
  }

  void _loadExtras() {
    _extras.clear();
    try {
      final text = bind.mainGetLocalOption(key: _extrasKey);
      if (text.isEmpty) return;
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (key is String && value is Map) {
            _extras[key] = RtechExtra(
                group: '${value['g'] ?? ''}', note: '${value['n'] ?? ''}');
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveExtras() async {
    final map = <String, dynamic>{};
    _extras.forEach((key, value) {
      if (value.group.isNotEmpty || value.note.isNotEmpty) {
        map[key] = {'g': value.group, 'n': value.note};
      }
    });
    await bind.mainSetLocalOption(key: _extrasKey, value: jsonEncode(map));
  }

  // ---------------------------------------------------------------- screen pictures

  static String thumbFileName(String id) =>
      '${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.png';

  RtechThumb? thumbOf(String id) => _thumbs[id];

  String lastSeen(String id) {
    final t = _thumbs[id]?.time;
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final days = today.difference(day).inDays;
    if (days <= 0) return 'היום, $hm';
    if (days == 1) return 'אתמול, $hm';
    if (days < 7) return 'לפני $days ימים';
    return '${t.day}.${t.month}.${t.year}';
  }

  Future<void> _refreshThumbs() async {
    if (_thumbsDir.isEmpty || _refreshing) return;
    _refreshing = true;
    var changed = false;
    try {
      for (final p in List<Peer>.from(peers.peers)) {
        if (p.id.isEmpty) continue;
        final file = File(
            '$_thumbsDir${Platform.pathSeparator}${thumbFileName(p.id)}');
        try {
          if (!await file.exists()) {
            if (_thumbs.remove(p.id) != null) changed = true;
            continue;
          }
          final time = await file.lastModified();
          final old = _thumbs[p.id];
          if (old == null || old.time != time) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              _thumbs[p.id] = RtechThumb(time, bytes);
              changed = true;
            }
          }
        } catch (_) {}
      }
    } finally {
      _refreshing = false;
    }
    if (changed) notifyListeners();
  }

  Future<void> forgetThumb(String id) async {
    _thumbs.remove(id);
    if (_thumbsDir.isEmpty) return;
    try {
      final file =
          File('$_thumbsDir${Platform.pathSeparator}${thumbFileName(id)}');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
