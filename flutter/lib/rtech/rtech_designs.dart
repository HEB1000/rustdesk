// R-TECH DESK: the three main-screen designs Moti chose.
//   ע1 "לוח טכנאי"    - flat, dark side panel, big tiles
//   ע4 "כרטיסי עבודה" - flat, icon rail, wide cards with notes and buttons
//   נ2 "נאומורפי כהה" - soft shadows on a dark surface
// The number is always orange-copper and the code always blue.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import 'rtech_brand.dart';
import 'rtech_data.dart';
import 'rtech_home.dart';

// ------------------------------------------------------------------ shared helpers

Widget _clickable(
    {required Widget child,
    VoidCallback? onTap,
    GestureTapDownCallback? onTapDown}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: onTapDown,
      child: child,
    ),
  );
}

/// Shrinks a long number or code instead of breaking it into two lines.
Widget _fit(Widget child) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: child);

Widget _flatButton(
    {required String text,
    IconData? icon,
    required Color back,
    required Color fore,
    Color? border,
    required VoidCallback onTap,
    double height = 46,
    double fontSize = 15,
    double pad = 16}) {
  return _clickable(
    onTap: onTap,
    child: Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: pad),
      decoration: BoxDecoration(
          color: back,
          border: border == null ? null : Border.all(color: border, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, size: fontSize + 3, color: fore),
        if (icon != null && text.isNotEmpty) const SizedBox(width: 7),
        if (text.isNotEmpty)
          Text(text,
              style: TextStyle(
                  color: fore, fontWeight: FontWeight.w800, fontSize: fontSize)),
      ]),
    ),
  );
}

