// R-TECH DESK: the main screen. It replaces RustDesk's home page (left: this computer,
// right: connect + lists) with tiles of the computers I already connected to, in one of the
// designs Moti chose (ע1, ע4, נ2), a simple screen for relatives, or RustDesk's own screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// common.dart has a Dialog of its own; the dialogs here are Flutter's.
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rtech_brand.dart';
import 'rtech_data.dart';
import 'rtech_designs.dart';

class RtechHome extends StatefulWidget {
  /// RustDesk's own home page, for the "original screen" choice.
  final Widget original;
  const RtechHome({Key? key, required this.original}) : super(key: key);

  @override
  State<RtechHome> createState() => _RtechHomeState();
}

class _RtechHomeState extends State<RtechHome> {
  final RtechData data = RtechData.instance;

  @override
  void initState() {
    super.initState();
    data.attach();
  }

  @override
  void dispose() {
    data.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([data, data.peers]),
      builder: (context, _) {
        if (data.design == 'orig') {
          return Stack(children: [
            Positioned.fill(child: widget.original),
            Positioned(
              left: 10,
              bottom: 10,
              child: ElevatedButton.icon(
                onPressed: () => data.setDesign('f1'),
                icon: const Icon(Icons.grid_view, size: 16),
                label: const Text('מסך R-TECH'),
              ),
            ),
          ]);
        }
        final Widget page;
        switch (data.design) {
          case 'simple':
            page = const RtechSimple();
            break;
          case 'f4':
            page = const RtechF4();
            break;
          case 'n2':
            page = const RtechN2();
            break;
          default:
            page = const RtechF1();
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const RtechInstallBar(),
            Expanded(child: page),
          ]),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ install

/// RustDesk's "install" card lives in the left pane of its own screen, which the R-TECH designs
/// replace: the same choice, as a bar above them (Windows, program not installed or older).
class RtechInstallBar extends StatelessWidget {
  const RtechInstallBar({Key? key}) : super(key: key);

  // Asked once: the screen rebuilds every few seconds, and the answer changes only with a
  // restart of the program (installing restarts it).
  static int _state = -1; // 0 nothing to show, 1 not installed, 2 older version installed

  static int _check() {
    if (!isWindows || bind.isDisableInstallation() || bind.isOutgoingOnly()) {
      return 0;
    }
    if (!bind.mainIsInstalled()) return 1;
    if (bind.mainIsInstalledLowerVersion()) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_state < 0) _state = _check();
    final String text;
    final String button;
    final VoidCallback action;
    if (_state == 1) {
      text = 'התוכנה רצה בלי התקנה. כדי שאפשר יהיה להתחבר למחשב הזה גם אחרי הפעלה מחדש — התקן אותה.';
      button = 'התקנה';
      action = () async {
        await rustDeskWinManager.closeAllSubWindows();
        bind.mainGotoInstall();
      };
    } else if (_state == 2) {
      text = 'במחשב מותקנת גרסה ישנה יותר של התוכנה.';
      button = 'עדכון ההתקנה';
      action = () async {
        await rustDeskWinManager.closeAllSubWindows();
        bind.mainUpdateMe();
      };
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      color: const Color(0xFF3E2A14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.download_for_offline_outlined,
            size: 20, color: Color(0xFFFFB74D)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Color(0xFFFAEEDC), fontSize: 13)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: kRtechAccent, foregroundColor: Colors.white),
          onPressed: action,
          child: Text(button),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ this computer

/// This computer's number and one-time code; rebuilds when they change.
class RtechMine extends StatelessWidget {
  final Widget Function(BuildContext context, String id, String code) builder;
  const RtechMine({Key? key, required this.builder}) : super(key: key);

  static ServerModel get _model => gFFI.serverModel;

  static String id() => _model.serverId.text;

  /// The one-time code, or '' when this computer does not use one.
  static String code() {
    final model = _model;
    final show = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    if (!show) return '';
    final text = model.serverPasswd.text;
    return text == '-' ? '' : text;
  }

  static void copyId() {
    Clipboard.setData(ClipboardData(text: trimID(id())));
    showToast('המספר הועתק');
  }

  static void copyCode() {
    final c = code();
    if (c.isEmpty) return;
    Clipboard.setData(ClipboardData(text: c));
    showToast('הקוד הועתק');
  }

  static void copyBoth() {
    final c = code();
    final text = c.isEmpty ? 'מספר: ${id()}' : 'מספר: ${id()}\nקוד: $c';
    Clipboard.setData(ClipboardData(text: text));
    showToast('המספר והקוד הועתקו');
  }

  static void newCode() {
    bind.mainUpdateTemporaryPassword();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return AnimatedBuilder(
      animation: Listenable.merge([model, model.serverId, model.serverPasswd]),
      builder: (context, _) => builder(context, id(), code()),
    );
  }
}

/// "Ready" when this computer is connected to the server.
class RtechServerState extends StatelessWidget {
  final Color readyColor;
  final Color otherColor;
  final double size;
  const RtechServerState(
      {Key? key,
      required this.readyColor,
      required this.otherColor,
      this.size = 12})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = stateGlobal.svcStatus.value;
      final ready = status == SvcStatus.ready;
      final text = ready
          ? '● מוכן · מחובר לשרת'
          : status == SvcStatus.connecting
              ? '○ מתחבר לשרת…'
              : '○ לא מחובר לשרת';
      return Text(text,
          style: TextStyle(
              color: ready ? readyColor : otherColor,
              fontSize: size,
              fontWeight: FontWeight.w700));
    });
  }
}

