import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/user_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final UserService _userService = UserService();
  bool _isChecking = false;
  Map<String, dynamic>? _result;

  Future<void> _checkConsistency() async {
    setState(() => _isChecking = true);

    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Người dùng chưa đăng nhập")),
      );
      setState(() => _isChecking = false);
      return;
    }

    final result = await _userService.verifyUserConsistency(uid);
    setState(() {
      _result = result;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔧 Debug - Kiểm Tra Dữ Liệu"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.verified),
                label: const Text("🔍 Kiểm Tra Consistency"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                onPressed: _isChecking ? null : _checkConsistency,
              ),
            ),
            const SizedBox(height: 30),
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result!['isConsistent']
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _result!['isConsistent']
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result!['isConsistent']
                          ? "✅ DỮ LIỆU ĐỒNG BỘ"
                          : "❌ DỮ LIỆU KHÔNG ĐỒNG BỘ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _result!['isConsistent']
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCheckItem("Auth Account",
                        _result!['authExists'] ?? false),
                    _buildCheckItem("Firestore Record",
                        _result!['firestoreExists'] ?? false),
                    if (_result!['user'] != null) ...[
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text(
                        "📊 Thông tin user:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _buildUserInfo(_result!['user']),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      "💬 ${_result!['message']}",
                      style: TextStyle(
                        color: _result!['isConsistent']
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            passed ? "✓ OK" : "✗ FAILED",
            style: TextStyle(
              color: passed ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem("User Code", user.userCode),
        _buildInfoItem("Full Name", user.fullName),
        _buildInfoItem("Phone", user.phoneNumber),
        _buildInfoItem("Email", user.email),
        _buildInfoItem("Balance", "${user.balance}đ"),
        _buildInfoItem("Points", "${user.points}"),
        _buildInfoItem("Status", user.status),
        _buildInfoItem(
            "Created", user.createdAt.toString().split('.')[0]),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ",
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}