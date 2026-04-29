import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.database;
  runApp(const SardaniakanamApp());
}

const Color kPurple = Color(0xFF5B35D5);
const Color kDarkPurple = Color(0xFF1D154A);
const Color kLightBg = Color(0xFFF7F6FB);

class SardaniakanamApp extends StatelessWidget {
  const SardaniakanamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سەردانیەکانم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple),
        scaffoldBackgroundColor: kLightBg,
        useMaterial3: true,
      ),
      home: const Directionality(textDirection: TextDirection.rtl, child: PinScreen()),
    );
  }
}

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'sardaniakanam_final.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE visitors(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          date TEXT NOT NULL,
          time TEXT NOT NULL,
          meetingWith TEXT NOT NULL,
          purpose TEXT,
          note TEXT,
          status TEXT NOT NULL,
          photoPath TEXT,
          createdBy TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.insert('settings', {'key': 'pin', 'value': '1234'});
      await db.insert('settings', {'key': 'manager', 'value': 'سەرکەوت زەکی'});
      await db.insert('settings', {'key': 'secretary', 'value': 'سکرتێر ١'});
    });
    return _db!;
  }

  Future<String> getSetting(String key, String fallback) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty ? fallback : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> addVisitor(Visitor v) async {
    final db = await database;
    return db.insert('visitors', v.toMap());
  }

  Future<int> updateVisitor(Visitor v) async {
    final db = await database;
    return db.update('visitors', v.toMap(), where: 'id=?', whereArgs: [v.id]);
  }

  Future<int> deleteVisitor(int id) async {
    final db = await database;
    return db.delete('visitors', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Visitor>> visitors({String q = '', String status = 'هەموو'}) async {
    final db = await database;
    String where = '';
    List<Object?> args = [];
    if (q.trim().isNotEmpty) {
      where += '(name LIKE ? OR phone LIKE ? OR meetingWith LIKE ?)';
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }
    if (status != 'هەموو') {
      if (where.isNotEmpty) where += ' AND ';
      where += 'status=?';
      args.add(status);
    }
    final rows = await db.query('visitors', where: where.isEmpty ? null : where, whereArgs: args, orderBy: 'date DESC, time DESC');
    return rows.map((e) => Visitor.fromMap(e)).toList();
  }

  Future<List<Visitor>> todayVisitors() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final db = await database;
    final rows = await db.query('visitors', where: 'date=?', whereArgs: [today], orderBy: 'time ASC');
    return rows.map((e) => Visitor.fromMap(e)).toList();
  }
}

class Visitor {
  final int? id;
  final String name, phone, date, time, meetingWith, purpose, note, status, createdBy, createdAt;
  final String? photoPath;

  Visitor({
    this.id,
    required this.name,
    required this.phone,
    required this.date,
    required this.time,
    required this.meetingWith,
    required this.purpose,
    required this.note,
    required this.status,
    this.photoPath,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'date': date,
    'time': time,
    'meetingWith': meetingWith,
    'purpose': purpose,
    'note': note,
    'status': status,
    'photoPath': photoPath,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };

  static Visitor fromMap(Map<String, dynamic> m) => Visitor(
    id: m['id'] as int?,
    name: m['name'],
    phone: m['phone'],
    date: m['date'],
    time: m['time'],
    meetingWith: m['meetingWith'],
    purpose: m['purpose'] ?? '',
    note: m['note'] ?? '',
    status: m['status'],
    photoPath: m['photoPath'],
    createdBy: m['createdBy'],
    createdAt: m['createdAt'],
  );
}

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String pin = '';
  String saved = '1234';
  bool error = false;

  @override
  void initState() {
    super.initState();
    AppDb.instance.getSetting('pin', '1234').then((v) => setState(() => saved = v));
  }

