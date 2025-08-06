import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, Map<String, int>> dailyStats = {};
  Map<String, Map<String, int>> monthlyStats = {};
  Map<String, Map<String, int>> yearlyStats = {};
  bool isLoading = true;

  DateTime selectedDate = DateTime.now();
  String selectedFilter = 'all';
  int? selectedYear;
  int? selectedMonth;
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    _loadActivityHistory();
  }

  Future<void> _loadActivityHistory() async {
    if (user == null) return;

    try {
      // Chỉ lấy nhiệm vụ cá nhân của user
      final tasksQuery = await FirebaseFirestore.instance
          .collection('tasks')
          .where('uid', isEqualTo: user!.uid)
          .get();

      final tasks = tasksQuery.docs;

      // Thống kê theo ngày/tháng/năm - Chỉ nhiệm vụ cá nhân
      for (var task in tasks) {
        _processTask(task);
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading activity history: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _processTask(QueryDocumentSnapshot task) {
    final taskData = task.data() as Map<String, dynamic>;
    final createdAtTimestamp = taskData['createdAt'] as Timestamp?;
    
    // Bỏ qua task không có createdAt
    if (createdAtTimestamp == null) return;
    
    final createdAt = createdAtTimestamp.toDate();
    
    // Kiểm tra bộ lọc thời gian
    if (!_isTaskInSelectedTimeRange(createdAt)) return;
    
    final dayKey = DateFormat('yyyy-MM-dd').format(createdAt);
    final monthKey = DateFormat('yyyy-MM').format(createdAt);
    final yearKey = createdAt.year.toString();

    // Khởi tạo nếu chưa có
    if (!dailyStats.containsKey(dayKey)) {
      dailyStats[dayKey] = {'total': 0, 'completed': 0};
    }
    if (!monthlyStats.containsKey(monthKey)) {
      monthlyStats[monthKey] = {'total': 0, 'completed': 0};
    }
    if (!yearlyStats.containsKey(yearKey)) {
      yearlyStats[yearKey] = {'total': 0, 'completed': 0};
    }

    // Tăng số lượng nhiệm vụ
    dailyStats[dayKey]!['total'] = dailyStats[dayKey]!['total']! + 1;
    monthlyStats[monthKey]!['total'] = monthlyStats[monthKey]!['total']! + 1;
    yearlyStats[yearKey]!['total'] = yearlyStats[yearKey]!['total']! + 1;

    // Kiểm tra nhiệm vụ đã hoàn thành
    if (taskData['completed'] == true) {
      dailyStats[dayKey]!['completed'] = dailyStats[dayKey]!['completed']! + 1;
      monthlyStats[monthKey]!['completed'] = monthlyStats[monthKey]!['completed']! + 1;
      yearlyStats[yearKey]!['completed'] = yearlyStats[yearKey]!['completed']! + 1;
    }
  }

  bool _isTaskInSelectedTimeRange(DateTime taskDate) {
    switch (selectedFilter) {
      case 'year':
        return selectedYear != null && taskDate.year == selectedYear;
      case 'month':
        return selectedYear != null && selectedMonth != null && 
               taskDate.year == selectedYear && taskDate.month == selectedMonth;
      case 'day':
        return selectedDay != null && 
               taskDate.year == selectedDay!.year && 
               taskDate.month == selectedDay!.month && 
               taskDate.day == selectedDay!.day;
      default:
        return true; // Hiển thị tất cả
    }
  }

  void _resetFilter() {
    setState(() {
      selectedFilter = 'all';
      selectedYear = null;
      selectedMonth = null;
      selectedDay = null;
      dailyStats.clear();
      monthlyStats.clear();
      yearlyStats.clear();
    });
    _loadActivityHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'TIẾN ĐỘ CÁ NHÂN',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.deepPurple),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivityHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterInfo(),
                    const SizedBox(height: 16),
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    _buildDailyStats(),
                    const SizedBox(height: 24),
                    _buildYearlyStats(),
                    const SizedBox(height: 24),
                    _buildMonthlyStats(),
                    const SizedBox(height: 50), // Thêm padding cuối để tránh bị che
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterInfo() {
    if (selectedFilter == 'all') return const SizedBox.shrink();
    
    String filterText = '';
    switch (selectedFilter) {
      case 'year':
        filterText = 'Năm $selectedYear';
        break;
      case 'month':
        final monthNames = [
          'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
          'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
        ];
        filterText = '${monthNames[selectedMonth! - 1]} $selectedYear';
        break;
      case 'day':
        filterText = DateFormat('dd/MM/yyyy').format(selectedDay!);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang lọc: $filterText',
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _resetFilter,
            child: Text(
              'Xóa bộ lọc',
              style: TextStyle(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc thời gian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Tất cả'),
              onTap: () {
                Navigator.pop(context);
                _resetFilter();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Chọn năm'),
              onTap: () {
                Navigator.pop(context);
                _selectYear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Chọn tháng'),
              onTap: () {
                Navigator.pop(context);
                _selectMonth();
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Chọn ngày'),
              onTap: () {
                Navigator.pop(context);
                _selectDay();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectYear() async {
    final now = DateTime.now();
    final year = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn năm'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              final year = now.year - index;
              return ListTile(
                title: Text(year.toString()),
                onTap: () => Navigator.pop(context, year),
              );
            },
          ),
        ),
      ),
    );

    if (year != null) {
      setState(() {
        selectedFilter = 'year';
        selectedYear = year;
        selectedMonth = null;
        selectedDay = null;
        dailyStats.clear();
        monthlyStats.clear();
        yearlyStats.clear();
      });
      _loadActivityHistory();
    }
  }

  void _selectMonth() async {
    final now = DateTime.now();
    final year = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn năm'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              final year = now.year - index;
              return ListTile(
                title: Text(year.toString()),
                onTap: () => Navigator.pop(context, year),
              );
            },
          ),
        ),
      ),
    );

    if (year != null) {
      final month = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn tháng'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthNames = [
                  'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
                  'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
                ];
                return InkWell(
                  onTap: () => Navigator.pop(context, index + 1),
                  child: Card(
                    child: Center(
                      child: Text(
                        monthNames[index],
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      if (month != null) {
        setState(() {
          selectedFilter = 'month';
          selectedYear = year;
          selectedMonth = month;
          selectedDay = null;
          dailyStats.clear();
          monthlyStats.clear();
          yearlyStats.clear();
        });
        _loadActivityHistory();
      }
    }
  }

  void _selectDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        selectedFilter = 'day';
        selectedDay = selected;
        selectedYear = null;
        selectedMonth = null;
        dailyStats.clear();
        monthlyStats.clear();
        yearlyStats.clear();
      });
      _loadActivityHistory();
    }
  }

  Widget _buildSummaryCard() {
    int totalTasks = 0;
    int totalCompleted = 0;

    yearlyStats.forEach((year, stats) {
      totalTasks += stats['total']!;
      totalCompleted += stats['completed']!;
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng quan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Tổng nhiệm vụ',
                    totalTasks.toString(),
                    Icons.task,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Đã hoàn thành',
                    totalCompleted.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Tỷ lệ hoàn thành',
                    totalTasks > 0 ? '${((totalCompleted / totalTasks) * 100).toStringAsFixed(1)}%' : '0%',
                    Icons.analytics,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Chưa hoàn thành',
                    (totalTasks - totalCompleted).toString(),
                    Icons.pending,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyStats() {
    final sortedDays = dailyStats.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedDays.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thống kê theo ngày',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedDays.map((day) => _buildDayCard(day, dailyStats[day]!)),
      ],
    );
  }

  Widget _buildDayCard(String dayKey, Map<String, int> stats) {
    final date = DateTime.parse(dayKey);
    final dayName = DateFormat('EEEE', 'vi_VN').format(date);
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final completionRate = stats['total']! > 0 
        ? (stats['completed']! / stats['total']! * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                '${stats['completed']}/${stats['total']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$completionRate%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyStats() {
    final sortedYears = yearlyStats.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedYears.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thống kê theo năm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedYears.map((year) => _buildYearCard(year, yearlyStats[year]!)),
      ],
    );
  }

  Widget _buildYearCard(String year, Map<String, int> stats) {
    final completionRate = stats['total']! > 0 
        ? (stats['completed']! / stats['total']! * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Năm $year',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completionRate%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat('Tổng', stats['total']!.toString(), Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStat('Hoàn thành', stats['completed']!.toString(), Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStat('Chưa hoàn thành', (stats['total']! - stats['completed']!).toString(), Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final sortedMonths = monthlyStats.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedMonths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thống kê theo tháng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedMonths.map((month) => _buildMonthCard(month, monthlyStats[month]!)),
      ],
    );
  }

  Widget _buildMonthCard(String monthKey, Map<String, int> stats) {
    final date = DateTime.parse('$monthKey-01');
    final monthNames = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    final monthName = monthNames[date.month - 1];
    final year = date.year;
    final completionRate = stats['total']! > 0 
        ? (stats['completed']! / stats['total']! * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$monthName $year',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats['total']} nhiệm vụ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                '${stats['completed']}/${stats['total']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$completionRate%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
} 