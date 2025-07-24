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
import 'group_screen.dart';
import 'profile_screen.dart';
import 'setting_screen.dart';

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

  bool _titleError = false;


  bool _weekStartsFromSunday = false;

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

  void _initCurrentWeek() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    String weekStart = prefs.getString('weekStart') ?? 'Thứ hai';
    final weekDayMap = {
      'Chủ nhật': DateTime.sunday,
      'Thứ hai': DateTime.monday,
      'Thứ ba': DateTime.tuesday,
      'Thứ tư': DateTime.wednesday,
      'Thứ năm': DateTime.thursday,
      'Thứ sáu': DateTime.friday,
      'Thứ bảy': DateTime.saturday,
    };
    int startWeekday = weekDayMap[weekStart] ?? DateTime.monday;
    // Tìm ngày bắt đầu tuần gần nhất
    int diff = (now.weekday - startWeekday) % 7;
    if (diff < 0) diff += 7;
    _startOfWeek = now.subtract(Duration(days: diff));
    _endOfWeek = _startOfWeek.add(const Duration(days: 6));
    _selectedDayIndex = now.difference(_startOfWeek).inDays;
    _updateDaysOfWeek();
  }

  void _updateDaysOfWeek() async {
    // Lấy ngày bắt đầu tuần từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String weekStart = prefs.getString('weekStart') ?? 'Thứ hai';
    final weekDayMap = {
      'Chủ nhật': DateTime.sunday,
      'Thứ hai': DateTime.monday,
      'Thứ ba': DateTime.tuesday,
      'Thứ tư': DateTime.wednesday,
      'Thứ năm': DateTime.thursday,
      'Thứ sáu': DateTime.friday,
      'Thứ bảy': DateTime.saturday,
    };
    int startWeekday = weekDayMap[weekStart] ?? DateTime.monday;
    // Tạo danh sách 7 ngày bắt đầu từ startOfWeek
    _daysOfWeek = List.generate(7, (i) {
      final d = _startOfWeek.add(Duration(days: i));
      return {
        'label': _weekdayLabelVN(d.weekday),
        'date': d.day,
        'dateTime': d,
      };
    });
    // Sắp xếp lại thứ tự label cho đúng thứ bắt đầu tuần
    // (label chỉ để hiển thị, còn dateTime đã đúng)
    setState(() {});
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo ở góc trái
                Image.asset(
                  'assets/logo.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                // Spacer để đẩy dropdown sang phải
                Spacer(),
                // Dropdown tháng và năm bên phải
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
                const SizedBox(width: 12),
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
                          defaultBuilder: (context, day, focusedDay) {
                            const specialDays = [
                              '1/1', '3/2', '14/2', '8/3', '26/3', '30/4', '1/5', '19/5', '1/6', '27/7', '19/8', '2/9', '20/10', '20/11', '24/12',
                            ];
                            final key = '${day.day}/${day.month}';
                            if (specialDays.contains(key)) {
                              return Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 50),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
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
    // Danh sách ngày đặc biệt (dd/MM) với icon và nội dung riêng
    const specialDayInfo = {
      '1/1':  {'icon': Icons.celebration, 'color': Colors.red,    'text': 'Chúc mừng năm mới!'},
      '3/2':  {'icon': Icons.flag,        'color': Colors.red,    'text': 'Kỷ niệm ngày thành lập Đảng Cộng Sản Việt Nam!'},
      '14/2': {'icon': Icons.favorite,    'color': Colors.pink,   'text': 'Chúc mừng ngày Valentine!'},
      '8/3':  {'icon': Icons.woman,       'color': Colors.purple, 'text': 'Chúc mừng ngày Quốc tế Phụ nữ!'},
      '26/3': {'icon': Icons.groups,      'color': Colors.blue,   'text': 'Kỷ niệm ngày thành lập Đoàn TNCS Hồ Chí Minh!'},
      '30/4': {'icon': Icons.flag,        'color': Colors.orange, 'text': 'Chào mừng ngày Giải phóng Miền Nam!'},
      '1/5':  {'icon': Icons.handyman,    'color': Colors.green,  'text': 'Chúc mừng ngày Quốc tế Lao động!'},
      '19/5': {'icon': Icons.cake,        'color': Colors.brown,  'text': 'Kỷ niệm ngày sinh Chủ tịch Hồ Chí Minh!'},
      '1/6':  {'icon': Icons.child_care,  'color': Colors.cyan,   'text': 'Chúc mừng ngày Quốc tế Thiếu nhi!'},
      '27/7': {'icon': Icons.military_tech,'color': Colors.amber, 'text': 'Tri ân ngày Thương binh Liệt sĩ!'},
      '19/8': {'icon': Icons.flag,        'color': Colors.deepOrange, 'text': 'Kỷ niệm Cách mạng Tháng Tám thành công!'},
      '2/9':  {'icon': Icons.flag,        'color': Colors.red,    'text': 'Chúc mừng ngày Quốc Khánh!'},
      '20/10':{'icon': Icons.woman,       'color': Colors.pink,   'text': 'Chúc mừng ngày Phụ nữ Việt Nam!'},
      '20/11':{'icon': Icons.school,      'color': Colors.deepPurple, 'text': 'Chúc mừng ngày Nhà giáo Việt Nam!'},
      '24/12':{'icon': Icons.church,      'color': Colors.green,  'text': 'Chúc mừng Giáng sinh!'},
    };
    final key = '${selectedDate.day}/${selectedDate.month}';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('tasks')
        .where('date', isEqualTo: dateKey)
        .where('uid', isEqualTo: user?.uid)
        .orderBy('time')
        .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: {snapshot.error}'));
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
            if (specialDayInfo.containsKey(key))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      specialDayInfo[key]!['icon'] as IconData,
                      color: specialDayInfo[key]!['color'] as Color,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        specialDayInfo[key]!['text'] as String,
                        style: calendarFont.copyWith(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
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