  void press(String x) {
    HapticFeedback.lightImpact();
    setState(() {
      error = false;
      if (x == 'del') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 4) {
        pin += x;
      }
    });
    if (pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (pin == saved) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: HomeShell())));
        } else {
          setState(() {
            error = true;
            pin = '';
          });
        }
      });
    }
  }

  Future<void> biometric() async {
    try {
      final ok = await LocalAuthentication().authenticate(localizedReason: 'چوونەژوورەوە بۆ سەردانیەکانم');
      if (ok && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: HomeShell())));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkPurple,
      body: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('assets/logo.png', height: 112),
          const SizedBox(height: 10),
          const Text('سەردانیەکانم', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          const Text('سیستەمی سەردان و مۆعید', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 34),
          Text(error ? 'PIN هەڵەیە' : 'تکایە PIN بنووسە', style: TextStyle(color: error ? Colors.redAccent : Colors.white70)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 13,
            height: 13,
            decoration: BoxDecoration(color: i < pin.length ? Colors.white : Colors.white24, shape: BoxShape.circle),
          ))),
          const SizedBox(height: 30),
          ...[['1','2','3'],['4','5','6'],['7','8','9'],['bio','0','del']].map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map((x) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: InkWell(
                onTap: () => x == 'bio' ? biometric() : press(x),
                borderRadius: BorderRadius.circular(32),
                child: CircleAvatar(
                  radius: 31,
                  backgroundColor: Colors.white12,
                  child: x == 'del'
                    ? const Icon(Icons.backspace_outlined, color: Colors.white)
                    : x == 'bio'
                      ? const Icon(Icons.fingerprint, color: Colors.white)
                      : Text(x, style: const TextStyle(color: Colors.white, fontSize: 24)),
                ),
              ),
            )).toList()),
          )),
        ]),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  final pages = const [DashboardPage(), VisitorListPage(), AddVisitorPage(), ReportsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: pages[idx],
    bottomNavigationBar: NavigationBar(
      selectedIndex: idx,
      onDestinationSelected: (i) => setState(() => idx = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبۆرد'),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'سەردانەکان'),
        NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'زیادکردن'),
        NavigationDestination(icon: Icon(Icons.bar_chart), label: 'ڕاپۆرت'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'ڕێکخستن'),
      ],
    ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Visitor> all = [], today = [];
  String manager = 'سەرکەوت زەکی';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final a = await AppDb.instance.visitors();
    final t = await AppDb.instance.todayVisitors();
    final m = await AppDb.instance.getSetting('manager', 'سەرکەوت زەکی');
    setState(() {
      all = a;
      today = t;
      manager = m;
    });
  }

  int count(String s) => all.where((e) => e.status == s).length;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('داشبۆرد'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('بەخێربێیت — $manager', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            stat('سەردانی ئەمڕۆ', today.length.toString(), Icons.today, Colors.blue),
            stat('کۆی گشتی', all.length.toString(), Icons.people, kPurple),
            stat('چاوەڕێ', count('چاوەڕێ').toString(), Icons.schedule, Colors.orange),
            stat('تەواوبوو', count('تەواوبوو').toString(), Icons.check_circle, Colors.green),
          ],
        ),
        const SizedBox(height: 20),
        const Text('دوایین سەردانەکان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        ...all.take(8).map((v) => VisitorTile(visitor: v, onChanged: load)),
      ]),
    ),
  );

  Widget stat(String title, String value, IconData icon, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.black54)),
      ]),
    ),
  );
}

class VisitorListPage extends StatefulWidget {
  const VisitorListPage({super.key});
  @override
  State<VisitorListPage> createState() => _VisitorListPageState();
}

class _VisitorListPageState extends State<VisitorListPage> {
  String q = '', status = 'هەموو';

  Future<List<Visitor>> future() => AppDb.instance.visitors(q: q, status: status);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('سەردانەکان')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'گەڕان بە ناو، ژمارە، یان کەس...', border: OutlineInputBorder()),
          onChanged: (v) => setState(() => q = v),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: ['هەموو','هات','چاوەڕێ','تەواوبوو','هەڵوەشاوە'].map((s) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ChoiceChip(label: Text(s), selected: status == s, onSelected: (_) => setState(() => status = s)),
        )).toList()),
      ),
      Expanded(
        child: FutureBuilder<List<Visitor>>(
          future: future(),
          builder: (context, snap) {
            final data = snap.data ?? [];
            if (data.isEmpty) return const Center(child: Text('هیچ سەردانێک نییە'));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              itemBuilder: (_, i) => VisitorTile(visitor: data[i], onChanged: () => setState(() {})),
            );
          },
        ),
      )
    ]),
  );
}

class VisitorTile extends StatelessWidget {
  final Visitor visitor;
  final VoidCallback onChanged;

  const VisitorTile({super.key, required this.visitor, required this.onChanged});

  Color get color => visitor.status == 'تەواوبوو'
    ? Colors.green
    : visitor.status == 'چاوەڕێ'
      ? Colors.orange
      : visitor.status == 'هەڵوەشاوە'
        ? Colors.red
        : kPurple;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: visitor.photoPath != null && File(visitor.photoPath!).existsSync()
        ? CircleAvatar(backgroundImage: FileImage(File(visitor.photoPath!)))
        : CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(Icons.person, color: color)),
      title: Text(visitor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${visitor.phone}\n${visitor.date} - ${visitor.time} | ${visitor.meetingWith}'),
      isThreeLine: true,
      trailing: Chip(label: Text(visitor.status), side: BorderSide.none, backgroundColor: color.withOpacity(.12)),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => Directionality(textDirection: TextDirection.rtl, child: VisitorDetailsPage(visitor: visitor))));
        onChanged();
      },
    ),
  );
}

