import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Màn hình Admin xem và trả lời câu hỏi hỗ trợ từ users
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ người dùng'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Chờ trả lời', icon: Icon(Icons.pending_actions, size: 20)),
            Tab(text: 'Đã trả lời', icon: Icon(Icons.check_circle_outline, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTicketList('pending'),
          _buildTicketList('answered'),
        ],
      ),
    );
  }

  Widget _buildTicketList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs.toList();

        // Sắp xếp theo thời gian mới nhất
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (bData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == 'pending' ? Icons.inbox_outlined : Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  status == 'pending'
                      ? 'Không có câu hỏi nào đang chờ'
                      : 'Chưa có câu hỏi nào đã trả lời',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _buildTicketCard(data, docId, status);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data, String docId, String status) {
    final isPending = status == 'pending';
    final createdAt = data['createdAt'] != null
        ? DateFormat('HH:mm dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate())
        : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: user info + time
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isPending ? Colors.orange[100] : Colors.green[100],
                  child: Icon(
                    Icons.person,
                    color: isPending ? Colors.orange[800] : Colors.green[800],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['userName'] ?? 'Người dùng',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        createdAt,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPending ? Colors.orange : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isPending ? 'Chờ trả lời' : 'Đã trả lời',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPending ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Câu hỏi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('❓ Câu hỏi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text(data['question'] ?? '', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Bot response
            if (data['botResponse'] != null && (data['botResponse'] as String).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖 Bot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(data['botResponse'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ),
              ),

            // Admin response (nếu đã trả lời)
            if (!isPending && data['adminResponse'] != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅ Phản hồi Admin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                    const SizedBox(height: 4),
                    Text(data['adminResponse'] ?? '', style: const TextStyle(fontSize: 14)),
                    if (data['answeredAt'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Trả lời lúc: ${DateFormat('HH:mm dd/MM/yyyy').format((data['answeredAt'] as Timestamp).toDate())}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Nút trả lời (chỉ hiện ở tab pending)
            if (isPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAnswerDialog(docId, data),
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Trả lời'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAnswerDialog(String docId, Map<String, dynamic> data) {
    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.reply_all, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Trả lời câu hỏi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '❓ ${data['question']}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Nhập câu trả lời',
                hintText: 'Phản hồi cho người dùng...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.indigo, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (answerController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập câu trả lời')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('support_tickets')
                    .doc(docId)
                    .update({
                  'adminResponse': answerController.text.trim(),
                  'status': 'answered',
                  'answeredAt': FieldValue.serverTimestamp(),
                });

                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã gửi phản hồi thành công!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Gửi phản hồi'),
          ),
        ],
      ),
    );
  }
}
