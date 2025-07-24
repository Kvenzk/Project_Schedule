import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'change_password_screen.dart'; 


class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User? user;
  late String displayName;
  late String email;
  int avatarColorValue = Colors.grey.value;
  final List<Color> avatarColors = [
    Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.cyan
  ];

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    displayName = user?.displayName ?? '';
    email = user?.email ?? '';
    _ensureAvatarColor();
  }

  Future<void> _ensureAvatarColor() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (!doc.exists || !(doc.data()?.containsKey('avatarColor') ?? false)) {
      final color = (avatarColors..shuffle()).first.value;
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'avatarColor': color,
      }, SetOptions(merge: true));
      setState(() { avatarColorValue = color; });
    } else {
      setState(() { avatarColorValue = doc['avatarColor']; });
    }
  }

  Future<void> _editField(String field, String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi tên'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'Nhập tên mới',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await user?.updateDisplayName(result);
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'displayName': result,
      }, SetOptions(merge: true));
      setState(() => displayName = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Hồ sơ cá nhân', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(avatarColorValue),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                (displayName.isNotEmpty ? displayName[0] : (email.isNotEmpty ? email[0] : '?')).toUpperCase(),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName.isNotEmpty ? displayName : 'Chưa đặt tên',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            if (user?.metadata.creationTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Ngày tham gia ${user!.metadata.creationTime!.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            const SizedBox(height: 24),
            // General info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(child: Text(displayName.isNotEmpty ? displayName : 'Chưa đặt tên')),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.deepPurple),
                        onPressed: () => _editField('displayName', displayName),
                        tooltip: 'Đổi tên',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(child: Text(email)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Đổi mật khẩu')),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.deepPurple),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChangePasswordScreen(),
                            ),
                          );
                        },
                        tooltip: 'Đổi mật khẩu',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Sign out button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
} 