class AddVisitorPage extends StatefulWidget {
  final Visitor? edit;
  const AddVisitorPage({super.key, this.edit});

  @override
  State<AddVisitorPage> createState() => _AddVisitorPageState();
}

class _AddVisitorPageState extends State<AddVisitorPage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final meeting = TextEditingController(text: 'سەرکەوت زەکی');
  final purpose = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();
  String status = 'چاوەڕێ';
  String? photoPath;
  String secretary = 'سکرتێر ١';

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    secretary = await AppDb.instance.getSetting('secretary', 'سکرتێر ١');
    final e = widget.edit;
    if (e != null) {
      name.text = e.name;
      phone.text = e.phone;
      meeting.text = e.meetingWith;
      purpose.text = e.purpose;
      note.text = e.note;
      status = e.status;
      photoPath = e.photoPath;
      date = DateTime.parse(e.date);
      final parts = e.time.split(':');
      time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    setState(() {});
  }

  Future<void> pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
    if (x != null) setState(() => photoPath = x.path);
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
    final v = Visitor(
      id: widget.edit?.id,
      name: name.text.trim(),
      phone: phone.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(date),
      time: '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}',
      meetingWith: meeting.text.trim(),
      purpose: purpose.text.trim(),
      note: note.text.trim(),
      status: status,
      photoPath: photoPath,
      createdBy: secretary,
      createdAt: DateTime.now().toIso8601String(),
    );
    if (widget.edit == null) {
      await AppDb.instance.addVisitor(v);
    } else {
      await AppDb.instance.updateVisitor(v);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پاشەکەوت کرا')));
    if (widget.edit != null && mounted) Navigator.pop(context);
    if (widget.edit == null) {
      name.clear();
      phone.clear();
      purpose.clear();
      note.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.edit == null ? 'زیادکردنی سەردان' : 'دەستکاریکردن')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: InkWell(
          onTap: pickPhoto,
          child: CircleAvatar(
            radius: 48,
            backgroundImage: photoPath != null && File(photoPath!).existsSync() ? FileImage(File(photoPath!)) : null,
            child: photoPath == null ? const Icon(Icons.camera_alt, size: 34) : null,
          ),
        ),
      ),
      const SizedBox(height: 16),
      field(name, 'ناوی سەردانکەر', Icons.person),
      field(phone, 'ژمارەی مۆبایل', Icons.phone, keyboard: TextInputType.phone),
      ListTile(
        leading: const Icon(Icons.calendar_month),
        title: Text(DateFormat('yyyy-MM-dd').format(date)),
        subtitle: const Text('بەروار'),
        onTap: () async {
          final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: date);
          if (d != null) setState(() => date = d);
        },
      ),
      ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(time.format(context)),
        subtitle: const Text('کات'),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: time);
          if (t != null) setState(() => time = t);
        },
      ),
      field(meeting, 'چاوی بە کێ کەوتووە', Icons.groups),
      field(purpose, 'مەبەست', Icons.flag),
      field(note, 'تێبینی', Icons.note, maxLines: 3),
      DropdownButtonFormField<String>(
        value: status,
        decoration: const InputDecoration(labelText: 'دۆخ', border: OutlineInputBorder()),
        items: ['هات','چاوەڕێ','تەواوبوو','هەڵوەشاوە'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => setState(() => status = v!),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('تۆمارکردن')),
    ]),
  );

  Widget field(TextEditingController c, String label, IconData icon, {TextInputType keyboard = TextInputType.text, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, keyboardType: keyboard, maxLines: maxLines, decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label, border: const OutlineInputBorder())),
  );
}

class VisitorDetailsPage extends StatelessWidget {
  final Visitor visitor;
  const VisitorDetailsPage({super.key, required this.visitor});

