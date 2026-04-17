import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/meeting_model.dart';
import '../services/meeting_service.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum ViewState { idle, loading, success, error }

// ─── HR Meeting ViewModel ─────────────────────────────────────────────────────

class HRMeetingViewModel extends ChangeNotifier {
  final MeetingService _service;
  final String hrUserId;
  final String hrUserName;

  HRMeetingViewModel({
    required this.hrUserId,
    required this.hrUserName,
    MeetingService? service,
  }) : _service = service ?? MeetingService() {
    _init();
  }

  // ─── State ────────────────────────────────────────────────────────────────

  ViewState _state = ViewState.idle;
  ViewState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<MeetingModel> _allMeetings = [];
  List<MeetingModel> get allMeetings => _filteredMeetings;

  List<MeetingModel> _pendingMeetings = [];
  List<MeetingModel> get pendingMeetings => _pendingMeetings;

  List<UserModel> _employees = [];
  List<UserModel> get employees => _employees;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // ─── Filters ──────────────────────────────────────────────────────────────

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _filterStatus = 'All';
  String get filterStatus => _filterStatus;

  String _filterType = 'All';
  String get filterType => _filterType;

  // ─── Subscriptions ────────────────────────────────────────────────────────

  StreamSubscription<List<MeetingModel>>? _allSub;
  StreamSubscription<List<MeetingModel>>? _pendingSub;
  StreamSubscription<int>? _unreadSub;

  // ─── Init ─────────────────────────────────────────────────────────────────

  void _init() {
    _listenAllMeetings();
    _listenPendingMeetings();
    _listenUnreadCount();
    _loadEmployees();
  }

  void _listenAllMeetings() {
    _allSub = _service.streamAllMeetings().listen(
          (meetings) {
        _allMeetings = meetings;
        notifyListeners();
      },
      onError: (e) => _setError('Failed to load meetings: $e'),
    );
  }

  void _listenPendingMeetings() {
    _pendingSub = _service.streamPendingMeetings().listen(
          (meetings) {
        _pendingMeetings = meetings;
        notifyListeners();
      },
      onError: (e) => _setError('Failed to load pending meetings: $e'),
    );
  }

  void _listenUnreadCount() {
    _unreadSub = _service.streamUnreadCount(hrUserId).listen(
          (count) {
        _unreadCount = count;
        notifyListeners();
      },
    );
  }

  Future<void> _loadEmployees() async {
    try {
      _employees = await _service.getAllEmployees();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load employees: $e');
    }
  }

  // ─── Computed / Filtered ──────────────────────────────────────────────────

