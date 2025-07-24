import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';



class SettingsScreen extends StatefulWidget {
  final Function(bool) onWeekStartChanged;
  final bool weekStartsFromSunday;

  const SettingsScreen({
    Key? key,
    required this.onWeekStartChanged,
    required this.weekStartsFromSunday,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState(
    onWeekStartChanged: onWeekStartChanged,
    weekStartsFromSunday: weekStartsFromSunday,
  );
}

class _SettingsScreenState extends State<SettingsScreen> {
  String weekStart = 'Thứ hai';

  final Function(bool) onWeekStartChanged;
  final bool weekStartsFromSunday;

  final List<String> weekDays = [
    'Chủ nhật',
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
  ];

  _SettingsScreenState({
    required this.onWeekStartChanged,
    required this.weekStartsFromSunday,
  });

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('CÀI ĐẶT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/advertise.png',
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.deepPurple),
              title: const Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen()));
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('Bắt đầu tuần từ', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: DropdownButton<String>(
                value: weekStart,
                underline: const SizedBox(),
                items: weekDays.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    setState(() {
                      weekStart = val;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('weekStart', val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.deepPurple),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 