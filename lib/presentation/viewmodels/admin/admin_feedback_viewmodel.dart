import 'package:flutter/material.dart';
import '../../../data/services/admin/admin_audit_service.dart';
import '../../../data/services/admin/admin_exceptions.dart';
import '../../../data/services/admin/feedback_service.dart';
import '../../../domain/models/admin/admin_models.dart';

/// ViewModel managing feedback triage, notes, replies, and status transitions.
class AdminFeedbackViewModel extends ChangeNotifier {
  final FeedbackService feedbackService;
  final AdminAuditService auditService;

  AdminFeedbackViewModel({
    required this.feedbackService,
    required this.auditService,
  });

  List<UserFeedback> _feedbackList = [];
  UserFeedback? _selectedFeedback;
  List<FeedbackInternalNote> _internalNotes = [];
  List<FeedbackReply> _replies = [];

  bool _isLoading = false;
  bool _isLoadingDetails = false;
  String? _errorMessage;

  FeedbackCategory? _selectedCategory;
  FeedbackStatus? _selectedStatus;

  List<UserFeedback> get feedbackList => _feedbackList;
  UserFeedback? get selectedFeedback => _selectedFeedback;
  List<FeedbackInternalNote> get internalNotes => _internalNotes;
  List<FeedbackReply> get replies => _replies;
  bool get isLoading => _isLoading;
  bool get isLoadingDetails => _isLoadingDetails;
  String? get errorMessage => _errorMessage;
  FeedbackCategory? get selectedCategory => _selectedCategory;
  FeedbackStatus? get selectedStatus => _selectedStatus;

  void setCategoryFilter(FeedbackCategory? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    fetchFeedback();
  }

  void setStatusFilter(FeedbackStatus? status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    fetchFeedback();
  }

  /// Fetches feedback items with current filters.
  Future<void> fetchFeedback() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _feedbackList = await feedbackService.fetchFeedbackList(
        category: _selectedCategory,
        status: _selectedStatus,
      );
    } on AdminBackendUnavailableException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load feedback inbox: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a feedback item and loads its internal notes and reply thread.
  Future<void> selectFeedback(UserFeedback feedback) async {
    _selectedFeedback = feedback;
    _isLoadingDetails = true;
    _internalNotes = [];
    _replies = [];
    notifyListeners();

    try {
      final results = await Future.wait([
        feedbackService.fetchInternalNotes(feedback.id),
        feedbackService.fetchReplies(feedback.id),
      ]);
      _internalNotes = results[0] as List<FeedbackInternalNote>;
      _replies = results[1] as List<FeedbackReply>;
    } catch (e) {
      debugPrint('[AdminFeedbackViewModel] Details load notice: $e');
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedFeedback = null;
    _internalNotes = [];
    _replies = [];
    notifyListeners();
  }

  /// Updates status of selected feedback.
  Future<bool> updateStatus(FeedbackStatus newStatus, AdminUser admin) async {
    final current = _selectedFeedback;
    if (current == null) return false;

    try {
      await feedbackService.updateFeedbackStatus(
        feedbackId: current.id,
        newStatus: newStatus,
      );

      await auditService.recordAction(
        action: AuditAction.feedbackStatusUpdated,
        targetType: 'feedback',
        targetId: current.id,
        previousState: {'status': current.status.value},
        newState: {'status': newStatus.value},
      );

      final updated = current.copyWith(status: newStatus, updatedAt: DateTime.now());
      _selectedFeedback = updated;

      final idx = _feedbackList.indexWhere((f) => f.id == current.id);
      if (idx != -1) {
        _feedbackList[idx] = updated;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Adds an internal administrative note to the active feedback item.
  Future<bool> addInternalNote(String noteText, AdminUser admin) async {
    final current = _selectedFeedback;
    if (current == null || noteText.trim().isEmpty) return false;

    try {
      final note = await feedbackService.addInternalNote(
        feedbackId: current.id,
        note: noteText.trim(),
        adminUserId: admin.id,
        adminDisplayName: admin.displayName,
      );
      _internalNotes.add(note);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add note: $e';
      notifyListeners();
      return false;
    }
  }

  /// Posts an administrative reply in the feedback thread.
  Future<bool> postReply(String messageText, AdminUser admin) async {
    final current = _selectedFeedback;
    if (current == null || messageText.trim().isEmpty) return false;

    try {
      final reply = await feedbackService.postAdminReply(
        feedbackId: current.id,
        message: messageText.trim(),
        adminUserId: admin.id,
        adminDisplayName: admin.displayName,
      );
      _replies.add(reply);

      await auditService.recordAction(
        action: AuditAction.feedbackReplyPosted,
        targetType: 'feedback',
        targetId: current.id,
        newState: {'reply_id': reply.id},
      );

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to post reply: $e';
      notifyListeners();
      return false;
    }
  }
}
