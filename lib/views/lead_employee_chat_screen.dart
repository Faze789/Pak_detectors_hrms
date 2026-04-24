import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeadEmployeeChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String leadEmpId;
  final String leadName;
  final String employeeEmpId;
  final String employeeName;
  final String currentUserEmpId;

  const LeadEmployeeChatScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.leadEmpId,
    required this.leadName,
    required this.employeeEmpId,
    required this.employeeName,
    required this.currentUserEmpId,
  });

  @override
  State<LeadEmployeeChatScreen> createState() => _LeadEmployeeChatScreenState();
}

class _LeadEmployeeChatScreenState extends State<LeadEmployeeChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  String? _chatRoomId;
  bool _loading = true;

  bool get _isLead =>
      widget.currentUserEmpId.toLowerCase() == widget.leadEmpId.toLowerCase();

  String get _otherName => _isLead ? widget.employeeName : widget.leadName;

  @override
  void initState() {
    super.initState();
    _findOrCreateChatRoom();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _findOrCreateChatRoom() async {
    final collection = FirebaseFirestore.instance.collection(
      'lead_employee_feedback',
    );

    final query = await collection
        .where('leadEmpId', isEqualTo: widget.leadEmpId)
        .where('employeeEmpId', isEqualTo: widget.employeeEmpId)
        .where('taskId', isEqualTo: widget.taskId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      _chatRoomId = query.docs.first.id;
    } else {
      final doc = await collection.add({
        'leadEmpId': widget.leadEmpId,
        'leadName': widget.leadName,
        'employeeEmpId': widget.employeeEmpId,
        'employeeName': widget.employeeName,
        'taskId': widget.taskId,
        'taskTitle': widget.taskTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      _chatRoomId = doc.id;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _chatRoomId == null) return;

    _msgController.clear();

    final senderName = _isLead ? widget.leadName : widget.employeeName;
    final senderRole = _isLead ? 'lead' : 'employee';

    final chatRef = FirebaseFirestore.instance
        .collection('lead_employee_feedback')
        .doc(_chatRoomId);

    await chatRef.collection('messages').add({
      'senderId': widget.currentUserEmpId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _otherName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.taskTitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFFBFDBFE)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : Column(
              children: [
                // Messages
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('lead_employee_feedback')
                        .doc(_chatRoomId)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
                        );
                      }

                      final messages = snapshot.data?.docs ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Start a conversation with $_otherName',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg =
                              messages[index].data() as Map<String, dynamic>;
                          final isMine =
                              (msg['senderId'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              widget.currentUserEmpId.toLowerCase();
                          return _buildMessageBubble(msg, isMine);
                        },
                      );
                    },
                  ),
                ),

                // Input bar
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 8,
                    top: 10,
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMine) {
    final timestamp = msg['timestamp'] as Timestamp?;
    String timeStr = '';
    if (timestamp != null) {
      final dt = timestamp.toDate();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      timeStr = '$hour:$minute $amPm';
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg['senderName'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            Text(
              msg['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : const Color(0xFF1E293B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
