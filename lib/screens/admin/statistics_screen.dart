import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/station_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Khởi tạo mặc định là ngày hôm nay
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    _endDate = _startDate;
  }

  @override
  Widget build(BuildContext context) {
    String dateRangeStr = _startDate == _endDate 
      ? DateFormat('dd/MM/yyyy').format(_startDate)
      : '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Thống kê hoạt động', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text(dateRangeStr, style: const TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.deepPurple,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. TỔNG QUAN (CON SỐ)
            _buildSummaryCards(),

            // 2. BIỂU ĐỒ SO SÁNH
            _buildChartsSection(),

            // 3. LỊCH SỬ CHI TIẾT
            _buildTripHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Tổng số xe',
              stream: _firestore.collection('bikes').snapshots(),
              color: Colors.teal,
              icon: Icons.pedal_bike,
              getValue: (snapshot) => snapshot.docs.length.toString(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              title: 'Chuyến đi',
              stream: _firestore.collection('trips')
                  .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
                  .where('startTime', isLessThan: Timestamp.fromDate(_endDate.add(const Duration(days: 1))))
                  .snapshots(),
              color: Colors.orange,
              icon: Icons.trending_up,
              getValue: (snapshot) => snapshot.docs.length.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required Stream<QuerySnapshot> stream,
    required Color color,
    required IconData icon,
    required String Function(QuerySnapshot) getValue,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = snapshot.hasData ? getValue(snapshot.data!) : "...";
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  final List<Color> _chartColors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.amber,
  ];

  Widget _buildChartsSection() {
    DateTime startRange = DateTime(_startDate.year, _startDate.month, _startDate.day);
    DateTime endRange = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('stations').snapshots(),
      builder: (context, stationSnapshot) {
        if (!stationSnapshot.hasData) return const SizedBox();
        
        final allStations = stationSnapshot.data!.docs
            .map((doc) => Station.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('trips')
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startRange))
              .where('startTime', isLessThan: Timestamp.fromDate(endRange))
              .snapshots(),
          builder: (context, tripSnapshot) {
            if (!tripSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final trips = tripSnapshot.data!.docs;
            
            return Column(
              children: [
                _buildRevenueChart(trips),
                const SizedBox(height: 24),
                _buildTopStations(allStations, trips),
                const SizedBox(height: 24),
                _buildBorrowReturnChart(allStations, trips),
                const SizedBox(height: 24),
                _buildTenMinuteActivityChart(allStations, trips),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopStations(List<Station> allStations, List<QueryDocumentSnapshot> trips) {
    Map<String, int> stationUsage = {};
    for (var doc in trips) {
      final data = doc.data() as Map<String, dynamic>;
      String startId = data['startStationId'] ?? '';
      String endId = data['endStationId'] ?? '';
      if (startId.isNotEmpty) stationUsage[startId] = (stationUsage[startId] ?? 0) + 1;
      if (endId.isNotEmpty) stationUsage[endId] = (stationUsage[endId] ?? 0) + 1;
    }

    List<MapEntry<String, int>> sorted = stationUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = sorted.take(5).toList();

    return _buildChartContainer(
      title: 'Top 5 Trạm phổ biến nhất',
      chart: top5.isEmpty 
        ? const Center(child: Text('Không có dữ liệu trạm', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: top5.length,
            itemBuilder: (context, index) {
              final entry = top5[index];
              final station = allStations.firstWhere((s) => s.id == entry.key, 
                  orElse: () => Station(id: entry.key, name: 'Trạm ẩn danh', latitude: 0, longitude: 0, capacity: 0, currentBikes: 0));
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _chartColors[index % _chartColors.length].withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${index + 1}', style: TextStyle(color: _chartColors[index % _chartColors.length], fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(station.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value / (top5[0].value),
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(_chartColors[index % _chartColors.length]),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${entry.value} lượt', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildRevenueChart(List<QueryDocumentSnapshot> trips) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    Map<int, int> hourlyRevenue = {};
    int totalRevenue = 0;

    for (var doc in trips) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'Completed') {
        Timestamp? ts = data['endTime'] as Timestamp?;
        if (ts != null) {
          int hour = ts.toDate().hour;
          int cost = data['cost'] ?? 0;
          hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) + cost;
          totalRevenue += cost;
        }
      }
    }

    if (totalRevenue == 0) return _buildNoDataChart('Doanh thu');

    bool isMultiDay = _startDate != _endDate;

    if (isMultiDay) {
      // Nhóm theo ngày
      Map<String, int> dailyRevenue = {};
      for (var doc in trips) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'Completed') {
          Timestamp? ts = data['endTime'] as Timestamp?;
          if (ts != null) {
            String day = DateFormat('dd/MM').format(ts.toDate());
            dailyRevenue[day] = (dailyRevenue[day] ?? 0) + (data['cost'] as int? ?? 0);
          }
        }
      }

      List<String> sortedDays = dailyRevenue.keys.toList()..sort((a, b) {
        // Sort dd/MM format (rough sort for display)
        return a.compareTo(b);
      });

      List<BarChartGroupData> groups = List.generate(sortedDays.length, (i) {
        double rev = dailyRevenue[sortedDays[i]]!.toDouble();
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rev,
              color: Colors.green,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            )
          ],
        );
      });

      return _buildChartContainer(
        title: 'Doanh thu theo ngày (Tổng: ${formatter.format(totalRevenue)})',
        chart: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: dailyRevenue.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int idx = value.toInt();
                    if (idx >= 0 && idx < sortedDays.length) {
                      return Text(sortedDays[idx], style: const TextStyle(fontSize: 10));
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: groups,
          ),
        ),
      );
    }

    // Nếu chỉ chọn 1 ngày, show theo giờ như cũ
    List<BarChartGroupData> groups = List.generate(24, (hour) {
      double rev = (hourlyRevenue[hour] ?? 0).toDouble();
      return BarChartGroupData(
        x: hour,
        barRods: [
          BarChartRodData(
            toY: rev,
            gradient: const LinearGradient(
              colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          )
        ],
      );
    });



    return _buildChartContainer(
      title: 'Doanh thu theo giờ (Tổng: ${formatter.format(totalRevenue)})',
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (hourlyRevenue.values.isEmpty ? 50000 : hourlyRevenue.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey.shade900,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  'Khung giờ ${groupIndex}h\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: formatter.format(rod.toY.toInt()),
                      style: const TextStyle(color: Colors.cyanAccent),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 4 == 0) {
                    return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10, color: Colors.grey));
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Text('${(value / 1000).toInt()}k', style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 10000,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
    );
  }

  Widget _buildBorrowReturnChart(List<Station> stations, List<QueryDocumentSnapshot> trips) {
    Map<String, int> borrows = {};
    Map<String, int> returns = {};
    Set<String> activeIds = {};

    for (var doc in trips) {
      final data = doc.data() as Map<String, dynamic>;
      String startId = data['startStationId'] ?? "";
      String endId = data['endStationId'] ?? "";
      String startLoc = data['startLocation'] ?? "";
      String endLoc = data['endLocation'] ?? "";

      // Fallback if ID missing
      if (startId.isEmpty && startLoc.isNotEmpty) {
        try { startId = stations.firstWhere((s) => s.name == startLoc).id; } catch (_) {}
      }
      if (endId.isEmpty && endLoc.isNotEmpty) {
        try { endId = stations.firstWhere((s) => s.name == endLoc).id; } catch (_) {}
      }

      if (startId.isNotEmpty) {
        borrows[startId] = (borrows[startId] ?? 0) + 1;
        activeIds.add(startId);
      }
      if (endId.isNotEmpty && data['status'] == 'Completed') {
        returns[endId] = (returns[endId] ?? 0) + 1;
        activeIds.add(endId);
      }
    }

    final displayStations = stations.where((s) => activeIds.contains(s.id)).toList();
    if (displayStations.isEmpty) return _buildNoDataChart('So sánh Mượn & Trả theo Trạm');

    int maxVal = 0;
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < displayStations.length; i++) {
      int bCount = borrows[displayStations[i].id] ?? 0;
      int rCount = returns[displayStations[i].id] ?? 0;
      if (bCount > maxVal) maxVal = bCount;
      if (rCount > maxVal) maxVal = rCount;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: bCount.toDouble(), 
            gradient: const LinearGradient(colors: [Colors.lightBlueAccent, Colors.blue]),
            width: 12, 
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (maxVal == 0 ? 5 : maxVal.toDouble() + 1),
              color: Colors.grey.withOpacity(0.1),
            )
          ),
          BarChartRodData(
            toY: rCount.toDouble(), 
            gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
            width: 12, 
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (maxVal == 0 ? 5 : maxVal.toDouble() + 1),
              color: Colors.grey.withOpacity(0.1),
            )
          ),
        ],
        barsSpace: 4,
      ));
    }

    return _buildChartContainer(
      title: 'So sánh Mượn & Trả theo Trạm',
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal == 0 ? 5 : maxVal.toDouble() + 1),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey.shade900,
              tooltipPadding: const EdgeInsets.all(12),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${displayStations[groupIndex].name}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  children: [
                    TextSpan(
                      text: rodIndex == 0 ? 'Mượn: ${rod.toY.toInt()} xe' : 'Trả: ${rod.toY.toInt()} xe',
                      style: TextStyle(
                        color: rodIndex == 0 ? Colors.lightBlueAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= displayStations.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${value.toInt() + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == meta.max) return const SizedBox();
                  return Text(value.toInt().toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 10));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
      legend: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Mượn', Colors.blue),
              const SizedBox(width: 20),
              _buildLegendItem('Trả', Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(displayStations.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  const SizedBox(width: 4),
                  Text(displayStations[i].name, style: TextStyle(fontSize: 11, color: Colors.grey[800])),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTenMinuteActivityChart(List<Station> stations, List<QueryDocumentSnapshot> trips) {
    // key: slotIndex (0-143), value: {stationId: count}
    Map<int, Map<String, int>> slotData = {};
    
    for (var doc in trips) {
      final data = doc.data() as Map<String, dynamic>;
      Timestamp? ts = data['startTime'] as Timestamp?;
      if (ts != null) {
        DateTime dt = ts.toDate();
        int slot = (dt.hour * 6) + (dt.minute ~/ 10);
        String stationId = data['startStationId'] ?? "";
        
        // Fallback for missing ID
        if (stationId.isEmpty) {
          String startLoc = data['startLocation'] ?? "";
          try { stationId = stations.firstWhere((s) => s.name == startLoc).id; } catch (_) {}
        }

        if (stationId.isNotEmpty) {
          slotData.putIfAbsent(slot, () => {});
          slotData[slot]![stationId] = (slotData[slot]![stationId] ?? 0) + 1;
        }
      }
    }

    int maxVal = 0;
    List<BarChartGroupData> groups = List.generate(144, (slot) {
      int totalInSlot = 0;
      slotData[slot]?.values.forEach((v) => totalInSlot += v);
      if (totalInSlot > maxVal) maxVal = totalInSlot;

      return BarChartGroupData(
        x: slot,
        barRods: [
          BarChartRodData(
            toY: totalInSlot.toDouble(),
            gradient: const LinearGradient(
              colors: [Colors.purpleAccent, Colors.deepPurple],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          )
        ],
      );
    });

    return _buildChartContainer(
      title: 'Lượt mượn Real-time (10 phút/cột)',
      chart: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 144 * 14.0, 
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxVal == 0 ? 5 : maxVal.toDouble() + 1),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent && response != null && response.spot != null) {
                    int slotIndex = response.spot!.touchedBarGroupIndex;
                    if (slotData.containsKey(slotIndex)) {
                      _showSlotDetails(context, slotIndex, slotData[slotIndex]!, stations);
                    }
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.deepPurple.shade900,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    int hour = groupIndex ~/ 6;
                    int min = (groupIndex % 6) * 10;
                    return BarTooltipItem(
                      '${hour.toString().padLeft(2,'0')}:${min.toString().padLeft(2,'0')}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} lượt mượn',
                          style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      int val = value.toInt();
                      if (val % 6 == 0) { // Hiện nhãn mỗi giờ
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('${val ~/ 6}h', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1, dashArray: [3, 3]),
              ),
              borderData: FlBorderData(show: false),
              barGroups: groups,
            ),
          ),
        ),
      ),
    );
  }

  void _showSlotDetails(BuildContext context, int slotIndex, Map<String, int> stationCounts, List<Station> allStations) {
    int hour = slotIndex ~/ 6;
    int min = (slotIndex % 6) * 10;
    String timeRange = '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} - ${hour.toString().padLeft(2, '0')}:${(min + 10).toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chi tiết khung giờ $timeRange', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: stationCounts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  String sId = stationCounts.keys.elementAt(index);
                  int count = stationCounts[sId]!;
                  Station? station;
                  try { station = allStations.firstWhere((s) => s.id == sId); } catch (_) {}
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.ev_station, color: Colors.deepPurple, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(station?.name ?? 'Trạm không xác định', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Đã mượn: $count xe', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('bikes').where('stationId', isEqualTo: sId).where('status', isEqualTo: 'available').snapshots(),
                          builder: (context, snapshot) {
                            int available = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$available', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                                const Text('Xe còn lại', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer({required String title, required Widget chart, Widget? legend}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: chart),
          if (legend != null) ...[const SizedBox(height: 12), legend],
        ],
      ),
    );
  }

  Widget _buildNoDataChart(String title) {
    return _buildChartContainer(
      title: title,
      chart: const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildLegend(List<Station> activeStations, List<Station> allStations) {
    if (activeStations.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 15,
      runSpacing: 10,
      children: List.generate(activeStations.length, (i) {
        int originalIndex = allStations.indexOf(activeStations[i]);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _chartColors[originalIndex % _chartColors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(activeStations[i].name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
      }),
    );
  }

  Widget _buildTripHistoryList() {
    DateTime startRange = DateTime(_startDate.year, _startDate.month, _startDate.day);
    DateTime endRange = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('Lịch sử chuyến đi trong kỳ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('trips')
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startRange))
              .where('startTime', isLessThan: Timestamp.fromDate(endRange))
              .orderBy('startTime', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Không có dữ liệu cho ngày này', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            // Sắp xếp theo thời gian giảm dần
            var sortedDocs = snapshot.data!.docs.toList();
            sortedDocs.sort((a, b) {
              Timestamp tsA = a['startTime'] ?? Timestamp.now();
              Timestamp tsB = b['startTime'] ?? Timestamp.now();
              return tsB.compareTo(tsA);
            });

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDocs.length,
              itemBuilder: (context, index) {
                var trip = sortedDocs[index].data() as Map<String, dynamic>;
                return _buildTripListItem(trip);
              },
            );
          },
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  void _showStationDetails(BuildContext context, Station station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.ev_station, color: Colors.deepPurple, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(station.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(station.address, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: station.status == 'active' ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      station.status == 'active' ? 'Hoạt động' : 'Bảo trì',
                      style: TextStyle(
                        color: station.status == 'active' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('bikes')
                    .where('stationId', isEqualTo: station.id)
                    .snapshots(),
                builder: (context, bikeSnapshot) {
                  int available = 0;
                  int inUse = 0;
                  if (bikeSnapshot.hasData) {
                    for (var doc in bikeSnapshot.data!.docs) {
                      String status = doc['status'] ?? '';
                      if (status == 'available') available++;
                      else if (status == 'in_use') inUse++;
                    }
                  }
                  final emptySlots = station.capacity - available;
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoItem(
                        icon: Icons.pedal_bike,
                        value: '$available',
                        label: 'Xe có sẵn',
                        color: const Color(0xFF4CAF50),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildInfoItem(
                        icon: Icons.directions_bike,
                        value: '$inUse',
                        label: 'Đang mượn',
                        color: const Color(0xFFE91E63),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildInfoItem(
                        icon: Icons.local_parking,
                        value: '${emptySlots < 0 ? 0 : emptySlots}',
                        label: 'Chỗ trống',
                        color: const Color(0xFF2196F3),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildInfoItem(
                        icon: Icons.ev_station,
                        value: '${station.capacity}',
                        label: 'Sức chứa',
                        color: const Color(0xFFFF9800),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Đóng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTripListItem(Map<String, dynamic> trip) {
    String bikeId = trip['bikeId'] ?? "---";
    String userId = trip['userId'] ?? "";
    int cost = trip['cost'] ?? 0;
    String startLoc = trip['startLocation'] ?? "Không xác định";
    String endLoc = trip['endLocation'] ?? "Đang di chuyển...";
    int duration = trip['duration'] ?? 0;
    double distance = (trip['distance'] ?? 0).toDouble();
    String status = trip['status'] ?? 'Unknown';
    Timestamp? startTime = trip['startTime'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header: Xe + Thời gian + Giá
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.directions_bike, color: Colors.deepPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Xe: $bikeId', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTripTime(trip), 
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status == 'Ongoing' ? 'Đang đi' : '${NumberFormat('#,###').format(cost)}đ', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: status == 'Ongoing' ? Colors.blue : Colors.green
                    )
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'Completed' ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status == 'Completed' ? '✓ Hoàn thành' : '● Đang đi',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: status == 'Completed' ? Colors.green : Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          // Khách hàng
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Khách hàng: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
              _buildUserName(userId),
            ],
          ),
          const SizedBox(height: 8),
          // Lộ trình: Điểm đầu → Điểm cuối
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(startLoc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(width: 2, height: 14, color: Colors.grey[300]),
                    ),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(status == 'Ongoing' ? 'Đang di chuyển...' : endLoc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Thông số: Thời gian + Quãng đường
          Row(
            children: [
              _buildMiniStat(Icons.timer_outlined, '$duration phút', Colors.orange),
              const SizedBox(width: 16),
              _buildMiniStat(Icons.route, '${distance.toStringAsFixed(2)} km', Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  String _formatTripTime(Map<String, dynamic> trip) {
    Timestamp? startTimeTs = trip['startTime'] as Timestamp?;
    Timestamp? endTimeTs = trip['endTime'] as Timestamp?;
    String status = trip['status'] ?? "";

    if (startTimeTs == null) return "---";

    String startStr = DateFormat('HH:mm').format(startTimeTs.toDate());
    
    if (status == 'Ongoing') {
      return "$startStr - Đang đi";
    }

    if (endTimeTs != null) {
      return "$startStr - ${DateFormat('HH:mm').format(endTimeTs.toDate())}";
    } else {
      // Fallback cho dữ liệu cũ
      int duration = trip['duration'] ?? 0;
      DateTime end = startTimeTs.toDate();
      DateTime start = end.subtract(Duration(minutes: duration));
      return "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}";
    }
  }

  Widget _buildUserName(String userId) {
    if (userId.isEmpty) return const Text("Ẩn danh", style: TextStyle(fontSize: 13));
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          return Text(snapshot.data!['name'] ?? "Không tên", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
        }
        return const Text("...", style: TextStyle(fontSize: 13));
      },
    );
  }
}
