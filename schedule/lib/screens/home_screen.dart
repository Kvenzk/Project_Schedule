import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);
  static late BuildContext rootContext;

  @override
  Widget build(BuildContext context) {
    rootContext = context;
    return CustomBottomNavBar();
  }
}

class CustomBottomNavBar extends StatefulWidget {
  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  int _selectedIndex = 0;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late List<String> _months;
  late int _selectedMonth;
  late int _selectedYear;

  // Quản lý tuần động
  late DateTime _startOfWeek;
  late DateTime _endOfWeek;
  late int _selectedDayIndex;
  late List<Map<String, dynamic>> _daysOfWeek;

  final Color mainColor = const Color(0xFF667eea);
  final Color secondaryColor = const Color(0xFF764ba2);

  // 1. Thêm biến trạng thái để biết có lỗi tiêu đề không
  bool _titleError = false;

  // Thêm biến cho cài đặt
  bool _weekStartsFromSunday = false;

  // --- XÓA các biến và widget liên quan đến alarm, reminder ở cả form thêm và sửa ---
  // --- THÊM biến trạng thái cho lặp lại và quan trọng ---
  bool repeatWeekly = false;
  int repeatCount = 1;
  bool important = false;


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedMonth = _focusedDay.month;
    _selectedYear = _focusedDay.year;
    _months = List.generate(12, (index) => DateFormat.MMMM('vi_VN').format(DateTime(0, index + 1)));
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weekStartsFromSunday = prefs.getBool('weekStartsFromSunday') ?? false;
    });
    _initCurrentWeek();
  }

  void _initCurrentWeek() {
    final now = DateTime.now();
    if (_weekStartsFromSunday) {
      // Bắt đầu từ Chủ nhật (weekday = 7)
      _startOfWeek = now.subtract(Duration(days: now.weekday == 7 ? 0 : now.weekday));
      _endOfWeek = _startOfWeek.add(const Duration(days: 6));
    } else {
      // Bắt đầu từ Thứ 2 (weekday = 1)
      _startOfWeek = now.subtract(Duration(days: now.weekday == 7 ? 6 : now.weekday - 1));
      _endOfWeek = _startOfWeek.add(const Duration(days: 6));
    }
    _selectedDayIndex = now.difference(_startOfWeek).inDays;
    _updateDaysOfWeek();
  }

  void _updateDaysOfWeek() {
    _daysOfWeek = List.generate(7, (i) {
      final d = _startOfWeek.add(Duration(days: i));
      return {
        'label': _weekdayLabelVN(d.weekday),
        'date': d.day,
        'dateTime': d,
      };
    });
  }

  void _goToPrevWeek() {
    setState(() {
      _startOfWeek = _startOfWeek.subtract(const Duration(days: 7));
      _endOfWeek = _startOfWeek.add(const Duration(days: 6));
      _updateDaysOfWeek();
      // Nếu là tuần hiện tại thì chọn ngày hôm nay, nếu không thì chọn ngày đầu tuần
      final now = DateTime.now();
      final startOfThisWeek = _weekStartsFromSunday 
          ? now.subtract(Duration(days: now.weekday == 7 ? 0 : now.weekday))
          : now.subtract(Duration(days: now.weekday == 7 ? 6 : now.weekday - 1));
      if (_isSameDay(_startOfWeek, startOfThisWeek)) {
        _selectedDayIndex = now.difference(_startOfWeek).inDays;
      } else {
        _selectedDayIndex = 0;
      }
    });
  }

  void _goToNextWeek() {
    setState(() {
      _startOfWeek = _startOfWeek.add(const Duration(days: 7));
      _endOfWeek = _startOfWeek.add(const Duration(days: 6));
      _updateDaysOfWeek();
      // Nếu là tuần hiện tại thì chọn ngày hôm nay, nếu không thì chọn ngày đầu tuần
      final now = DateTime.now();
      final startOfThisWeek = _weekStartsFromSunday 
          ? now.subtract(Duration(days: now.weekday == 7 ? 0 : now.weekday))
          : now.subtract(Duration(days: now.weekday == 7 ? 6 : now.weekday - 1));
      if (_isSameDay(_startOfWeek, startOfThisWeek)) {
        _selectedDayIndex = now.difference(_startOfWeek).inDays;
      } else {
        _selectedDayIndex = 0;
      }
    });
  }

  String _weekdayLabelVN(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
        return 'CN';
      default:
        return '';
    }
  }

  String formatVN(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // Theo dõi ngày thực để tự động cập nhật tuần nếu sang tuần mới
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoUpdateWeekIfNeeded();
    });
  }

  void _autoUpdateWeekIfNeeded() {
    final now = DateTime.now();
    final startOfThisWeek = _weekStartsFromSunday 
        ? now.subtract(Duration(days: now.weekday == 7 ? 0 : now.weekday))
        : now.subtract(Duration(days: now.weekday == 7 ? 6 : now.weekday - 1));
    if (!_isSameDay(_startOfWeek, startOfThisWeek)) {
      setState(() {
        _initCurrentWeek();
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onMonthChanged(int? month) {
    if (month != null) {
      setState(() {
        _selectedMonth = month;
        _focusedDay = DateTime(_selectedYear, _selectedMonth, 1);
      });
    }
  }

  void _onYearChanged(int? year) {
    if (year != null) {
      setState(() {
        _selectedYear = year;
        _focusedDay = DateTime(_selectedYear, _selectedMonth, 1);
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      // Xử lý khi nhấn nút thêm
    } else {
      setState(() {
        _selectedIndex = index;
        if (index == 1) {
          _initCurrentWeek();
        }
        if (index == 0) {
          _selectedDay = DateTime.now();
          _focusedDay = DateTime.now();
        }
      });
    }
  }

  void _showAddTaskForm() {
    // Đưa các biến state ra ngoài StatefulBuilder để không bị reset
    DateTime selectedDateTime = DateTime.now();
    int _activityIndex = 0;
    final List<Color> colorOptions = [Colors.green, Colors.orange, Colors.pink, Colors.purple, Colors.blue, Colors.black, Colors.teal];
    Color selectedColor = colorOptions[0];
    TextEditingController titleController = TextEditingController();
    TextEditingController detailController = TextEditingController();
    String _reminderValue = 'Đúng giờ';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _pickDateTime() async {
              final DateTime? pickedDate = await showDatePicker(
                context: HomeScreen.rootContext,
                initialDate: selectedDateTime,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                locale: const Locale('vi', 'VN'),
              );
              if (pickedDate != null) {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: HomeScreen.rootContext,
                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                );
                if (pickedTime != null) {
                  setModalState(() {
                    selectedDateTime = DateTime(
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
            String formatVN(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            String formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.6,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return Container(
                  color: const Color(0xFFF3F4F6), // Nền xám nhạt
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Thanh tiêu đề
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF667eea)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Flexible(
                            child: Text('Thêm thời gian biểu',
                              style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Color(0xFF667eea)),
                            onPressed: () async {
                              if (titleController.text.trim().isEmpty) {
                                setModalState(() {
                                  _titleError = true;
                                });
                                return;
                              } else {
                                setModalState(() {
                                  _titleError = false;
                                });
                              }
                              final taskDate = DateFormat('yyyy-MM-dd').format(selectedDateTime);
                              final taskTime = DateFormat('HH:mm').format(selectedDateTime);
                              for (int i = 0; i < (repeatWeekly ? repeatCount : 1); i++) {
                                final date = selectedDateTime.add(Duration(days: 7 * i));
                                await FirebaseFirestore.instance.collection('tasks').add({
                                  'title': titleController.text,
                                  'desc': detailController.text,
                                  'date': DateFormat('yyyy-MM-dd').format(date),
                                  'time': DateFormat('HH:mm').format(date),
                                  'color': selectedColor.value,
                                  'type': _activityIndex == 0 ? 'nhiem_vu' : 'su_kien',
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'uid': FirebaseAuth.instance.currentUser?.uid,
                                  'completed': false,
                                  if (repeatWeekly) 'repeatWeekly': true,
                                  if (repeatWeekly) 'repeatCount': repeatCount,
                                  if (important) 'important': true,
                                });
                              }
                              // Cập nhật ngày đang chọn về ngày vừa lưu
                              if (mounted) {
                                setState(() {
                                  _focusedDay = selectedDateTime;
                                  _selectedDay = selectedDateTime;
                                  // Tìm lại tuần chứa ngày này
                                  _startOfWeek = selectedDateTime.subtract(Duration(days: selectedDateTime.weekday == 7 ? 6 : selectedDateTime.weekday - 1));
                                  _endOfWeek = _startOfWeek.add(const Duration(days: 6));
                                  _daysOfWeek = List.generate(7, (i) {
                                    final d = _startOfWeek.add(Duration(days: i));
                                    return {
                                      'label': _weekdayLabelVN(d.weekday),
                                      'date': d.day,
                                      'dateTime': d,
                                    };
                                  });
                                  _selectedDayIndex = selectedDateTime.difference(_startOfWeek).inDays;
                                });
                              }
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Hoạt động
                      Container(
                        padding: const EdgeInsets.all(12),
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
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => setModalState(() => _activityIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _activityIndex == 0 ? const Color(0xFF667eea).withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.checklist, color: _activityIndex == 0 ? Color(0xFF667eea) : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('Nhiệm vụ', style: calendarFont.copyWith(color: _activityIndex == 0 ? Color(0xFF667eea) : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setModalState(() => _activityIndex = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _activityIndex == 1 ? const Color(0xFF667eea).withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event, color: _activityIndex == 1 ? Color(0xFF667eea) : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('Sự kiện', style: calendarFont.copyWith(color: _activityIndex == 1 ? Color(0xFF667eea) : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tiêu đề
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: 'Tiêu đề',
                            hintStyle: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                            border: InputBorder.none,
                            enabledBorder: _titleError
                                ? OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red, width: 1.5),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : InputBorder.none,
                            focusedBorder: _titleError
                                ? OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red, width: 1.5),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : InputBorder.none,
                            suffixIcon: _titleError
                                ? Icon(Icons.error, color: Colors.red)
                                : null,
                          ),
                          style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                          onChanged: (_) {
                            if (_titleError) {
                              setModalState(() {
                                _titleError = false;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Thêm chi tiết
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: detailController,
                          decoration: InputDecoration(
                            hintText: 'Thêm chi tiết',
                            hintStyle: calendarFont.copyWith(fontSize: 15, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                          style: calendarFont.copyWith(fontSize: 15),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Thời gian
                      Container(
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
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickDateTime,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667eea).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.access_time, color: Color(0xFF667eea), size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Thời gian', style: calendarFont.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text(formatVN(selectedDateTime), style: calendarFont),
                                  const SizedBox(width: 8),
                                  Text(formatTime(selectedDateTime), style: calendarFont),
                                ],
                              ),
                              const Icon(Icons.edit, color: Color(0xFF667eea)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Màu sắc
                      Container(
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
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.color_lens, color: Color(0xFF667eea), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text('Màu sắc', style: calendarFont),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final color in [
                                  Color(0xFF7C3AED),
                                  Color(0xFFF59E42),
                                  Color(0xFFE64980),
                                  Color(0xFF22D3EE),
                                  Color(0xFF10B981),
                                  Color(0xFF222222),
                                  Color(0xFF4ADE80),
                                ])
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedColor = color;
                                      });
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selectedColor == color ? Color(0xFF667eea) : Colors.grey.shade300,
                                          width: selectedColor == color ? 3 : 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Lặp lại hàng tuần
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
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
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.repeat, color: Color(0xFF667eea), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: repeatWeekly,
                                  onChanged: (val) {
                                    setModalState(() {
                                      repeatWeekly = val!;
                                      if (!repeatWeekly) repeatCount = 1;
                                    });
                                  },
                                ),
                                const Text('Áp dụng lặp lại cho các tuần'),
                              ],
                            ),
                            if (repeatWeekly)
                              Padding(
                                padding: const EdgeInsets.only(left: 32, top: 8),
                                child: DropdownButton<int>(
                                  value: repeatCount,
                                  items: List.generate(8, (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text('${i + 1} tuần'),
                                  )),
                                  onChanged: (val) {
                                    setModalState(() {
                                      repeatCount = val!;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Quan trọng
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
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
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF667eea).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star, color: Color(0xFF667eea), size: 18),
                            ),
                            const SizedBox(width: 8),
                            Checkbox(
                              value: important,
                              onChanged: (val) {
                                setModalState(() { important = val!; });
                              },
                            ),
                            const Text('Quan trọng'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Nút apply
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 1. Thêm hàm showTaskDetail để hiển thị chi tiết task:
  void _showTaskDetail(BuildContext context, Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: task['completed'] == true ? null : () async {
                        if (task['id'] != null) {
                          await FirebaseFirestore.instance.collection('tasks').doc(task['id']).update({'completed': true});
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(Icons.check, color: Colors.white),
                      label: Text('Hoàn thành'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Đóng trang chi tiết trước
                        _showEditTaskForm(context, task);
                      },
                      icon: Icon(Icons.edit, color: Colors.white),
                      label: Text('Sửa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(task['color'] ?? 0xFF667eea),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // 1. Thêm hàm showEditTaskForm để mở form sửa với dữ liệu task:
  void _showEditTaskForm(BuildContext context, Map<String, dynamic> task) {
    DateTime selectedDateTime = DateTime.tryParse(task['dateTime'] ?? '') ?? DateTime.now();
    int _activityIndex = (task['type'] == 'su_kien') ? 1 : 0;
    final List<Color> colorOptions = [
      Color(0xFF7C3AED),
      Color(0xFFF59E42),
      Color(0xFFE64980),
      Color(0xFF22D3EE),
      Color(0xFF10B981),
      Color(0xFF222222),
      Color(0xFF4ADE80),
    ];
    Color selectedColor = colorOptions.firstWhere(
      (c) => c.value == (task['color'] ?? colorOptions[0].value),
      orElse: () => colorOptions[0],
    );
    TextEditingController titleController = TextEditingController(text: task['title'] ?? '');
    TextEditingController detailController = TextEditingController(text: task['desc'] ?? '');
    bool repeatWeekly = task['repeatWeekly'] ?? false;
    int repeatCount = task['repeatCount'] ?? 1;
    bool important = task['important'] ?? false;
    bool _titleError = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _pickDateTime() async {
              final DateTime? pickedDate = await showDatePicker(
                context: HomeScreen.rootContext,
                initialDate: selectedDateTime,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                locale: const Locale('vi', 'VN'),
              );
              if (pickedDate != null) {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: HomeScreen.rootContext,
                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                );
                if (pickedTime != null) {
                  setModalState(() {
                    selectedDateTime = DateTime(
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
            String formatVN(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            String formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.6,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return Container(
                  color: const Color(0xFFF3F4F6),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                      // Thanh tiêu đề
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF667eea)),
                          onPressed: () => Navigator.pop(context),
                        ),
                          Flexible(
                            child: Text('Sửa thời gian biểu',
                              style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.check, color: Color(0xFF667eea)),
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty) {
                              setModalState(() {
                                _titleError = true;
                              });
                              return;
                            } else {
                              setModalState(() {
                                _titleError = false;
                              });
                            }
                              // Nếu lặp lại tuần, tạo/cập nhật nhiều task
                              if (repeatWeekly) {
                                for (int i = 0; i < repeatCount; i++) {
                                  final date = selectedDateTime.add(Duration(days: 7 * i));
                                  if (i == 0) {
                                    // Update task hiện tại
                            await FirebaseFirestore.instance.collection('tasks').doc(task['id']).update({
                                      'title': titleController.text,
                                      'desc': detailController.text,
                                      'dateTime': date.toIso8601String(),
                                      'date': DateFormat('yyyy-MM-dd').format(date),
                                      'time': DateFormat('HH:mm').format(date),
                                      'color': selectedColor.value,
                                      'type': _activityIndex == 0 ? 'nhiem_vu' : 'su_kien',
                                      'repeatWeekly': true,
                                      'repeatCount': repeatCount,
                                      'important': important,
                                    });
                                  } else {
                                    // Tạo task mới cho các tuần tiếp theo
                                    await FirebaseFirestore.instance.collection('tasks').add({
                                      'title': titleController.text,
                                      'desc': detailController.text,
                                      'dateTime': date.toIso8601String(),
                                      'date': DateFormat('yyyy-MM-dd').format(date),
                                      'time': DateFormat('HH:mm').format(date),
                                      'color': selectedColor.value,
                                      'type': _activityIndex == 0 ? 'nhiem_vu' : 'su_kien',
                                      'repeatWeekly': true,
                                      'repeatCount': repeatCount,
                                      'important': important,
                                      'uid': FirebaseAuth.instance.currentUser?.uid,
                                      'completed': false,
                                    });
                                  }
                                }
                              } else {
                                // Chỉ update task hiện tại
                                await FirebaseFirestore.instance.collection('tasks').doc(task['id']).update({
                                  'title': titleController.text,
                                  'desc': detailController.text,
                              'dateTime': selectedDateTime.toIso8601String(),
                              'date': DateFormat('yyyy-MM-dd').format(selectedDateTime),
                              'time': DateFormat('HH:mm').format(selectedDateTime),
                              'color': selectedColor.value,
                                  'type': _activityIndex == 0 ? 'nhiem_vu' : 'su_kien',
                                  'repeatWeekly': false,
                                  'repeatCount': 1,
                              'important': important,
                            });
                              }
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Hoạt động
                    Container(
                      padding: const EdgeInsets.all(12),
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
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                              onTap: () => setModalState(() => _activityIndex = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: _activityIndex == 0 ? const Color(0xFF667eea).withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                    Icon(Icons.checklist, color: _activityIndex == 0 ? Color(0xFF667eea) : Colors.grey),
                                  const SizedBox(width: 6),
                                    Text('Nhiệm vụ', style: calendarFont.copyWith(color: _activityIndex == 0 ? Color(0xFF667eea) : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                              onTap: () => setModalState(() => _activityIndex = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: _activityIndex == 1 ? const Color(0xFF667eea).withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                    Icon(Icons.event, color: _activityIndex == 1 ? Color(0xFF667eea) : Colors.grey),
                                  const SizedBox(width: 6),
                                    Text('Sự kiện', style: calendarFont.copyWith(color: _activityIndex == 1 ? Color(0xFF667eea) : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tiêu đề
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Tiêu đề',
                          hintStyle: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                          border: InputBorder.none,
                          enabledBorder: _titleError
                              ? OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : InputBorder.none,
                          focusedBorder: _titleError
                              ? OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : InputBorder.none,
                          suffixIcon: _titleError
                              ? Icon(Icons.error, color: Colors.red)
                              : null,
                        ),
                        style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                        onChanged: (_) {
                          if (_titleError) {
                            setModalState(() {
                              _titleError = false;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Thêm chi tiết
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: detailController,
                        decoration: InputDecoration(
                          hintText: 'Thêm chi tiết',
                          hintStyle: calendarFont.copyWith(fontSize: 15, color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        style: calendarFont.copyWith(fontSize: 15),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Thời gian
                    Container(
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
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                          onTap: _pickDateTime,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.access_time, color: Color(0xFF667eea), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text('Thời gian', style: calendarFont.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                  Text(formatVN(selectedDateTime), style: calendarFont),
                                const SizedBox(width: 8),
                                  Text(formatTime(selectedDateTime), style: calendarFont),
                              ],
                            ),
                            const Icon(Icons.edit, color: Color(0xFF667eea)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                      // Màu sắc
                    Container(
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
                      ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                                  child: const Icon(Icons.color_lens, color: Color(0xFF667eea), size: 18),
                          ),
                          const SizedBox(width: 8),
                                Text('Màu sắc', style: calendarFont),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final color in colorOptions)
                                  GestureDetector(
                                    onTap: () {
                              setModalState(() {
                                        selectedColor = color;
                              });
                            },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selectedColor == color ? Color(0xFF667eea) : Colors.grey.shade300,
                                          width: selectedColor == color ? 3 : 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                      // Lặp lại hàng tuần
                    Container(
                      padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
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
                      ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                  child: const Icon(Icons.repeat, color: Color(0xFF667eea), size: 18),
                              ),
                              const SizedBox(width: 8),
                                Checkbox(
                                  value: repeatWeekly,
                                  onChanged: (val) {
                                    setModalState(() {
                                      repeatWeekly = val!;
                                      if (!repeatWeekly) repeatCount = 1;
                                    });
                                  },
                                ),
                                const Text('Áp dụng lặp lại cho các tuần'),
                              ],
                            ),
                            if (repeatWeekly)
                              Padding(
                                padding: const EdgeInsets.only(left: 32, top: 8),
                                child: DropdownButton<int>(
                                  value: repeatCount,
                                  items: List.generate(8, (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text('${i + 1} tuần'),
                                  )),
                            onChanged: (val) {
                              setModalState(() {
                                      repeatCount = val!;
                              });
                            },
                                ),
                          ),
                        ],
                      ),
                    ),
                      // Quan trọng
                    Container(
                      padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
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
                      ),
                        child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              child: const Icon(Icons.star, color: Color(0xFF667eea), size: 18),
                              ),
                              const SizedBox(width: 8),
                            Checkbox(
                              value: important,
                              onChanged: (val) {
                                setModalState(() { important = val!; });
                                  },
                            ),
                            const Text('Quan trọng'),
                            ],
                          ),
                      ),
                    const SizedBox(height: 24),
                    // Nút apply
                    const SizedBox(height: 24),
                  ],
              ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Hàm chuyển sang tab Quản lý và set ngày
  void _goToManagementForDay(DateTime day) {
    setState(() {
      _selectedIndex = 1;
      // Tìm index của ngày trong tuần hiện tại, nếu không có thì cập nhật tuần
      int idx = _daysOfWeek.indexWhere((d) => _isSameDay(d['dateTime'], day));
      if (idx != -1) {
        _selectedDayIndex = idx;
      } else {
        // Nếu ngày không thuộc tuần hiện tại, cập nhật tuần
        _startOfWeek = day.subtract(Duration(days: day.weekday == 7 ? 6 : day.weekday - 1));
        _endOfWeek = _startOfWeek.add(const Duration(days: 6));
        _daysOfWeek = List.generate(7, (i) {
          final d = _startOfWeek.add(Duration(days: i));
          return {
            'label': _weekdayLabelVN(d.weekday),
            'date': d.day,
            'dateTime': d,
          };
        });
        _selectedDayIndex = day.difference(_startOfWeek).inDays;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        color: _selectedIndex == 0 ? const Color(0xFFF5F6FA) : (_selectedIndex == 1 ? const Color(0xFFF5F5F5) : const Color(0xFFF5F6FA)),
        // Xóa decoration gradient cho các tab khác
        child: SafeArea(
          child: _selectedIndex == 0 ? _buildCalendarPage()
            : _selectedIndex == 1 ? _buildManagementPage()
            : _selectedIndex == 3 ? GroupScreen()
            : _selectedIndex == 4 ? SettingsScreen(
                onWeekStartChanged: _onWeekStartChanged,
                weekStartsFromSunday: _weekStartsFromSunday,
              )
            : Center(
                child: Text(
                  _getPageTitle(_selectedIndex),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskForm,
        backgroundColor: mainColor,
        child: const Icon(Icons.add, size: 32),
        elevation: 4,
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white.withOpacity(0.85),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(Icons.calendar_today, "Lịch", 0),
              _buildNavItem(Icons.manage_accounts, "Quản lý", 1),
              const SizedBox(width: 48), 
              _buildNavItem(Icons.group, "Nhóm", 3),
              _buildNavItem(Icons.settings, "Cài đặt", 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarPage() {
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final user = FirebaseAuth.instance.currentUser;
    int avatarColorValue = Colors.grey.value;
    // Lấy màu avatar từ Firestore
    if (user != null) {
      // Không dùng await vì build là sync, chỉ lấy màu mặc định, khi vào ProfileScreen sẽ luôn đúng
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists && doc.data()!.containsKey('avatarColor')) {
          avatarColorValue = doc['avatarColor'];
        }
      });
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Dropdown tháng và năm bên trái
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.black87, size: 18),
                      const SizedBox(width: 4),
                      DropdownButton<int>(
                        value: _selectedMonth,
                        underline: const SizedBox(),
                        dropdownColor: Colors.white,
                        style: calendarFont.copyWith(color: Colors.black87, fontSize: 16),
                        items: List.generate(
                          12,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(_months[index].capitalize(), style: calendarFont.copyWith(color: Colors.black87)),
                          ),
                        ),
                        onChanged: _onMonthChanged,
                      ),
                      DropdownButton<int>(
                        value: _selectedYear,
                        underline: const SizedBox(),
                        dropdownColor: Colors.white,
                        style: calendarFont.copyWith(color: Colors.black87, fontSize: 16),
                        items: List.generate(
                          10,
                          (index) => DropdownMenuItem(
                            value: DateTime.now().year - 5 + index,
                            child: Text('${DateTime.now().year - 5 + index}', style: calendarFont.copyWith(color: Colors.black87)),
                          ),
                        ),
                        onChanged: _onYearChanged,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // XÓA ICON CHUÔNG Ở ĐÂY
                // Nút avatar (dùng emoji mặc định)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ProfileScreen()),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(avatarColorValue),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Builder(
                        builder: (context) {
                          final user = FirebaseAuth.instance.currentUser;
                          final displayName = user?.displayName ?? '';
                          final email = user?.email ?? '';
                          return Text(
                            (displayName.isNotEmpty ? displayName[0] : (email.isNotEmpty ? email[0] : '?')).toUpperCase(),
                            style: const TextStyle(fontSize: 24, color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: StreamBuilder<QuerySnapshot>(
              stream: (() {
                final user = FirebaseAuth.instance.currentUser;
                final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
                final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
                return FirebaseFirestore.instance
                  .collection('tasks')
                  .where('uid', isEqualTo: user?.uid)
                  .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
                  .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
                  .snapshots();
              })(),
              builder: (context, snapshot) {
                // Xóa hiệu ứng Hoàn thành và Chưa hoàn thành, chỉ giữ hiệu ứng cho ngày hôm nay
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TableCalendar(
                        locale: 'vi_VN',
                        firstDay: DateTime(2000),
                        lastDay: DateTime(2100),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          _goToManagementForDay(selectedDay);
                        },
                        calendarFormat: CalendarFormat.month,
                        headerVisible: false,
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: BoxDecoration(), // Không dùng marker
                          weekendTextStyle: calendarFont.copyWith(color: Colors.black87),
                          defaultTextStyle: calendarFont.copyWith(color: Colors.black87),
                          outsideTextStyle: calendarFont.copyWith(color: Colors.grey[400]),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: calendarFont.copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
                          weekendStyle: calendarFont.copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                        calendarBuilders: CalendarBuilders(
                          // Không custom hiệu ứng nữa, chỉ để mặc định
                        ),
                      ),
                    ),
                    // Xóa phần chú thích Hoàn thành và Chưa hoàn thành
                    // const SizedBox(height: 8),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     _buildLegendDot(Colors.green, 'Hoàn thành'),
                    //     const SizedBox(width: 16),
                    //     _buildLegendDot(Colors.black, 'Chưa hoàn thành'),
                    //   ],
                    // ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18), // Tăng khoảng cách giữa lịch và nhiệm vụ hằng ngày
          // Today Task Section Title and Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.today, color: mainColor, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Nhiệm vụ hằng ngày',
                      style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    _goToManagementForDay(_selectedDay ?? DateTime.now());
                  },
                  icon: Text(
                    'Tất cả',
                    style: calendarFont.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: mainColor),
                  ),
                  label: Icon(Icons.keyboard_double_arrow_right, color: mainColor, size: 20),
                  style: TextButton.styleFrom(
                    foregroundColor: mainColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          // Today Task Card (below title)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('date', isEqualTo: dateKey)
                  .where('uid', isEqualTo: user?.uid)
                  .orderBy('time')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi:   {snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Chưa có thời gian biểu',
                        style: calendarFont.copyWith(
                          color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                final task = docs.first.data() as Map<String, dynamic>;
                final taskCount = docs.length;
                final completedCount = docs.where((d) => (d.data() as Map<String, dynamic>)['completed'] == true).length;
                final progress = taskCount == 0 ? 0 : ((completedCount / taskCount) * 100).round();
                return GestureDetector(
                  onTap: () {
                    _goToManagementForDay(_selectedDay ?? DateTime.now());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        Text(
                          task['title'] ?? '',
                          style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task['desc'] ?? '',
                          style: calendarFont.copyWith(fontSize: 15, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress / 100.0,
                                  minHeight: 12, // tăng chiều cao
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$progress%',
                              style: calendarFont.copyWith(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble, color: Color(0xFF1DE9B6), size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Bạn có $taskCount nhiệm vụ',
                                    style: calendarFont.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Thêm widget Mức độ hoàn thành công việc
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 28, bottom: 0),
            child: Row(
              children: [
                Icon(Icons.bar_chart, color: mainColor),
                const SizedBox(width: 8),
                Text(
                  'Mức độ hoàn thành công việc',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _WeeklyTaskProgress(mainColor: mainColor),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementPage() {
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
    DateTime selectedDate = _daysOfWeek[_selectedDayIndex]['dateTime'];
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('tasks')
        .where('date', isEqualTo: dateKey)
        .where('uid', isEqualTo: user?.uid)
        .orderBy('time')
        .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data?.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng thời gian tuần và nút add
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 0, right: 0, bottom: 0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFFE8F0FE), // xanh nhạt
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        _goToPrevWeek();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${formatVN(_startOfWeek)} đến ${formatVN(_endOfWeek)}',
                          style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        _goToNextWeek();
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Thanh chọn ngày ngang
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_daysOfWeek.length, (i) {
                  final isSelected = i == _selectedDayIndex;
                  final day = _daysOfWeek[i];
                  return Column(
                    children: [
                      Text(
                        day['label'] as String,
                        style: calendarFont.copyWith(
                          color: isSelected ? Colors.black : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = i;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day['date'].toString(),
                            style: calendarFont.copyWith(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            // Danh sách task
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        "Chưa có thời gian biểu",
                        style: calendarFont.copyWith(
                          color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: tasks.length, // Số lượng task sẽ được lấy từ Firestore
                      separatorBuilder: (_, __) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 1,
                        color: Colors.grey.withOpacity(0.15),
                      ),
                      itemBuilder: (context, i) {
                        final task = tasks[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), // sát trái hơn
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Thời gian bên trái, căn giữa dọc, margin phải lớn hơn
                              Container(
                                width: 56,
                                alignment: Alignment.centerRight,
                                margin: const EdgeInsets.only(right: 20),
                                child: Text(
                                  task['time'] ?? '',
                                  style: calendarFont.copyWith(color: Colors.grey[700], fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Card task bên phải
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: task['completed'] == true ? Color(0xFFE8F5E9) : Colors.white, // xanh nhạt nếu hoàn thành
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (task['important'] == true) Icon(Icons.star, color: Colors.amber, size: 22),
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Color(task['color'] ?? 0xFF667eea),
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            task['type'] == 'nhiem_vu' ? Icons.checklist : Icons.event,
                                            color: Color(task['color'] ?? 0xFF667eea),
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(task['title'] ?? '', style: calendarFont.copyWith(fontWeight: FontWeight.bold)),
                                    subtitle: Text(task['desc'] ?? '', style: calendarFont),
                                    onTap: () {
                                      _showTaskDetail(context, task);
                                    },
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        task['completed'] == true
                                          ? Icon(Icons.check_circle, color: Colors.green, size: 28)
                                          : IconButton(
                                              icon: Icon(Icons.check_circle_outline, color: Colors.green),
                                              tooltip: 'Hoàn thành',
                                              onPressed: () async {
                                                if (task['id'] != null) {
                                                  await FirebaseFirestore.instance.collection('tasks').doc(task['id']).update({'completed': true});
                                                }
                                              },
                                            ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: Icon(Icons.close, color: Colors.grey),
                                          tooltip: 'Xóa',
                                          onPressed: () async {
                                            if (task['id'] != null) {
                                              await FirebaseFirestore.instance.collection('tasks').doc(task['id']).delete();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final Color selectedColor = mainColor;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? selectedColor : Colors.black54),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedColor : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Trang Lịch';
      case 1:
        return 'Trang Quản lý';
      case 3:
        return 'Trang Nhóm';
      case 4:
        return 'Trang Cài đặt';
      default:
        return 'Trang chính';
    }
  }

  // Thêm widget chú thích
  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  void _onWeekStartChanged(bool startsFromSunday) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weekStartsFromSunday', startsFromSunday);
    setState(() {
      _weekStartsFromSunday = startsFromSunday;
    });
    _initCurrentWeek();
  }
} 

// Extension để viết hoa chữ cái đầu
extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
} 

class _WeeklyTaskProgress extends StatelessWidget {
  final Color mainColor;
  const _WeeklyTaskProgress({required this.mainColor});

  @override
  Widget build(BuildContext context) {
    final calendarFont = GoogleFonts.montserrat(fontWeight: FontWeight.w500);
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: (() {
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday == 7 ? 6 : now.weekday - 1));
          final daysOfWeek = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
          final dayKeys = daysOfWeek.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
          return FirebaseFirestore.instance
              .collection('tasks')
              .where('uid', isEqualTo: user?.uid)
              .where('date', whereIn: dayKeys)
              .snapshots();
        })(),
        builder: (context, snapshot) {
          // Lấy tuần hiện tại mỗi lần build để luôn cập nhật ngày mới
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday == 7 ? 6 : now.weekday - 1));
          final daysOfWeek = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
          final dayKeys = daysOfWeek.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
          Map<String, List<Map<String, dynamic>>> dayTasks = { for (var k in dayKeys) k: [] };
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final date = data['date'];
              if (dayTasks.containsKey(date)) {
                dayTasks[date]!.add(data);
              }
            }
          }
          List<int> percents = dayKeys.map((key) {
            final tasks = dayTasks[key]!;
            if (tasks.isEmpty) return 0;
            final completed = tasks.where((t) => t['completed'] == true).length;
            return ((completed / tasks.length) * 100).round();
          }).toList();
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final d = daysOfWeek[i];
                  final percent = percents[i];
                  final weekdayVN = ['T2','T3','T4','T5','T6','T7','CN'][d.weekday == 7 ? 6 : d.weekday - 1];
                  final hasTask = dayTasks[dayKeys[i]]!.isNotEmpty;
                  final isDone = percent == 100;
                  final barColor = isDone ? Colors.green : (percent > 0 ? Color(0xFF7C3AED) : Colors.black);
                  final barHeight = hasTask ? (80 * percent / 100).clamp(8, 80).toDouble() : 80.0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        weekdayVN,
                        style: calendarFont.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: calendarFont.copyWith(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 6),
                      hasTask
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 32,
                                height: 80,
                                alignment: Alignment.bottomCenter,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 32,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$percent%',
                                style: calendarFont.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: barColor,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              CustomPaint(
                                size: const Size(32, 80),
                                painter: _StripedBarPainter(),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '',
                                style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendDot(Colors.green, 'Hoàn thành', calendarFont),
                  const SizedBox(width: 18),
                  _buildLegendDot(Color(0xFF7C3AED), 'Đang thực hiện', calendarFont),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// Widget vẽ sọc chéo cho ngày không có task
class _StripedBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final circleRect = Rect.fromCircle(center: center, radius: radius);
    final bgPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.fill;
    final stripePaint = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..strokeWidth = 4;
    // Vẽ nền tròn (giữa cột dài)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
      bgPaint,
    );
    // Vẽ sọc chéo trong hình chữ nhật bo góc
    for (double x = -size.height; x < size.width + size.height; x += 8) {
      final p1 = Offset(x, 0);
      final p2 = Offset(x + size.height, size.height);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ));
      canvas.drawPath(path, stripePaint);
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 

// Thêm hàm helper ở cuối file:
Widget _buildLegendDot(Color color, String label, TextStyle font) {
  return Row(
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: font.copyWith(fontSize: 14)),
    ],
  );
} 

// Thêm widget ProfileScreen ở cuối file
class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User? user;
  late String displayName;
  late String email;
  int avatarColorValue = Colors.grey.value; // mặc định
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
                  // Đã xóa phần số điện thoại
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

  // Thêm danh sách các ngày trong tuần
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
    // Đọc từ SharedPreferences nếu có, hoặc mặc định Thứ hai
    // Nếu đã lưu weekStart, lấy ra, nếu không thì lấy từ weekStartsFromSunday
    // (Để đơn giản, vẫn giữ weekStart là String)
    // Nếu muốn đồng bộ với weekStartsFromSunday, có thể truyền thêm giá trị String
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // KHÔNG có icon góc trái trên
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
          // Ảnh advertise.png
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
          // Thông tin cá nhân
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
          // Bắt đầu tuần từ
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
                    // Lưu vào SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('weekStart', val);
                    // Gọi callback nếu cần
                    // Bạn có thể truyền lại weekStart cho logic tuần ở các màn khác
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

// Thêm màn hình Nhóm
class GroupScreen extends StatefulWidget {
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  void _showCreateGroupDialog() async {
    showDialog(
      context: context,
      builder: (context) => GroupCreateDialog(onCreated: () => setState(() {})),
    );
  }

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
          // Nút Tham gia nhóm nhỏ gọn
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
    
    // Kiểm tra xem người dùng hiện tại có phải là chủ nhóm không (thành viên đầu tiên)
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
                  
                  // Lấy chữ cái đầu từ thông tin đã lưu trong group
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

        // Tìm index của người dùng hiện tại
        final userIndex = members.indexOf(currentUser.uid);
        if (userIndex == -1) return;

        // Xóa người dùng khỏi các danh sách
        members.removeAt(userIndex);
        if (userIndex < memberAvatars.length) memberAvatars.removeAt(userIndex);
        if (userIndex < memberEmails.length) memberEmails.removeAt(userIndex);
        if (userIndex < memberNames.length) memberNames.removeAt(userIndex);

        // Cập nhật nhóm trên Firebase
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
                
                // Lấy thông tin thành viên
                String memberName = 'Thành viên';
                String memberEmail = '';
                
                if (index < memberNames.length) {
                  memberName = memberNames[index]?.toString() ?? 'Thành viên';
                }
                
                if (index < memberEmails.length) {
                  memberEmail = memberEmails[index]?.toString() ?? '';
                }
                
                // Lấy màu avatar
                int avatarColor = Colors.grey.value;
                if (index < memberAvatars.length) {
                  avatarColor = memberAvatars[index];
                }
                
                // Lấy chữ cái đầu
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
                              top: -16, // cao hơn một chút
                              left: 10, // căn giữa đầu avatar (avatar radius 20, icon size 20)
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
      
      print('Creating group with code: $code'); // Debug log
      
      await FirebaseFirestore.instance.collection('groups').add({
        'name': _nameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'code': code,
        'members': [user.uid],
        'memberAvatars': [avatarColor],
        'memberEmails': [user.email ?? ''],
        'memberNames': [user.displayName ?? user.email?.split('@')[0] ?? 'User'],
      });
      
      print('Group created successfully'); // Debug log
      
      // Đóng dialog trước khi gọi callback
      Navigator.pop(context);
      
      // Gọi callback sau khi đã đóng dialog
      widget.onCreated();
      
    } catch (e) {
      print('Error creating group: $e'); // Debug log
      setState(() { 
        _error = 'Tạo nhóm thất bại: ${e.toString()}'; 
      });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<int> _getUserAvatarColor(User? user) async {
    if (user == null) return Colors.grey.value;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()!.containsKey('avatarColor')) {
      return doc['avatarColor'];
    }
    return Colors.grey.value;
  }

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

class GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({required this.group});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
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

  Future<void> _addTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final selectedUids = <String>[];
      for (int i = 0; i < _selectedMembers.length; i++) {
        if (_selectedMembers[i]) selectedUids.add(_members[i]);
      }
      // Luôn thêm chủ phòng (thành viên đầu tiên) vào visibleTo nếu chưa có
      if (_members.isNotEmpty && !selectedUids.contains(_members[0])) {
        selectedUids.insert(0, _members[0]);
      }
      if (widget.editTask != null && widget.editTask!['id'] != null) {
        // SỬA: update document cũ, KHÔNG tạo mới
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
        // THÊM MỚI
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
          // Hiển thị lỗi chi tiết
          return Center(child: Text('Lỗi tải nhiệm vụ nhóm: \\n${snapshot.error}', textAlign: TextAlign.center));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        // Lọc task theo quyền xem, dùng try-catch để tránh lỗi
        final filtered = docs.where((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final visibleTo = data['visibleTo'] as List<dynamic>?;
            if (visibleTo == null) return true;
            return user != null && visibleTo.contains(user.uid);
          } catch (e) {
            // Nếu lỗi parse, bỏ qua document này
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
            data['id'] = filtered[i].id; // Đảm bảo luôn có id khi sửa
            final title = data['title'] ?? '';
            final desc = data['desc'] ?? '';
            final date = data['date'] ?? '';
            final time = data['time'] ?? '';
            final color = data['color'] != null ? Color(data['color']) : Color(0xFF667eea);
            final important = data['important'] == true;
            final visibleTo = data['visibleTo'] as List<dynamic>?;
            // Lấy danh sách thành viên liên quan
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
                _showGroupTaskDetail(context, data, group: group); // Truyền đúng group và data có id
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

// 1. Thêm hàm hiển thị chi tiết task nhóm (dưới _showTaskDetail):
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
                    Navigator.pop(context); // Đóng popup detail
                    // Mở lại form sửa, truyền group và task
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