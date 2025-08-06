import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'group_screen.dart';

class GroupTaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Map<String, dynamic> group;

  const GroupTaskDetailScreen({
    Key? key,
    required this.task,
    required this.group,
  }) : super(key: key);

  @override
  State<GroupTaskDetailScreen> createState() => _GroupTaskDetailScreenState();
}

class _GroupTaskDetailScreenState extends State<GroupTaskDetailScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _taskId;

  @override
  void initState() {
    super.initState();
    _initializeTaskId();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Khởi tạo taskId
  Future<void> _initializeTaskId() async {
    String taskId = widget.task['id'] ?? '';
    if (taskId.isEmpty) {
      // Nếu không có id, thử tìm task theo title và groupId
      try {
        final query = await FirebaseFirestore.instance
            .collection('group_tasks')
            .where('title', isEqualTo: widget.task['title'])
            .where('groupId', isEqualTo: widget.task['groupId'])
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          taskId = query.docs.first.id;
        }
      } catch (e) {
        print('Lỗi khi tìm taskId: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _taskId = taskId;
      });
    }
  }

  // Gửi comment mới
  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (_taskId == null || _taskId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang tải thông tin task...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Thêm comment vào Firestore
      await FirebaseFirestore.instance
          .collection('group_tasks')
          .doc(_taskId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': user!.uid,
        'userName': user!.displayName ?? user!.email?.split('@')[0] ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear input và scroll xuống comment mới nhất
      _commentController.clear();
      
      // Scroll xuống comment mới nhất sau khi build xong
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi bình luận thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi bình luận: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Xóa comment (chỉ người viết mới xóa được)
  Future<void> _deleteComment(String commentId) async {
    if (_taskId == null || _taskId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang tải thông tin task...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('group_tasks')
          .doc(_taskId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa bình luận: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Hiển thị dialog sửa task
  void _showEditTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => GroupAddTaskDialog(
        group: widget.group,
        onTaskAdded: () {
          Navigator.pop(context);
          setState(() {}); // Refresh task data
        },
        editTask: widget.task,
      ),
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chi tiết nhiệm vụ',
          style: calendarFont.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Color(widget.task['color'] ?? 0xFF667eea)),
            onPressed: _showEditTaskDialog,
            tooltip: 'Sửa nhiệm vụ',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // Phần thông tin nhiệm vụ
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(widget.task['color'] ?? 0xFF667eea),
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    widget.task['type'] == 'nhiem_vu' ? Icons.checklist : Icons.event,
                    color: Color(widget.task['color'] ?? 0xFF667eea),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.task['title'] ?? '',
                  style: calendarFont.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                if ((widget.task['desc'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.task['desc'] ?? '',
                    style: calendarFont.copyWith(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Color(widget.task['color'] ?? 0xFF667eea),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (widget.task['time'] ?? '') + 
                      (widget.task['date'] != null ? '  ' + widget.task['date'] : ''),
                      style: calendarFont.copyWith(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Phần bình luận
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header bình luận
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(widget.task['color'] ?? 0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Color(widget.task['color'] ?? 0xFF667eea),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bình luận',
                          style: calendarFont.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(widget.task['color'] ?? 0xFF667eea),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Danh sách bình luận
                  Expanded(
                    child: _taskId == null || _taskId!.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Đang tải bình luận...',
                                  style: calendarFont.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('group_tasks')
                                .doc(_taskId)
                                .collection('comments')
                                .orderBy('timestamp', descending: false)
                                .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Lỗi khi tải bình luận: ${snapshot.error}',
                                style: calendarFont.copyWith(
                                  color: Colors.red[600],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final comments = snapshot.data?.docs ?? [];

                        if (comments.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Chưa có bình luận nào',
                                  style: calendarFont.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hãy là người đầu tiên bình luận!',
                                  style: calendarFont.copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(16),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index].data() as Map<String, dynamic>;
                            final commentId = comments[index].id;
                            final isMyComment = comment['userId'] == user?.uid;
                            final userName = comment['userName'] ?? 'User';
                            final commentText = comment['text'] ?? '';
                            final timestamp = comment['timestamp'] as Timestamp?;

                            return Container(
                              margin: EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar với màu dựa trên user
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(widget.task['color'] ?? 0xFF667eea),
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Nội dung comment
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header với tên và thời gian
                                        Row(
                                          children: [
                                            Text(
                                              userName,
                                              style: calendarFont.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              timestamp != null
                                                  ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                                                  : 'Vừa xong',
                                              style: calendarFont.copyWith(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (isMyComment) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Bạn',
                                                  style: calendarFont.copyWith(
                                                    fontSize: 10,
                                                    color: Colors.blue[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Nội dung bình luận
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isMyComment
                                                ? Color(widget.task['color'] ?? 0xFF667eea).withOpacity(0.1)
                                                : Colors.grey[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isMyComment
                                                  ? Color(widget.task['color'] ?? 0xFF667eea).withOpacity(0.3)
                                                  : Colors.grey.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            commentText,
                                            style: calendarFont.copyWith(
                                              fontSize: 14,
                                              color: Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Nút xóa (chỉ hiển thị cho comment của mình)
                                  if (isMyComment)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: Colors.grey[600],
                                      ),
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _deleteComment(commentId);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
                                              const SizedBox(width: 8),
                                              Text('Xóa bình luận'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Input gửi bình luận
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Viết bình luận...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(widget.task['color'] ?? 0xFF667eea),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.send, 
                              color: Colors.white, 
                              size: 20
                            ),
                            onPressed: _sendComment,
                            tooltip: 'Gửi bình luận',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// GroupAddTaskDialog is imported from group_screen.dart 