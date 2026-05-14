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
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Thống kê hoạt động', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
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
              title: 'Chuyến đi hôm nay',
              stream: _firestore.collection('trips')
                  .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)))
                  .where('startTime', isLessThan: Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).add(const Duration(days: 1))))
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
    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('stations').snapshots(),
      builder: (context, stationSnapshot) {
        if (!stationSnapshot.hasData) return const SizedBox();
        
        final allStations = stationSnapshot.data!.docs
            .map((doc) => Station.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('trips')
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
              .snapshots(),
          builder: (context, tripSnapshot) {
            if (!tripSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final trips = tripSnapshot.data!.docs;
            
            return Column(
              children: [
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
          BarChartRodData(toY: bCount.toDouble(), color: Colors.blue, width: 8, borderRadius: BorderRadius.circular(4)),
          BarChartRodData(toY: rCount.toDouble(), color: Colors.orange, width: 8, borderRadius: BorderRadius.circular(4)),
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
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${displayStations[groupIndex].name}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: rodIndex == 0 ? 'Mượn: ${rod.toY.toInt()}' : 'Trả: ${rod.toY.toInt()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
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
                    child: Text('${value.toInt() + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  );
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
            color: Colors.deepPurple,
            width: 4,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          )
        ],
      );
    });

    return _buildChartContainer(
      title: 'Lượt mượn Real-time (10 phút/cột)',
      chart: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 144 * 12.0, 
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
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    int hour = groupIndex ~/ 6;
                    int min = (groupIndex % 6) * 10;
                    return BarTooltipItem(
                      '${hour.toString().padLeft(2,'0')}:${min.toString().padLeft(2,'0')}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toInt()} xe',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
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
                          child: Text('${val ~/ 6}h', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
              gridData: const FlGridData(show: false),
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
    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 30, 20, 15),
          child: Text('Chi tiết lịch sử di chuyển', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('trips')
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
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
    String endLoc = trip['endLocation'] ?? "Đang di chuyển...";
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
              Text(
                trip['status'] == 'Ongoing' ? 'Đang đi' : '${NumberFormat('#,###').format(cost)}đ', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: trip['status'] == 'Ongoing' ? Colors.blue : Colors.green
                )
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Khách hàng: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
              _buildUserName(userId),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Lộ trình: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Expanded(
                child: Text(
                  '${trip['startLocation'] ?? '...'} → ${trip['endLocation'] ?? 'Đang đi'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
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