Widget _field(
    {required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onSubmitted,
    ValueChanged<String>? onChanged,
    required Color text,
    required Color hintColor,
    IconData? icon,
    Color? iconColor}) {
  const none = InputBorder.none;
  return Row(children: [
    if (icon != null) Icon(icon, size: 20, color: iconColor),
    if (icon != null) const SizedBox(width: 8),
    Expanded(
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        cursorColor: text,
        style: TextStyle(color: text, fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          border: none,
          enabledBorder: none,
          focusedBorder: none,
          disabledBorder: none,
          errorBorder: none,
          focusedErrorBorder: none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    ),
  ]);
}

Widget _groupTag(String group) {
  return Container(
    margin: const EdgeInsetsDirectional.only(start: 6),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    color: kRtechGroupColors[group] ?? Colors.grey,
    child: Text(group,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

// ------------------------------------------------------------------ ע1 · לוח טכנאי

class RtechF1 extends StatelessWidget {
  const RtechF1({Key? key}) : super(key: key);

  static const Color _canvas = Color(0xFFE0E0E0);
  static const Color _side = Color(0xFF263238);
  static const Color _cBox = Color(0xFF37474F);
  static const Color _ink = Color(0xFF1B1F23);
  static const Color _muted = Color(0xFF5F6B73);
  static const Color _chip = Color(0xFFCFD8DC);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _navText = Color(0xFFCFD8DC);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _canvas,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sidePanel(context),
        Expanded(child: _mainArea(context)),
      ]),
    );
  }

  Widget _sidePanel(BuildContext context) {
    return Container(
      width: 252,
      color: _side,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Align(
            alignment: AlignmentDirectional.centerStart,
            child: RtechBrand(dark: true)),
        const SizedBox(height: 16),
        RtechMine(
          builder: (context, id, code) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(
                'המספר שלך',
                Icons.copy,
                RtechMine.copyId,
                _fit(Text(id,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: kRtechIdOnDark))),
                onValue: RtechMine.copyId,
              ),
              const SizedBox(height: 10),
              _box(
                code.isEmpty ? 'קוד' : 'קוד חד-פעמי',
                code.isEmpty ? null : Icons.refresh,
                RtechMine.newCode,
                code.isEmpty
                    ? const Text('קוד קבוע (בהגדרות)',
                        style: TextStyle(fontSize: 15, color: kRtechCodeOnDark))
                    : _fit(Text(code,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 21,
                            fontFamily: 'Consolas',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: kRtechCodeOnDark))),
                onValue: RtechMine.copyCode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _nav(Icons.grid_view, 'המחשבים שלי', active: true),
        _nav(Icons.palette_outlined, 'עיצוב המסך',
            onTapAt: (p) => rtechDesignMenu(context, p)),
        _nav(Icons.settings_outlined, 'הגדרות', onTap: rtechOpenSettings),
        _nav(Icons.info_outline, 'אודות',
            onTap: () => rtechShowAbout(context)),
        const Spacer(),
        const RtechServerState(
            readyColor: Color(0xFF66BB6A), otherColor: Color(0xFFFFB74D)),
        const SizedBox(height: 3),
        const Text('מבוסס RustDesk · AGPL-3.0',
            style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
      ]),
    );
  }

  Widget _box(String label, IconData? icon, VoidCallback onIcon, Widget value,
      {VoidCallback? onValue}) {
    return Container(
      color: _cBox,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5)))),
          if (icon != null)
            _clickable(
                onTap: onIcon,
                child: Icon(icon, size: 17, color: const Color(0xFFECEFF1))),
        ]),
        const SizedBox(height: 4),
        onValue == null ? value : _clickable(onTap: onValue, child: value),
      ]),
    );
  }

  Widget _nav(IconData icon, String text,
      {bool active = false,
      VoidCallback? onTap,
      void Function(Offset position)? onTapAt}) {
    final color = active ? Colors.white : _navText;
    return _clickable(
      onTap: onTap,
      onTapDown: onTapAt == null ? null : (d) => onTapAt(d.globalPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        color: active ? kRtechAccent : Colors.transparent,
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Text(text,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _mainArea(BuildContext context) {
    final data = RtechData.instance;
    final list = data.visiblePeers();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _side, width: 2)),
              child: _field(
                controller: data.connectController,
                hint: 'מספר מחשב, למשל 731 204 586',
                onSubmitted: (v) => rtechConnect(context, v),
                text: _ink,
                hintColor: const Color(0xFF90A4AE),
                icon: Icons.desktop_windows_outlined,
                iconColor: const Color(0xFF78909C),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _flatButton(
              text: 'התחבר',
              icon: Icons.arrow_forward,
              back: _green,
              fore: Colors.white,
              onTap: () => rtechConnect(context, data.connectController.text)),
          const SizedBox(width: 8),
          _flatButton(
              text: 'קבצים',
              icon: Icons.folder_outlined,
              back: Colors.transparent,
              fore: _ink,
              border: _side,
              onTap: () => rtechConnect(context, data.connectController.text,
                  files: true)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Text('המחשבים שלי',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(width: 8),
          Container(
            color: _side,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Text('${data.peers.peers.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: RtechGroupChips(
                activeBack: _side,
                activeText: Colors.white,
                back: _chip,
                text: _ink),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: list.isEmpty
              ? const RtechEmpty(color: _muted)
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 14),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisExtent: 232,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _tile(list[i]),
                ),
        ),
        Container(
          height: 32,
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _chip, width: 2))),
          child: const Row(children: [
            Text('לחיצה כפולה על משבצת — חיבור מיידי',
                style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
            SizedBox(width: 18),
            Flexible(
              child: Text('לחיצה ימנית — קבצים, שם, קבוצה, הערה, הסרה',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tile(Peer p) {
    final data = RtechData.instance;
    final selected = data.selectedId == p.id;
    final extra = data.extraOf(p.id);
    final last = data.lastSeen(p.id);
    final status = RtechData.statusOf(p);
    return RtechTileGestures(
      peer: p,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
                color: selected ? kRtechAccent : Colors.white, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 5, color: p.online ? kRtechOnline : kRtechOffline),
          Expanded(child: RtechThumbView(peer: p)),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(RtechData.nameOf(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                    ),
                    if (extra.group.isNotEmpty) _groupTag(extra.group),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.online ? kRtechOnline : kRtechOffline)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(last.isEmpty ? status : '$status · $last',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _muted)),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    Text(formatID(p.id),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF263238))),
                    const Spacer(),
                    if (p.hash.isNotEmpty)
                      const Tooltip(
                          message: 'הקוד שמור — לחיצה כפולה מתחברת מיד',
                          child: Icon(Icons.key, size: 16, color: kRtechAccent)),
                    if (extra.note.isNotEmpty)
                      const Padding(
                          padding: EdgeInsetsDirectional.only(start: 8),
                          child: Icon(Icons.sticky_note_2_outlined,
                              size: 16, color: Color(0xFF546E7A))),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ ע4 · כרטיסי עבודה

class RtechF4 extends StatelessWidget {
  const RtechF4({Key? key}) : super(key: key);

  static const Color _canvas = Color(0xFFE0E0E0);
  static const Color _dark = Color(0xFF263238);
  static const Color _ink = Color(0xFF1B1F23);
  static const Color _muted = Color(0xFF546E7A);
  static const Color _chip = Color(0xFFCFD8DC);
  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _canvas,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(context),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _rail(context),
            Expanded(child: _main(context)),
          ]),
        ),
      ]),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _dark, width: 3))),
      child: Row(children: [
        const RtechBrand(dark: false, logo: 40),
        const SizedBox(width: 22),
        RtechMine(
          builder: (context, id, code) =>
              Row(mainAxisSize: MainAxisSize.min, children: [
            _mineCell('המספר שלך', id, kRtechIdOnLight,
                mono: false, ltr: true, onTap: RtechMine.copyId),
            code.isEmpty
                ? _mineCell('קוד', 'קבוע', kRtechCodeOnLight,
                    mono: false, ltr: false, onTap: () {})
                : _mineCell('קוד חד-פעמי', code, kRtechCodeOnLight,
                    mono: true, ltr: true, onTap: RtechMine.copyCode),
            const SizedBox(width: 6),
            _squareIcon(Icons.copy, 'העתק מספר וקוד', RtechMine.copyBoth),
            if (code.isNotEmpty) const SizedBox(width: 4),
            if (code.isNotEmpty)
              _squareIcon(Icons.refresh, 'קוד חדש', RtechMine.newCode),
          ]),
        ),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _fit(const RtechServerState(
                readyColor: _green, otherColor: Color(0xFFE65100))),
          ),
        ),
      ]),
    );
  }

  Widget _mineCell(String label, String value, Color color,
      {required bool mono, required bool ltr, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: const BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: _chip, width: 2))),
      child: _clickable(
        onTap: onTap,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
              Text(value,
                  textDirection: ltr ? TextDirection.ltr : null,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: mono ? 2 : 0.5,
                      fontFamily: mono ? 'Consolas' : null,
                      color: color)),
            ]),
      ),
    );
  }

  Widget _squareIcon(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: _clickable(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          color: _dark,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _rail(BuildContext context) {
    return Container(
      width: 76,
      color: _dark,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        _railItem(Icons.grid_view, 'מחשבים', active: true),
        _railItem(Icons.palette_outlined, 'עיצוב',
            onTapAt: (p) => rtechDesignMenu(context, p)),
        _railItem(Icons.settings_outlined, 'הגדרות', onTap: rtechOpenSettings),
        _railItem(Icons.info_outline, 'אודות',
            onTap: () => rtechShowAbout(context)),
      ]),
    );
  }

  Widget _railItem(IconData icon, String text,
      {bool active = false,
      VoidCallback? onTap,
      void Function(Offset position)? onTapAt}) {
    final color = active ? Colors.white : const Color(0xFFB0BEC5);
    return _clickable(
      onTap: onTap,
      onTapDown: onTapAt == null ? null : (d) => onTapAt(d.globalPosition),
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: active ? kRtechAccent : Colors.transparent,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _main(BuildContext context) {
    final data = RtechData.instance;
    final list = data.visiblePeers();
    void connectTyped() {
      final digits = trimID(data.searchController.text);
      if (RegExp(r'^\d{6,}$').hasMatch(digits)) {
        rtechConnect(context, digits);
      } else {
        showToast('הקלד בשדה מספר מחשב (לפחות 6 ספרות) ולחץ שוב');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 42,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _field(
                controller: data.searchController,
                hint: 'חיפוש לפי שם, מספר או הערה · או מספר מחשב חדש ו-Enter',
                onChanged: data.setSearch,
                onSubmitted: (_) => connectTyped(),
                text: _ink,
                hintColor: const Color(0xFF90A4AE),
                icon: Icons.search,
                iconColor: const Color(0xFF78909C),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _statusSeg(data),
          const SizedBox(width: 10),
          _flatButton(
              text: 'חיבור לפי מספר',
              icon: Icons.add,
              back: _green,
              fore: Colors.white,
              height: 42,
              fontSize: 14,
              onTap: connectTyped),
        ]),
        const SizedBox(height: 10),
        const RtechGroupChips(
            activeBack: _dark, activeText: Colors.white, back: _chip, text: _ink),
        const SizedBox(height: 12),
        Expanded(
          child: list.isEmpty
              ? const RtechEmpty(color: _muted)
              : LayoutBuilder(builder: (context, constraints) {
                  final columns = math.max(1, (constraints.maxWidth / 440).floor());
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 14),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 152,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _card(context, list[i]),
                  );
                }),
        ),
        Container(
          height: 30,
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _chip, width: 2))),
          child: const Row(children: [
            Flexible(
              child: Text(
                  'לחיצה כפולה על כרטיס — חיבור מיידי · לחיצה ימנית — עוד פעולות',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
            ),
            SizedBox(width: 14),
            Text('מבוסס RustDesk · AGPL-3.0',
                style: TextStyle(fontSize: 12, color: Color(0xFF78909C))),
          ]),
        ),
      ]),
    );
  }

  Widget _statusSeg(RtechData data) {
    Widget seg(String value, String label, int count) {
      final active = data.statusFilter == value;
      return _clickable(
        onTap: () => data.setStatusFilter(value),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: active ? _dark : _chip,
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _ink)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: active ? Colors.white24 : Colors.black12,
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11, color: active ? Colors.white : _ink)),
            ),
          ]),
        ),
      );
    }

    final all = data.peers.peers.length;
    final on = data.onlineCount;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      seg('', 'הכול', all),
      seg('on', 'מחוברים', on),
      seg('off', 'כבויים', all - on),
    ]);
  }

  Widget _card(BuildContext context, Peer p) {
    final data = RtechData.instance;
    final selected = data.selectedId == p.id;
    final extra = data.extraOf(p.id);
    final last = data.lastSeen(p.id);
    return RtechTileGestures(
      peer: p,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
                color: selected ? kRtechAccent : Colors.white, width: 2)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 168, height: 105, child: RtechThumbView(peer: p)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(RtechData.nameOf(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                    ),
                    if (extra.group.isNotEmpty) _groupTag(extra.group),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: p.online ? _green : kRtechOffline,
                      child: Text(p.online ? 'מחובר' : 'כבוי',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(formatID(p.id),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF263238))),
                    if (p.hash.isNotEmpty) const SizedBox(width: 8),
                    if (p.hash.isNotEmpty)
                      const Icon(Icons.key, size: 14, color: kRtechAccent),
                    if (p.hash.isNotEmpty) const SizedBox(width: 3),
                    if (p.hash.isNotEmpty)
                      const Text('קוד שמור',
                          style: TextStyle(fontSize: 12, color: kRtechAccent)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.schedule, size: 14, color: _muted),
                    const SizedBox(width: 5),
                    Text('חיבור אחרון: ${last.isEmpty ? '—' : last}',
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        size: 14, color: _muted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                          extra.note.isEmpty
                              ? 'אין הערה · לחיצה ימנית להוספה'
                              : extra.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: extra.note.isEmpty
                                  ? const Color(0xFF9EA7AD)
                                  : const Color(0xFF37474F))),
                    ),
                  ]),
                  const Spacer(),
                  _fit(Row(mainAxisSize: MainAxisSize.min, children: [
                    _flatButton(
                        text: 'התחבר',
                        icon: Icons.arrow_forward,
                        back: _green,
                        fore: Colors.white,
                        height: 30,
                        fontSize: 12.5,
                        pad: 12,
                        onTap: () => rtechConnect(context, p.id)),
                    const SizedBox(width: 6),
                    _flatButton(
                        text: 'קבצים',
                        icon: Icons.folder_outlined,
                        back: Colors.transparent,
                        fore: _ink,
                        border: _dark,
                        height: 30,
                        fontSize: 12.5,
                        pad: 10,
                        onTap: () =>
                            rtechConnect(context, p.id, files: true)),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'הערת טכנאי',
                      child: _flatButton(
                          text: '',
                          icon: Icons.edit_note,
                          back: Colors.transparent,
                          fore: _ink,
                          border: _dark,
                          height: 30,
                          fontSize: 13,
                          pad: 7,
                          onTap: () => _editNote(context, p)),
                    ),
                  ])),
                ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, Peer p) async {
    final data = RtechData.instance;
    final text = await rtechAskText(context,
        'הערת טכנאי · ${RtechData.nameOf(p)}', data.extraOf(p.id).note,
        hint: 'מה תוקן ומתי, למשל: הוחלף ספק כוח · 2.11', lines: 3);
    if (text != null) await data.setNote(p.id, text);
  }
}