  List<MeetingModel> get _filteredMeetings {
    return _allMeetings.where((m) {
      final matchSearch = _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.organizerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.attendeeNames.join(' ').toLowerCase().contains(_searchQuery.toLowerCase());

      final matchStatus = _filterStatus == 'All' ||
          m.status.name.toLowerCase() == _filterStatus.toLowerCase();

      final matchType = _filterType == 'All' ||
          MeetingTypeHelper.label(m.type) == _filterType;

      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  // Quick summary stats
  MeetingStats get stats => MeetingStats(
    total: _allMeetings.length,
    approved: _allMeetings.where((m) => m.status == MeetingStatus.approved).length,
    pending: _allMeetings.where((m) => m.status == MeetingStatus.pending).length,
    completed: _allMeetings.where((m) => m.status == MeetingStatus.completed).length,
    rejected: _allMeetings.where((m) => m.status == MeetingStatus.rejected).length,
  );

  // ─── Filter Actions ───────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterStatus = 'All';
    _filterType = 'All';
    notifyListeners();
  }

  // ─── Meeting Actions ──────────────────────────────────────────────────────

  /// HR schedules a new meeting — auto-approved, attendees notified
  Future<bool> scheduleMeeting(MeetingModel meeting) async {
    _setState(ViewState.loading);
    try {
      final attendees = meeting.isAllEmployees ? _employees
          : _employees.where((e) => meeting.attendeeIds.contains(e.id)).toList();

      await _service.hrArrangeMeeting(meeting: meeting, employees: attendees);
      _setState(ViewState.success);
      return true;
    } catch (e) {
      _setError('Failed to schedule meeting: $e');
      return false;
    }
  }

  /// HR approves a pending meeting request
  Future<bool> approveMeeting(MeetingModel meeting) async {
    _setState(ViewState.loading);
    try {
      final allUsers = await _service.getAllUsers();
      await _service.approveMeeting(meeting: meeting, allUsers: allUsers);
      _setState(ViewState.success);
      return true;
    } catch (e) {
      _setError('Failed to approve meeting: $e');
      return false;
    }
  }

  /// HR rejects a pending meeting request
  Future<bool> rejectMeeting(MeetingModel meeting, String reason) async {
    _setState(ViewState.loading);
    try {
      final allUsers = await _service.getAllUsers();
      await _service.rejectMeeting(
        meeting: meeting,
        reason: reason,
        allUsers: allUsers,
      );
      _setState(ViewState.success);
      return true;
    } catch (e) {
      _setError('Failed to reject meeting: $e');
      return false;
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Future<void> markAllNotificationsRead() async {
    await _service.markAllNotificationsRead(hrUserId);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _setState(ViewState s) {
    _state = s;
    if (s != ViewState.error) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = ViewState.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _state = ViewState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _allSub?.cancel();
    _pendingSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }
}

// ─── Employee Meeting ViewModel ───────────────────────────────────────────────

class EmployeeMeetingViewModel extends ChangeNotifier {
  final MeetingService _service;
  final String employeeId;
  final String employeeName;

  EmployeeMeetingViewModel({
    required this.employeeId,
    required this.employeeName,
    MeetingService? service,
  }) : _service = service ?? MeetingService() {
    _init();
  }

  // ─── State ────────────────────────────────────────────────────────────────

  ViewState _state = ViewState.idle;
  ViewState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<MeetingModel> _myMeetings = [];
  List<MeetingModel> _organizedMeetings = [];
  List<UserModel> _otherEmployees = [];

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // ─── Filters ──────────────────────────────────────────────────────────────

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _filterStatus = 'All';
  String get filterStatus => _filterStatus;

  // ─── Subscriptions ────────────────────────────────────────────────────────

  StreamSubscription<List<MeetingModel>>? _meetingsSub;
  StreamSubscription<List<MeetingModel>>? _organizedSub;
  StreamSubscription<int>? _unreadSub;

  // ─── Init ─────────────────────────────────────────────────────────────────

  void _init() {
    _listenMyMeetings();
    _listenOrganizedMeetings();
    _listenUnreadCount();
    _loadOtherEmployees();
  }

  void _listenMyMeetings() {
    _meetingsSub = _service.streamEmployeeMeetings(employeeId).listen(
          (meetings) {
        _myMeetings = meetings;
        notifyListeners();
      },
      onError: (e) => _setError('Failed to load meetings: $e'),
    );
  }

  void _listenOrganizedMeetings() {
    _organizedSub = _service.streamOrganizedMeetings(employeeId).listen(
          (meetings) {
        _organizedMeetings = meetings;
        notifyListeners();
      },
      onError: (e) => _setError('Failed to load your requests: $e'),
    );
  }

  void _listenUnreadCount() {
    _unreadSub = _service.streamUnreadCount(employeeId).listen(
          (count) {
        _unreadCount = count;
        notifyListeners();
      },
    );
  }

  Future<void> _loadOtherEmployees() async {
    try {
      final all = await _service.getAllEmployees();
      _otherEmployees = all.where((e) => e.id != employeeId).toList();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load employees: $e');
    }
  }

  // ─── Computed ─────────────────────────────────────────────────────────────

  /// All meetings filtered by search/status
  List<MeetingModel> get filteredMeetings {
    return _myMeetings.where((m) {
      final matchSearch = _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.organizerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchStatus = _filterStatus == 'All' ||
          m.status.name.toLowerCase() == _filterStatus.toLowerCase();
      return matchSearch && matchStatus;
    }).toList();
  }

  /// Approved meetings in the future, sorted ascending
  List<MeetingModel> get upcomingMeetings {
    return _myMeetings
        .where((m) =>
    m.status == MeetingStatus.approved &&
        m.dateTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Next upcoming meeting (for dashboard preview)
  MeetingModel? get nextMeeting =>
      upcomingMeetings.isNotEmpty ? upcomingMeetings.first : null;

  /// Meetings this employee submitted as organizer
  List<MeetingModel> get myRequests => _organizedMeetings;

  /// Pending requests submitted by this employee
  List<MeetingModel> get pendingRequests =>
      _organizedMeetings.where((m) => m.status == MeetingStatus.pending).toList();

  /// Other employees to select as attendees
  List<UserModel> get otherEmployees => _otherEmployees;

  MeetingStats get stats => MeetingStats(
    total: _myMeetings.length,
    approved: upcomingMeetings.length,
    pending: pendingRequests.length,
    completed: _myMeetings.where((m) => m.status == MeetingStatus.completed).length,
    rejected: _myMeetings.where((m) => m.status == MeetingStatus.rejected).length,
  );

  // ─── Filter Actions ───────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterStatus = 'All';
    notifyListeners();
  }

  // ─── Meeting Actions ──────────────────────────────────────────────────────

  /// Employee submits a meeting request (goes to HR for approval)
  Future<bool> requestMeeting(MeetingModel meeting) async {
    _setState(ViewState.loading);
    try {
      final hrUsers = await _service.getAllHRUsers();
      await _service.employeeRequestMeeting(
        meeting: meeting,
        hrUsers: hrUsers,
      );
      _setState(ViewState.success);
      return true;
    } catch (e) {
      _setError('Failed to submit request: $e');
      return false;
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Future<void> markAllNotificationsRead() async {
    await _service.markAllNotificationsRead(employeeId);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _setState(ViewState s) {
    _state = s;
    if (s != ViewState.error) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = ViewState.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _state = ViewState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _meetingsSub?.cancel();
    _organizedSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }
}

// ─── Notification ViewModel ───────────────────────────────────────────────────

class NotificationViewModel extends ChangeNotifier {
  final MeetingService _service;
  final String userId;

  NotificationViewModel({required this.userId, MeetingService? service})
      : _service = service ?? MeetingService() {
    _init();
  }

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  StreamSubscription<List<NotificationModel>>? _sub;

  void _init() {
    _sub = _service.streamNotifications(userId).listen((notifs) {
      _notifications = notifs;
      notifyListeners();
    });
  }

  Future<void> markRead(String notifId) async {
    await _service.markNotificationRead(notifId);
  }

  Future<void> markAllRead() async {
    await _service.markAllNotificationsRead(userId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ─── Shared Data Classes ──────────────────────────────────────────────────────

class MeetingStats {
  final int total;
  final int approved;
  final int pending;
  final int completed;
  final int rejected;

  const MeetingStats({
    required this.total,
    required this.approved,
    required this.pending,
    required this.completed,
    required this.rejected,
  });
}

// ─── Helper extension (avoids importing meeting_widgets in VM) ────────────────

class MeetingTypeHelper {
  static String label(MeetingType type) {
    switch (type) {
      case MeetingType.general:  return 'Meeting';
      case MeetingType.review:   return 'Review';
      case MeetingType.training: return 'Training';
      case MeetingType.oneOnOne: return '1-on-1';
      case MeetingType.event:    return 'Event';
    }
  }
}