// ------------------------------------------------------------------ actions

void rtechConnect(BuildContext context, String id, {bool files = false}) {
  final clean = trimID(id).trim();
  if (clean.isEmpty) {
    showToast('הקלד מספר מחשב');
    return;
  }
  connect(context, clean, isFileTransfer: files);
}

RelativeRect _menuPlace(BuildContext context, Offset position) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return RelativeRect.fromRect(
      position & const Size(1, 1), Offset.zero & overlay.size);
}

PopupMenuItem<String> _menuItem(String value, IconData icon, String text,
    {Color? color}) {
  return PopupMenuItem<String>(
    value: value,
    height: 38,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color)),
      ]),
    ),
  );
}

Future<void> rtechDesignMenu(BuildContext context, Offset position) async {
  final data = RtechData.instance;
  final choice = await showMenu<String>(
    context: context,
    position: _menuPlace(context, position),
    items: [
      for (final entry in kRtechDesigns.entries)
        _menuItem(
            entry.key,
            entry.key == data.design
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            entry.value),
    ],
  );
  if (choice != null) data.setDesign(choice);
}

Future<void> rtechTileMenu(
    BuildContext context, Peer peer, Offset position) async {
  final data = RtechData.instance;
  final extra = data.extraOf(peer.id);
  final choice = await showMenu<String>(
    context: context,
    position: _menuPlace(context, position),
    items: [
      _menuItem('connect', Icons.login, 'התחבר'),
      _menuItem('files', Icons.folder_outlined, 'העברת קבצים'),
      const PopupMenuDivider(),
      _menuItem('rename', Icons.edit_outlined, 'שינוי שם'),
      _menuItem('group', Icons.label_outline,
          extra.group.isEmpty ? 'קבוצה…' : 'קבוצה: ${extra.group}'),
      _menuItem('note', Icons.sticky_note_2_outlined,
          extra.note.isEmpty ? 'הוספת הערה' : 'עריכת ההערה'),
      if (peer.hash.isNotEmpty)
        _menuItem('forget', Icons.lock_open, 'לשכוח את הקוד השמור'),
      const PopupMenuDivider(),
      _menuItem('remove', Icons.delete_outline, 'הסרה מהרשימה',
          color: Colors.red),
    ],
  );
  if (choice == null || !context.mounted) return;
  final name = RtechData.nameOf(peer);
  switch (choice) {
    case 'connect':
      rtechConnect(context, peer.id);
      break;
    case 'files':
      rtechConnect(context, peer.id, files: true);
      break;
    case 'rename':
      final text = await rtechAskText(context, 'שם למחשב', peer.alias,
          hint: 'למשל: אבא · נייד');
      if (text != null) {
        await bind.mainSetPeerAlias(id: peer.id, alias: text);
        data.reload();
      }
      break;
    case 'group':
      final group = await rtechAskGroup(context, extra.group);
      if (group != null) await data.setGroup(peer.id, group);
      break;
    case 'note':
      final text = await rtechAskText(context, 'הערת טכנאי · $name', extra.note,
          hint: 'מה תוקן ומתי, למשל: הוחלף ספק כוח · 2.11', lines: 3);
      if (text != null) await data.setNote(peer.id, text);
      break;
    case 'forget':
      await bind.mainForgetPassword(id: peer.id);
      showToast('הקוד השמור נמחק');
      data.reload();
      break;
    case 'remove':
      final yes = await rtechConfirm(context, 'להסיר את "$name" מהרשימה?',
          'המחשב יימחק מהמשבצות יחד עם הקוד השמור, ההערה והתמונה שלו.');
      if (yes) {
        await bind.mainRemovePeer(id: peer.id);
        await data.setNote(peer.id, '');
        await data.setGroup(peer.id, '');
        await data.forgetThumb(peer.id);
        data.reload();
      }
      break;
  }
}