// ------------------------------------------------------------------ נ2 · נאומורפי כהה

class RtechN2 extends StatelessWidget {
  const RtechN2({Key? key}) : super(key: key);

  static const Color _bg = Color(0xFF2A2D33);
  static const Color _shadowDark = Color(0xFF1C1E22);
  static const Color _shadowLight = Color(0xFF383C44);
  static const Color _bright = Color(0xFFF1F3F5);
  static const Color _soft = Color(0xFFAEB6C2);
  static const Color _muted = Color(0xFF8D96A3);
  static const Color _id = Color(0xFFD98C4F);
  static const Color _code = Color(0xFF64B5F6);
  static const Color _led = Color(0xFF3DDC84);

  static BoxDecoration _raised(double radius, {double depth = 7}) {
    return BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
            color: _shadowDark,
            offset: Offset(depth, depth),
            blurRadius: depth * 2),
        BoxShadow(
            color: _shadowLight,
            offset: Offset(-depth, -depth),
            blurRadius: depth * 2),
      ],
    );
  }

  static BoxDecoration _sunken(double radius, {Color? border}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202227), Color(0xFF30333A)]),
      border: border == null ? null : Border.all(color: border, width: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.all(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 262, child: _side(context)),
        const SizedBox(width: 22),
        Expanded(child: _main(context)),
      ]),
    );
  }

  Widget _side(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _raised(24),
        child: RtechMine(
          builder: (context, id, code) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brand(context),
              const SizedBox(height: 16),
              const Text('המספר שלך',
                  style: TextStyle(fontSize: 12, color: _muted)),
              _clickable(
                onTap: RtechMine.copyId,
                child: _fit(Text(id,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _id,
                        shadows: [
                          Shadow(
                              color: _id.withOpacity(0.35), blurRadius: 14)
                        ]))),
              ),
              const SizedBox(height: 12),
              Text(code.isEmpty ? 'קוד' : 'קוד חד-פעמי',
                  style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: _clickable(
                    onTap: RtechMine.copyCode,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: _sunken(14),
                      alignment: AlignmentDirectional.centerStart,
                      child: code.isEmpty
                          ? const Text('קוד קבוע',
                              style: TextStyle(color: _code))
                          : _fit(Text(code,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                  fontSize: 19,
                                  fontFamily: 'Consolas',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  color: _code,
                                  shadows: [
                                    Shadow(
                                        color: _code.withOpacity(0.35),
                                        blurRadius: 12)
                                  ]))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (code.isNotEmpty)
                  _round(Icons.refresh, 'קוד חדש', RtechMine.newCode),
                if (code.isNotEmpty) const SizedBox(width: 8),
                _round(Icons.copy, 'העתק מספר וקוד', RtechMine.copyBoth),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      _pill(Icons.grid_view, 'המחשבים שלי', active: true),
      _pill(Icons.palette_outlined, 'עיצוב המסך',
          onTapAt: (p) => rtechDesignMenu(context, p)),
      _pill(Icons.settings_outlined, 'הגדרות', onTap: rtechOpenSettings),
      _pill(Icons.info_outline, 'אודות', onTap: () => rtechShowAbout(context)),
      const Spacer(),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RtechServerState(readyColor: _led, otherColor: _id),
          SizedBox(height: 3),
          Text('מבוסס RustDesk · AGPL-3.0',
              style: TextStyle(fontSize: 11, color: _muted)),
        ]),
      ),
    ]);
  }

  Widget _brand(BuildContext context) {
    return _clickable(
      onTap: () => rtechShowAbout(context),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: _raised(27, depth: 4),
          alignment: Alignment.center,
          child: Image.asset('assets/icon.png', width: 40, height: 40),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(kRtechDisplayName,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _bright)),
            if (kRtechSubtitle.isNotEmpty)
              const Text(kRtechSubtitle,
                  style: TextStyle(fontSize: 11, color: _muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _round(IconData icon, String tip, VoidCallback onTap,
      {Color color = _soft}) {
    return Tooltip(
      message: tip,
      child: _clickable(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: _raised(21, depth: 3),
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text,
      {bool active = false,
      VoidCallback? onTap,
      void Function(Offset position)? onTapAt}) {
    final color = active ? _id : _soft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _clickable(
        onTap: onTap,
        onTapDown: onTapAt == null ? null : (d) => onTapAt(d.globalPosition),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: active ? _sunken(21) : _raised(21, depth: 3),
          child: Row(children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 10),
            Text(text,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _main(BuildContext context) {
    final data = RtechData.instance;
    final list = data.visiblePeers();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: _sunken(25),
            child: _field(
              controller: data.connectController,
              hint: 'מספר מחשב להתחברות',
              onSubmitted: (v) => rtechConnect(context, v),
              text: _bright,
              hintColor: const Color(0xFF7D8693),
              icon: Icons.desktop_windows_outlined,
              iconColor: const Color(0xFF7D8693),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _clickable(
          onTap: () => rtechConnect(context, data.connectController.text),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 26),
            decoration: _raised(25),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_forward, size: 19, color: _id),
              SizedBox(width: 8),
              Text('התחבר',
                  style: TextStyle(
                      color: _id, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        _round(
            Icons.folder_outlined,
            'העברת קבצים למספר שהוקלד',
            () => rtechConnect(context, data.connectController.text,
                files: true)),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        const Text('המחשבים שלי',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: _bright)),
        const SizedBox(width: 10),
        Text(
            '${data.peers.peers.length} מחשבים · ${data.onlineCount} מחוברים',
            style: const TextStyle(fontSize: 13, color: _muted)),
        const SizedBox(width: 16),
        Expanded(child: _groupPills(data)),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: list.isEmpty
            ? const RtechEmpty(color: _muted)
            : LayoutBuilder(builder: (context, constraints) {
                final columns =
                    math.max(1, (constraints.maxWidth / 230).floor());
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 214,
                      crossAxisSpacing: 22,
                      mainAxisSpacing: 22),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _tile(list[i]),
                );
              }),
      ),
    ]);
  }

  Widget _groupPills(RtechData data) {
    Widget pill(String value, String label) {
      final active = data.groupFilter == value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: _clickable(
          onTap: () => data.setGroupFilter(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: active ? _sunken(16) : _raised(16, depth: 2.5),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? _id : _soft)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Row(children: [
        pill('', 'הכול'),
        for (final group in kRtechGroups) pill(group, group),
      ]),
    );
  }

  Widget _tile(Peer p) {
    final data = RtechData.instance;
    final selected = data.selectedId == p.id;
    final last = data.lastSeen(p.id);
    final extra = data.extraOf(p.id);
    return RtechTileGestures(
      peer: p,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: selected
            ? _sunken(22, border: _id.withOpacity(0.65))
            : _raised(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: _sunken(16),
              child: RtechThumbView(
                  peer: p,
                  radius: 12,
                  placeholder: const Color(0xFF3A3F47)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.online ? _led : const Color(0xFF444952),
                boxShadow: p.online
                    ? const [BoxShadow(color: _led, blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(RtechData.nameOf(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _bright)),
            ),
            if (extra.group.isNotEmpty)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(start: 6),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kRtechGroupColors[extra.group]),
              ),
            if (p.hash.isNotEmpty)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 6),
                child: Icon(Icons.key, size: 15, color: _id),
              ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(formatID(p.id),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _soft)),
            const Spacer(),
            Text(last.isEmpty ? RtechData.statusOf(p) : last,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
        ]),
      ),
    );
  }
}