  Future<void> whatsapp() async {
    final text = Uri.encodeComponent('بیرخستنەوە: مۆعیدت لە ${visitor.date} کاتژمێر ${visitor.time}');
    final uri = Uri.parse('https://wa.me/${visitor.phone.replaceAll('+','').replaceAll(' ','')}?text=$text');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('وردەکاری سەردان')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            visitor.photoPath != null && File(visitor.photoPath!).existsSync()
              ? CircleAvatar(radius: 54, backgroundImage: FileImage(File(visitor.photoPath!)))
              : const CircleAvatar(radius: 54, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 12),
            Text(visitor.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(visitor.phone),
            Chip(label: Text(visitor.status)),
          ]),
        ),
      ),
      info(Icons.calendar_month, 'کات و مۆعید', '${visitor.date} - ${visitor.time}'),
      info(Icons.groups, 'چاوی بە کێ کەوتووە', visitor.meetingWith),
      info(Icons.flag, 'مەبەست', visitor.purpose.isEmpty ? '-' : visitor.purpose),
      info(Icons.note, 'تێبینی', visitor.note.isEmpty ? '-' : visitor.note),
      info(Icons.person_pin, 'تۆمارکراو لەلایەن', visitor.createdBy),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: whatsapp, icon: const Icon(Icons.message), label: const Text('ناردنی WhatsApp')),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Directionality(textDirection: TextDirection.rtl, child: AddVisitorPage(edit: visitor)))),
        icon: const Icon(Icons.edit),
        label: const Text('دەستکاریکردن'),
      ),
      FilledButton.tonalIcon(
        onPressed: () async {
          await AppDb.instance.deleteVisitor(visitor.id!);
          if (context.mounted) Navigator.pop(context);
        },
        icon: const Icon(Icons.delete),
        label: const Text('سڕینەوە'),
      ),
    ]),
  );

  Widget info(IconData i, String title, String value) => Card(child: ListTile(leading: Icon(i), title: Text(title), subtitle: Text(value)));
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Visitor> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await AppDb.instance.visitors();
    setState(() {});
  }

  int count(String s) => items.where((e) => e.status == s).length;

  Future<void> exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (context) => [
      pw.Header(level: 0, child: pw.Text('Sardaniakanam Report')),
      pw.Text('Total: ${items.length}'),
      pw.Table.fromTextArray(
        headers: ['Name','Phone','Date','Time','Meeting','Status'],
        data: items.map((v) => [v.name, v.phone, v.date, v.time, v.meetingWith, v.status]).toList(),
      ),
    ]));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'sardaniakanam_report.pdf');
  }

  Future<void> exportExcel() async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Report'];
    sheet.appendRow(['Name','Phone','Date','Time','Meeting','Purpose','Status'].map((e) => ex.TextCellValue(e)).toList());
    for (final v in items) {
      sheet.appendRow([v.name, v.phone, v.date, v.time, v.meetingWith, v.purpose, v.status].map((e) => ex.TextCellValue(e)).toList());
    }
    final bytes = excel.save();
    if (bytes == null) return;
    final file = File('${Directory.systemTemp.path}/sardaniakanam_report.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ڕاپۆرت'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(crossAxisCount: 2, childAspectRatio: 1.5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
        reportCard('کۆی گشتی', items.length.toString()),
        reportCard('هات', count('هات').toString()),
        reportCard('چاوەڕێ', count('چاوەڕێ').toString()),
        reportCard('تەواوبوو', count('تەواوبوو').toString()),
      ]),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: exportPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('دەرچوونی PDF')),
      FilledButton.tonalIcon(onPressed: exportExcel, icon: const Icon(Icons.table_chart), label: const Text('دەرچوونی Excel')),
    ]),
  );

  Widget reportCard(String t, String v) => Card(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(v, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)), Text(t)])));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final manager = TextEditingController();
  final pin = TextEditingController();
  final secretary = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    manager.text = await AppDb.instance.getSetting('manager', 'سەرکەوت زەکی');
    pin.text = await AppDb.instance.getSetting('pin', '1234');
    secretary.text = await AppDb.instance.getSetting('secretary', 'سکرتێر ١');
  }

  Future<void> save() async {
    await AppDb.instance.setSetting('manager', manager.text.trim());
    await AppDb.instance.setSetting('pin', pin.text.trim().isEmpty ? '1234' : pin.text.trim());
    await AppDb.instance.setSetting('secretary', secretary.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ڕێکخستنەکان پاشەکەوت کران')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ڕێکخستن')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Image.asset('assets/logo.png', height: 90),
      const Center(child: Text('سەردانیەکانم', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
      const SizedBox(height: 18),
      TextField(controller: manager, decoration: const InputDecoration(labelText: 'ناوی بەڕێوەبەر', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: secretary, decoration: const InputDecoration(labelText: 'ناوی سکرتێر', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder())),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('پاشەکەوتکردن')),
      const SizedBox(height: 14),
      const Text('سکرتێرەکان: سکرتێر ١، سکرتێر ٢، سکرتێر ٣ — ناوی سکرتێری ئێستا لێرە بگۆڕە.'),
    ]),
  );
}
