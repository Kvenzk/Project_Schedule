import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


/// Widget chính cho trang nhóm
class GroupScreen extends StatefulWidget {
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  // Hiển thị dialog tạo nhóm
  void _showCreateGroupDialog() async {
    showDialog(
      context: context,
      builder: (context) => GroupCreateDialog(onCreated: () => setState(() {})),
    );
  }

  // Hiển thị dialog tham gia nhóm
  void _showJoinGroupDialog() async {
    showDialog(
      context: context,
      builder: (context) => GroupJoinDialog(onJoined: () => setState(() {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.add, color: Color(0xFF667eea)),
          onPressed: _showCreateGroupDialog,
          tooltip: 'Tạo nhóm',
        ),
        title: Text('Nhóm', style: calendarFont.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showJoinGroupDialog,
              icon: Icon(Icons.group_add, color: Color(0xFF667eea), size: 18),
              label: Text('Tham gia', style: calendarFont.copyWith(color: Color(0xFF667eea), fontSize: 14)),
              style: TextButton.styleFrom(
                minimumSize: Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm nhóm...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchText = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Row(
              children: [
                Text(
                  'Nhóm của bạn',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection('groups')
                  .where('members', arrayContains: user?.uid)
                  .snapshots(),
                builder: (context, snapshot) {
                  var groups = snapshot.data?.docs ?? [];
                  if (_searchText.trim().isNotEmpty) {
                    final searchLower = _searchText.trim().toLowerCase();
                    groups = groups.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(searchLower);
                    }).toList();
                  }
                  if (groups.isEmpty) {
                    return Center(child: Text('Bạn chưa tham gia nhóm nào', style: calendarFont));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => SizedBox(height: 18),
                    itemBuilder: (context, i) {
                      final data = groups[i].data() as Map<String, dynamic>;
                      data['id'] = groups[i].id;
                      return GroupCard(
                        group: data,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => GroupDetailScreen(group: data)),
                          );
                        },
                        onGroupUpdated: () {
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card hiển thị thông tin nhóm
class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback onGroupUpdated;
  const GroupCard({required this.group, required this.onTap, required this.onGroupUpdated});

  @override
  Widget build(BuildContext context) {
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w600);
    final memberAvatars = (group['memberAvatars'] ?? []) as List<dynamic>;
    final createdAt = (group['createdAt'] as Timestamp?)?.toDate();
    final currentUser = FirebaseAuth.instance.currentUser;
    final members = (group['members'] ?? []) as List<dynamic>;
    final isOwner = currentUser != null && members.isNotEmpty && members[0] == currentUser.uid;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(group['name'] ?? '', style: calendarFont.copyWith(fontSize: 18)),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _deleteGroup(context);
                    } else if (value == 'leave') {
                      await _leaveGroup(context);
                    } else if (value == 'members') {
                      _showMembersDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'members',
                      child: Row(
                        children: [
                          Icon(Icons.people, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Thành viên', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                    if (isOwner)
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xóa nhóm', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem<String>(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Rời nhóm', style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (createdAt != null)
              Text(DateFormat('dd/MM/yyyy').format(createdAt), style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                ...(memberAvatars as List<dynamic>).take(5).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final colorValue = entry.value;
                  final memberId = index < members.length ? members[index] : null;
                  String getInitial() {
                    if (memberId == null) return '?';
                    final memberNames = (group['memberNames'] ?? []) as List<dynamic>;
                    final memberEmails = (group['memberEmails'] ?? []) as List<dynamic>;
                    if (index < memberNames.length) {
                      final name = memberNames[index]?.toString() ?? '';
                      if (name.isNotEmpty) {
                        return name[0].toUpperCase();
                      }
                    }
                    if (index < memberEmails.length) {
                      final email = memberEmails[index]?.toString() ?? '';
                      if (email.isNotEmpty) {
                        return email[0].toUpperCase();
                      }
                    }
                    return '?';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(colorValue),
                      child: Text(
                        getInitial(),
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  );
                }),
                if (memberAvatars.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('+${memberAvatars.length - 5}', style: TextStyle(color: Colors.grey[700])),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Xóa nhóm
  Future<void> _deleteGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa nhóm'),
        content: Text('Bạn có chắc chắn muốn xóa nhóm "${group['name']}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa nhóm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('groups').doc(group['id']).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa nhóm thành công')),
        );
        onGroupUpdated();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa nhóm: ${e.toString()}')),
        );
      }
    }
  }

  // Rời nhóm
  Future<void> _leaveGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận rời nhóm'),
        content: Text('Bạn có chắc chắn muốn rời khỏi nhóm "${group['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Rời nhóm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        final members = (group['members'] ?? []) as List<dynamic>;
        final memberAvatars = (group['memberAvatars'] ?? []) as List<dynamic>;
        final memberEmails = (group['memberEmails'] ?? []) as List<dynamic>;
        final memberNames = (group['memberNames'] ?? []) as List<dynamic>;

        final userIndex = members.indexOf(currentUser.uid);
        if (userIndex == -1) return;

        members.removeAt(userIndex);
        if (userIndex < memberAvatars.length) memberAvatars.removeAt(userIndex);
        if (userIndex < memberEmails.length) memberEmails.removeAt(userIndex);
        if (userIndex < memberNames.length) memberNames.removeAt(userIndex);

        await FirebaseFirestore.instance.collection('groups').doc(group['id']).update({
          'members': members,
          'memberAvatars': memberAvatars,
          'memberEmails': memberEmails,
          'memberNames': memberNames,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã rời nhóm thành công')),
        );
        onGroupUpdated();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi rời nhóm: ${e.toString()}')),
        );
      }
    }
  }

  // Hiển thị danh sách thành viên nhóm
  void _showMembersDialog(BuildContext context) {
    final members = (group['members'] ?? []) as List<dynamic>;
    final memberAvatars = (group['memberAvatars'] ?? []) as List<dynamic>;
    final memberEmails = (group['memberEmails'] ?? []) as List<dynamic>;
    final memberNames = (group['memberNames'] ?? []) as List<dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.blue),
            SizedBox(width: 8),
            Text('Thành viên nhóm (${members.length})'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...members.asMap().entries.map((entry) {
                final index = entry.key;
                final memberId = entry.value;
                final isOwner = index == 0;
                final isCurrentUser = currentUser?.uid == memberId;
                String memberName = 'Thành viên';
                String memberEmail = '';
                if (index < memberNames.length) {
                  memberName = memberNames[index]?.toString() ?? 'Thành viên';
                }
                if (index < memberEmails.length) {
                  memberEmail = memberEmails[index]?.toString() ?? '';
                }
                int avatarColor = Colors.grey.value;
                if (index < memberAvatars.length) {
                  avatarColor = memberAvatars[index];
                }
                String getInitial() {
                  if (memberName.isNotEmpty && memberName != 'Thành viên') {
                    return memberName[0].toUpperCase();
                  }
                  if (memberEmail.isNotEmpty) {
                    return memberEmail[0].toUpperCase();
                  }
                  return '?';
                }
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? Colors.blue.withOpacity(0.1) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentUser 
                        ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(avatarColor),
                            child: Text(
                              getInitial(),
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isOwner)
                            Positioned(
                              top: -16,
                              left: 10,
                              child: FaIcon(
                                FontAwesomeIcons.crown,
                                color: Colors.amber,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  memberName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Bạn',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (memberEmail.isNotEmpty)
                              Text(
                                memberEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

/// Dialog tạo nhóm mới
class GroupCreateDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const GroupCreateDialog({required this.onCreated});
  @override
  State<GroupCreateDialog> createState() => _GroupCreateDialogState();
}

class _GroupCreateDialogState extends State<GroupCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Tạo nhóm mới
  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _error = 'Chưa đăng nhập'; });
        return;
      }
      final avatarColor = await _getUserAvatarColor(user);
      final code = _generateGroupCode();
      await FirebaseFirestore.instance.collection('groups').add({
        'name': _nameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'code': code,
        'members': [user.uid],
        'memberAvatars': [avatarColor],
        'memberEmails': [user.email ?? ''],
        'memberNames': [user.displayName ?? user.email?.split('@')[0] ?? 'User'],
      });
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      setState(() { _error = 'Tạo nhóm thất bại: ${e.toString()}'; });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  // Lấy màu avatar của user
  Future<int> _getUserAvatarColor(User? user) async {
    if (user == null) return Colors.grey.value;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()!.containsKey('avatarColor')) {
      return doc['avatarColor'];
    }
    return Colors.grey.value;
  }

  // Sinh mã nhóm
  String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (i) => chars[(DateTime.now().millisecondsSinceEpoch + i * 13) % chars.length]).join();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tạo nhóm mới'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(hintText: 'Tên nhóm'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tên nhóm' : null,
        ),
      ),
      actions: [
        if (_error != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(_error!, style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
        ElevatedButton(
          onPressed: _loading ? null : _createGroup,
          child: _loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Tạo'),
        ),
      ],
    );
  }
}

/// Dialog tham gia nhóm
class GroupJoinDialog extends StatefulWidget {
  final VoidCallback onJoined;
  const GroupJoinDialog({required this.onJoined});
  @override
  State<GroupJoinDialog> createState() => _GroupJoinDialogState();
}

class _GroupJoinDialogState extends State<GroupJoinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Tham gia nhóm
  Future<void> _joinGroup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final user = FirebaseAuth.instance.currentUser;
    final avatarColor = await _getUserAvatarColor(user);
    try {
      final query = await FirebaseFirestore.instance.collection('groups').where('code', isEqualTo: _codeController.text.trim()).get();
      if (query.docs.isEmpty) {
        setState(() { _error = 'Không tìm thấy nhóm'; });
      } else {
        final doc = query.docs.first;
        final data = doc.data();
        final members = List<String>.from(data['members'] ?? []);
        final memberAvatars = List<int>.from(data['memberAvatars'] ?? []);
        final memberEmails = List<String>.from(data['memberEmails'] ?? []);
        final memberNames = List<String>.from(data['memberNames'] ?? []);
        if (!members.contains(user?.uid)) {
          members.add(user!.uid);
          memberAvatars.add(avatarColor);
          memberEmails.add(user.email ?? '');
          memberNames.add(user.displayName ?? user.email?.split('@')[0] ?? 'User');
          await FirebaseFirestore.instance.collection('groups').doc(doc.id).update({
            'members': members,
            'memberAvatars': memberAvatars,
            'memberEmails': memberEmails,
            'memberNames': memberNames,
          });
        }
        widget.onJoined();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = 'Tham gia nhóm thất bại'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  // Lấy màu avatar của user
  Future<int> _getUserAvatarColor(User? user) async {
    if (user == null) return Colors.grey.value;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()!.containsKey('avatarColor')) {
      return doc['avatarColor'];
    }
    return Colors.grey.value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tham gia nhóm'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _codeController,
          decoration: InputDecoration(hintText: 'Nhập mã nhóm'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Nhập mã nhóm' : null,
        ),
      ),
      actions: [
        if (_error != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(_error!, style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
        ElevatedButton(
          onPressed: _loading ? null : _joinGroup,
          child: _loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Tham gia'),
        ),
      ],
    );
  }
}

/// Màn hình chi tiết nhóm
class GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({required this.group});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  // Hiển thị dialog thêm nhiệm vụ nhóm
  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => GroupAddTaskDialog(
        group: widget.group,
        onTaskAdded: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.bold);
    final memberAvatars = (group['memberAvatars'] ?? []) as List<dynamic>;
    final members = (group['members'] ?? []) as List<dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && members.isNotEmpty && members[0] == currentUser.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF667eea)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(group['name'] ?? '', style: calendarFont.copyWith(color: Colors.black)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: group['code'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã copy mã nhóm: ${group['code']}'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF667eea),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF667eea).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(group['code'] ?? '', style: TextStyle(color: Color(0xFF667eea), fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.copy, color: Color(0xFF667eea), size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group, color: Color(0xFF667eea)),
                        SizedBox(width: 8),
                        Text('Thành viên', style: calendarFont.copyWith(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        ...(memberAvatars as List<dynamic>).asMap().entries.map((entry) {
                          final index = entry.key;
                          final colorValue = entry.value;
                          final memberId = index < members.length ? members[index] : null;
                          String getInitial() {
                            if (memberId == null) return '?';
                            final memberNames = (group['memberNames'] ?? []) as List<dynamic>;
                            final memberEmails = (group['memberEmails'] ?? []) as List<dynamic>;
                            if (index < memberNames.length) {
                              final name = memberNames[index]?.toString() ?? '';
                              if (name.isNotEmpty) {
                                return name[0].toUpperCase();
                              }
                            }
                            if (index < memberEmails.length) {
                              final email = memberEmails[index]?.toString() ?? '';
                              if (email.isNotEmpty) {
                                return email[0].toUpperCase();
                              }
                            }
                            return '?';
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(colorValue),
                              child: Text(
                                getInitial(),
                                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt, color: Color(0xFF667eea)),
                    SizedBox(width: 8),
                    Text('Danh sách nhiệm vụ', style: calendarFont.copyWith(fontSize: 18)),
                  ],
                ),
                if (isOwner)
                  ElevatedButton.icon(
                    onPressed: _showAddTaskDialog,
                    icon: Icon(Icons.add, size: 18),
                    label: Text('Thêm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GroupTaskList(group: group),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog thêm/sửa nhiệm vụ nhóm
class GroupAddTaskDialog extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTaskAdded;
  final Map<String, dynamic>? editTask;
  const GroupAddTaskDialog({required this.group, required this.onTaskAdded, this.editTask});
  @override
  State<GroupAddTaskDialog> createState() => _GroupAddTaskDialogState();
}

class _GroupAddTaskDialogState extends State<GroupAddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  Color _selectedColor = const Color(0xFF667eea);
  int _activityIndex = 0;
  bool _important = false;
  bool _loading = false;
  String? _error;

  late List<dynamic> _members;
  late List<dynamic> _memberNames;
  late List<dynamic> _memberAvatars;
  late List<bool> _selectedMembers;

  @override
  void initState() {
    super.initState();
    _members = widget.group['members'] ?? [];
    _memberNames = widget.group['memberNames'] ?? [];
    _memberAvatars = widget.group['memberAvatars'] ?? [];
    _selectedMembers = List.filled(_members.length, false);
    if (widget.editTask != null) {
      _titleController.text = widget.editTask?['title']?.toString() ?? '';
      _descController.text = widget.editTask?['desc']?.toString() ?? '';
      _selectedDateTime = DateTime.tryParse(widget.editTask?['dateTime']?.toString() ?? '') ?? DateTime.now();
      _selectedColor = widget.editTask?['color'] != null ? Color(widget.editTask!['color']) : Color(0xFF667eea);
      _activityIndex = widget.editTask?['type'] == 'su_kien' ? 1 : 0;
      _important = widget.editTask?['important'] ?? false;
      for (int i = 0; i < _members.length; i++) {
        _selectedMembers[i] = (widget.editTask?['visibleTo'] as List?)?.contains(widget.group['members'][i]) ?? false;
      }
    }
  }

  // Chọn ngày giờ
  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('vi', 'VN'),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // Thêm/sửa nhiệm vụ nhóm
  Future<void> _addTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final selectedUids = <String>[];
      for (int i = 0; i < _selectedMembers.length; i++) {
        if (_selectedMembers[i]) selectedUids.add(_members[i]);
      }
      if (_members.isNotEmpty && !selectedUids.contains(_members[0])) {
        selectedUids.insert(0, _members[0]);
      }
      if (widget.editTask != null && widget.editTask!['id'] != null) {
        await FirebaseFirestore.instance
          .collection('group_tasks')
          .doc(widget.editTask!['id'])
          .update({
            'title': _titleController.text.trim(),
            'desc': _descController.text.trim(),
            'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
            'time': DateFormat('HH:mm').format(_selectedDateTime),
            'color': _selectedColor.value,
            'type': _activityIndex == 0 ? 'nhiem_vu' : 'su_kien',
            'important': _important,
            'groupId': widget.group['id'],
            if (selectedUids.isNotEmpty) 'visibleTo': selectedUids,
          });
        widget.onTaskAdded();
        Navigator.pop(context);
      } else {
        await FirebaseFirestore.instance.collection('group_tasks').add({
          'title': _titleController.text.trim(),
          'desc': _descController.text.trim(),
          'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
          'time': DateFormat('HH:mm').format(_selectedDateTime),
          'color': _selectedColor.value,
          'type': _activityIndex == 0 ? 'nhiem_vu' : 'su_kien',
          'createdAt': FieldValue.serverTimestamp(),
          'groupId': widget.group['id'],
          'important': _important,
          if (selectedUids.isNotEmpty) 'visibleTo': selectedUids,
        });
        widget.onTaskAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = 'Thêm nhiệm vụ thất bại: ${e.toString()}'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
    return AlertDialog(
      title: Text(widget.editTask != null ? 'Thay đổi nhiệm vụ' : 'Thêm nhiệm vụ nhóm'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề',
                      border: InputBorder.none,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tiêu đề' : null,
                  ),
                ),
              ),
              // Chi tiết
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Chi tiết',
                      border: InputBorder.none,
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
              ),
              // Ngày/giờ
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.access_time, color: Color(0xFF667eea)),
                  title: Text('Thời gian', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(_selectedDateTime)}  ${DateFormat('HH:mm').format(_selectedDateTime)}'),
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: Color(0xFF667eea)),
                    onPressed: _pickDateTime,
                  ),
                ),
              ),
              // Màu sắc
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.color_lens, color: Color(0xFF667eea)),
                          const SizedBox(width: 8),
                          Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ...[
                            Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple
                          ].map((color) => GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColor == color ? Color(0xFF667eea) : Colors.grey.shade300,
                                  width: _selectedColor == color ? 3 : 2,
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Loại nhiệm vụ
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _activityIndex = 0),
                          icon: Icon(Icons.checklist),
                          label: Text('Nhiệm vụ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activityIndex == 0 ? _selectedColor : Colors.grey[200],
                            foregroundColor: _activityIndex == 0 ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _activityIndex = 1),
                          icon: Icon(Icons.event),
                          label: Text('Sự kiện'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activityIndex == 1 ? _selectedColor : Colors.grey[200],
                            foregroundColor: _activityIndex == 1 ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Quan trọng
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _important,
                        onChanged: (v) => setState(() => _important = v ?? false),
                        title: Text('Quan trọng'),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: Icon(Icons.star, color: _important ? Colors.amber : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              // Chọn thành viên
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Color(0xFF667eea)),
                          const SizedBox(width: 8),
                          Text('Chọn thành viên', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ..._members.asMap().entries.where((entry) => entry.key != 0).map((entry) {
                        final i = entry.key;
                        final uid = entry.value;
                        final name = i < _memberNames.length ? _memberNames[i] : 'Thành viên';
                        final colorValue = i < _memberAvatars.length ? _memberAvatars[i] : Colors.grey.value;
                        return CheckboxListTile(
                          value: _selectedMembers[i],
                          onChanged: (v) => setState(() => _selectedMembers[i] = v ?? false),
                          title: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(colorValue),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(name),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
        ElevatedButton(
          onPressed: _loading ? null : _addTask,
          child: _loading 
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
              : Text(widget.editTask != null ? 'OK' : 'Thêm'),
        ),
      ],
    );
  }
}

/// Danh sách nhiệm vụ nhóm
class GroupTaskList extends StatelessWidget {
  final Map<String, dynamic> group;
  const GroupTaskList({required this.group});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final groupId = group['id'];
    final memberNames = (group['memberNames'] ?? []) as List<dynamic>;
    final memberAvatars = (group['memberAvatars'] ?? []) as List<dynamic>;
    final members = (group['members'] ?? []) as List<dynamic>;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('group_tasks')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải nhiệm vụ nhóm: \n${snapshot.error}', textAlign: TextAlign.center));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final visibleTo = data['visibleTo'] as List<dynamic>?;
            if (visibleTo == null) return true;
            return user != null && visibleTo.contains(user.uid);
          } catch (e) {
            return false;
          }
        }).toList();
        if (filtered.isEmpty) {
          return Center(child: Text('Chưa có nhiệm vụ nào trong nhóm này.'));
        }
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = filtered[i].data() as Map<String, dynamic>;
            data['id'] = filtered[i].id;
            final title = data['title'] ?? '';
            final desc = data['desc'] ?? '';
            final date = data['date'] ?? '';
            final time = data['time'] ?? '';
            final color = data['color'] != null ? Color(data['color']) : Color(0xFF667eea);
            final important = data['important'] == true;
            final visibleTo = data['visibleTo'] as List<dynamic>?;
            List<int> relatedIndexes = [];
            if (visibleTo == null) {
              relatedIndexes = List.generate(members.length, (i) => i);
            } else {
              for (int i = 0; i < members.length; i++) {
                if (visibleTo.contains(members[i])) relatedIndexes.add(i);
              }
            }
            return GestureDetector(
              onTap: () {
                _showGroupTaskDetail(context, data, group: group);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: important ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            data['type'] == 'nhiem_vu' ? Icons.checklist : Icons.event,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        if (important)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.star, color: Colors.amber, size: 22),
                          ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(desc, style: TextStyle(color: Colors.grey[700])),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(date, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(time, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                        Spacer(),
                        ...relatedIndexes.take(5).map((idx) {
                          final name = idx < memberNames.length ? memberNames[idx] : 'M';
                          final colorValue = idx < memberAvatars.length ? memberAvatars[idx] : Colors.grey.value;
                          return Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: Color(colorValue),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }),
                        if (relatedIndexes.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('+${relatedIndexes.length - 5}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Hàm hiển thị chi tiết nhiệm vụ nhóm
void _showGroupTaskDetail(BuildContext context, Map<String, dynamic> task, {Map<String, dynamic>? group}) {
  final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(task['color'] ?? 0xFF667eea),
                  width: 3,
                ),
              ),
              child: Icon(
                task['type'] == 'nhiem_vu' ? Icons.checklist : Icons.event,
                color: Color(task['color'] ?? 0xFF667eea),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              task['title'] ?? '',
              style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if ((task['desc'] ?? '').toString().isNotEmpty)
              Text(
                task['desc'] ?? '',
                style: calendarFont.copyWith(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, color: Color(task['color'] ?? 0xFF667eea)),
                const SizedBox(width: 8),
                Text(
                  (task['time'] ?? '') + (task['date'] != null ? '  ' + task['date'] : ''),
                  style: calendarFont.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => GroupAddTaskDialog(
                        group: group ?? {},
                        onTaskAdded: () {},
                        editTask: task,
                      ),
                    );
                  },
                  icon: Icon(Icons.edit, color: Colors.white),
                  label: Text('Sửa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(task['color'] ?? 0xFF667eea),
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
} 