// ------------------------------------------------------------------ dialogs

Future<String?> rtechAskText(BuildContext context, String title, String initial,
    {String hint = '', int lines = 1}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: lines,
            maxLines: lines,
            decoration: InputDecoration(hintText: hint),
            onSubmitted:
                lines == 1 ? (v) => Navigator.of(ctx).pop(v.trim()) : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ביטול')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('שמירה')),
        ],
      ),
    ),
  );
}

Future<String?> rtechAskGroup(BuildContext context, String current) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SimpleDialog(
        title: const Text('קבוצה', style: TextStyle(fontSize: 18)),
        children: [
          for (final group in ['', ...kRtechGroups])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(group),
              child: Row(children: [
                Container(
                  width: 14,
                  height: 14,
                  color: group.isEmpty
                      ? Colors.transparent
                      : kRtechGroupColors[group],
                ),
                const SizedBox(width: 10),
                Text(group.isEmpty ? 'בלי קבוצה' : group,
                    style: TextStyle(
                        fontWeight: group == current
                            ? FontWeight.w800
                            : FontWeight.w400)),
              ]),
            ),
        ],
      ),
    ),
  );
}

Future<bool> rtechConfirm(
    BuildContext context, String title, String text) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Text(text),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ביטול')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('הסרה')),
        ],
      ),
    ),
  );
  return result == true;
}

/// "About": a click anywhere outside closes it.
void rtechShowAbout(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFFF7F9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Image.asset('assets/icon.png', width: 64, height: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(kRtechDisplayName,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2A44))),
                      if (kRtechSubtitle.isNotEmpty)
                        const Text(kRtechSubtitle,
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF5B6B82))),
                      FutureBuilder<String>(
                        future: bind.mainGetVersion(),
                        builder: (c, s) => Text(
                            s.hasData ? 'גרסה ${s.data}' : '',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF5B6B82))),
                      ),
                    ],
                  ),
                ),
              ]),
              const Divider(height: 28),
              const Text(
                  'מבוסס על RustDesk — תוכנת קוד פתוח ברישיון AGPL-3.0. '
                  'מותר להשתמש, להעתיק ולשנות לפי תנאי הרישיון.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF2E3B52))),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => launchUrl(Uri.parse(kRtechSource)),
                child: const Text('קוד המקור של הגרסה הזו: $kRtechSource',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1565C0),
                        decoration: TextDecoration.underline)),
              ),
              if (kRtechAbout.isNotEmpty) const Divider(height: 28),
              if (kRtechAbout.isNotEmpty)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (kRtechHasMaker) ...[
                    Image.asset('assets/rtech_maker.png',
                        width: 56, height: 56),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < kRtechAbout.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: SelectableText(
                              kRtechAbout[i],
                              style: TextStyle(
                                  fontSize: i == 0 ? 18 : 15,
                                  fontWeight: i == 0
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: const Color(0xFF1E2A44)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]),
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kRtechAccent,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('סגירה'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ shared pieces

/// The logo, the name and the subtitle; a click opens "About".
class RtechBrand extends StatelessWidget {
  final bool dark;
  final double logo;
  const RtechBrand({Key? key, required this.dark, this.logo = 46})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => rtechShowAbout(context),
        child: Tooltip(
          message: 'אודות',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/icon.png', width: logo, height: logo),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(kRtechDisplayName,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: dark ? Colors.white : const Color(0xFF1B1F23))),
                  if (kRtechHasMaker) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: kRtechAbout.isNotEmpty
                          ? kRtechAbout.first
                          : 'יוצר התוכנה',
                      child: Image.asset('assets/rtech_maker.png',
                          width: 20, height: 20),
                    ),
                  ],
                ]),
                if (kRtechSubtitle.isNotEmpty)
                  Text(kRtechSubtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: dark
                              ? const Color(0xFFB0BEC5)
                              : const Color(0xFF607D8B))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// The screen picture of a computer, grey when it is off; its system's logo when there is
/// no picture yet.
class RtechThumbView extends StatelessWidget {
  final Peer peer;
  final double radius;
  final Color placeholder;
  const RtechThumbView(
      {Key? key,
      required this.peer,
      this.radius = 0,
      this.placeholder = const Color(0xFF455A64)})
      : super(key: key);

  static const List<double> _grey = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final thumb = RtechData.instance.thumbOf(peer.id);
    Widget child;
    if (thumb != null) {
      child = Image.memory(thumb.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium);
      if (!peer.online) {
        child = Opacity(
            opacity: 0.62,
            child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grey), child: child));
      }
    } else {
      child = Container(
        color: placeholder,
        alignment: Alignment.center,
        child: peer.platform.isEmpty
            ? const Icon(Icons.computer, size: 40, color: Colors.white70)
            : Opacity(
                opacity: peer.online ? 1 : 0.5,
                child: getPlatformImage(peer.platform, size: 44)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(child: child),
    );
  }
}

/// Click selects, double click connects, right click opens the menu.
class RtechTileGestures extends StatelessWidget {
  final Peer peer;
  final Widget child;
  const RtechTileGestures({Key? key, required this.peer, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = RtechData.instance;
    final note = data.extraOf(peer.id).note;
    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => data.select(peer.id),
        onDoubleTap: () => rtechConnect(context, peer.id),
        onSecondaryTapDown: (details) {
          data.select(peer.id);
          rtechTileMenu(context, peer, details.globalPosition);
        },
        child: child,
      ),
    );
    if (note.isEmpty) return tile;
    return Tooltip(
        message: note,
        waitDuration: const Duration(milliseconds: 700),
        child: tile);
  }
}

/// A filter chip row: "all" and the groups.
class RtechGroupChips extends StatelessWidget {
  final Color activeBack;
  final Color activeText;
  final Color back;
  final Color text;
  final double radius;
  const RtechGroupChips(
      {Key? key,
      required this.activeBack,
      required this.activeText,
      required this.back,
      required this.text,
      this.radius = 0})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = RtechData.instance;
    Widget chip(String value, String label) {
      final active = data.groupFilter == value;
      final dot = kRtechGroupColors[value];
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => data.setGroupFilter(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: active ? activeBack : back,
                  borderRadius: BorderRadius.circular(radius)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (dot != null)
                  Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle)),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? activeText : text)),
              ]),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('', 'הכול'),
        for (final group in kRtechGroups) chip(group, group),
      ]),
    );
  }
}

/// "Nothing here yet".
class RtechEmpty extends StatelessWidget {
  final Color color;
  const RtechEmpty({Key? key, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = RtechData.instance;
    final filtered = data.groupFilter.isNotEmpty ||
        data.statusFilter.isNotEmpty ||
        data.search.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          filtered
              ? 'אין מחשבים שמתאימים לסינון.'
              : 'עדיין אין מחשבים ברשימה.\nהקלד מספר מחשב ולחץ "התחבר" — אחרי החיבור הראשון הוא יופיע כאן כמשבצת,\nוהקוד יישמר כך שלחיצה כפולה תתחבר מיד.',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ simple screen

/// For relatives: only this computer's number and code, big, and one copy button.
class RtechSimple extends StatelessWidget {
  const RtechSimple({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1EC),
      child: Stack(children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: RtechMine(
              builder: (context, id, code) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => rtechShowAbout(context),
                      child: Image.asset('assets/icon.png',
                          width: 84, height: 84),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(kRtechDisplayName,
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 26),
                  const Text('המספר של המחשב הזה',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6B6257))),
                  Text(id,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: kRtechIdOnLight)),
                  const SizedBox(height: 12),
                  const Text('קוד',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6B6257))),
                  Text(code.isEmpty ? '—' : code,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 40,
                          fontFamily: 'Consolas',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: kRtechCodeOnLight)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRtechAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    onPressed: RtechMine.copyBoth,
                    icon: const Icon(Icons.copy),
                    label: const Text('העתק את המספר והקוד'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                      'תן את המספר והקוד רק למי שאתה סומך עליו.\nכדי שלא יוכלו להתחבר — פשוט סגור את התוכנה.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF6B6257), height: 1.5)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 10,
          child: TextButton.icon(
            onPressed: () => RtechData.instance.setDesign('f1'),
            icon: const Icon(Icons.grid_view, size: 16),
            label: const Text('חזרה למסך המלא'),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 14,
          child: RtechServerState(
              readyColor: kRtechOnline, otherColor: Colors.grey.shade600),
        ),
      ]),
    );
  }
}

/// RustDesk's settings page.
void rtechOpenSettings() {
  DesktopTabPage.onAddSetting();
}
