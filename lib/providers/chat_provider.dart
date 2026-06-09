import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/message_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _svc;

  ChatProvider({required ChatService chatService}) : _svc = chatService;

  List<MessageModel> _messages = [];
  ChatSummary? _chatSummary;
  List<ChatSummary> _allChats = [];
  int _totalUnreadCount = 0;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isOtherTyping = false;
  bool _isOtherOnline = false;
  DateTime? _otherLastSeenAt;
  String? _errorMessage;

  StreamSubscription<List<MessageModel>>? _msgSub;
  StreamSubscription<ChatSummary?>? _summarySub;
  StreamSubscription<List<ChatSummary>>? _allChatsSub;
  StreamSubscription<int>? _totalUnreadSub;
  StreamSubscription<bool>? _typingSub;
  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<DateTime?>? _lastSeenSub;
  Timer? _typingTimer;

  String? _activeChatId;
  String? _activeMyId;
  String? _presenceOtherId;
  String? _subscribedUserId;

  // Local optimistic read state: prevents stale Firestore snapshots from
  // temporarily re-showing unread badges after the user reads a chat.
  //
  // Key  = '$chatId::$userId'
  // Value = when the hold was SET (so we can invalidate it on new messages).
  // A hold is cancelled if chat.lastMessageAt > setAt (new message arrived).
  // Holds expire after 8 seconds regardless.
  final Map<String, DateTime> _readClearHoldSetAt = {};

  // ─── Getters ───────────────────────────────────────────
  List<MessageModel> get messages => _messages;
  ChatSummary? get chatSummary => _chatSummary;
  List<ChatSummary> get allChats => _allChats;

  /// Real-time total unread from Firestore stream.
  /// Falls back to summing allChats locally.
  int get totalUnreadCount {
    if (_totalUnreadCount > 0) return _totalUnreadCount;
    if (_subscribedUserId == null) return 0;
    return _allChats.fold<int>(
      0,
      (sum, c) => sum + c.unreadCountFor(_subscribedUserId!),
    );
  }

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isOtherTyping => _isOtherTyping;
  bool get isOtherOnline => _isOtherOnline;
  DateTime? get otherLastSeenAt => _otherLastSeenAt;
  String? get errorMessage => _errorMessage;

  // ─── Chat list subscription ─────────────────────────────

  void subscribeAllChats(String userId, bool isClient) {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    if (_subscribedUserId == uid && _allChatsSub != null) return;

    _subscribedUserId = uid;
    _allChatsSub?.cancel();
    _totalUnreadSub?.cancel();

    _allChatsSub = _svc.userChatsStream(uid, isClient).listen(
      (chats) {
        _allChats = chats.map((c) => _applyReadClearHold(c, uid)).toList();
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = _cleanError(e);
        notifyListeners();
      },
    );

    // Dedicated total-unread stream for badges (avoids re-summing allChats).
    _totalUnreadSub = _svc.totalUnreadStream(uid).listen(
      (count) {
        _totalUnreadCount = count;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  // ─── Single chat subscription ───────────────────────────

  void subscribeMessagesAndSummary({
    required String chatId,
    required String myId,
  }) {
    if (_activeChatId == chatId && _activeMyId == myId && _msgSub != null) {
      return;
    }

    _msgSub?.cancel();
    _summarySub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _lastSeenSub?.cancel();

    _activeChatId = chatId;
    _activeMyId = myId;
    _presenceOtherId = null;
    _messages = [];
    _chatSummary = _summaryFromCurrentList(chatId);
    _isOtherTyping = false;
    _isOtherOnline = false;
    _otherLastSeenAt = null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _msgSub = _svc.messagesStream(chatId).listen(
      (msgs) {
        _messages = msgs;
        _isLoading = false;
        _errorMessage = null;
        _clearLocalUnread(chatId: chatId, userId: myId);
        notifyListeners();
        // Mark read on Firestore whenever new messages arrive (while chat is open).
        _svc.markMessagesSeen(chatId: chatId, myId: myId);
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = _cleanError(e);
        notifyListeners();
      },
    );

    _summarySub = _svc.chatSummaryStream(chatId).listen(
      (summary) {
        _chatSummary = summary == null
            ? null
            : _applyReadClearHold(summary, myId);
        if (summary == null) {
          _isLoading = false;
          _errorMessage = 'Chat not found.';
        }
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = _cleanError(e);
        notifyListeners();
      },
    );

    _svc.setOnline(chatId: chatId, userId: myId, isOnline: true);
  }

  void attachPresence({
    required String chatId,
    required String myId,
    required String otherUserId,
  }) {
    if (otherUserId.isEmpty || otherUserId == 'placeholder') return;
    if (_presenceOtherId == otherUserId) return;

    _presenceOtherId = otherUserId;
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _lastSeenSub?.cancel();

    _typingSub = _svc.otherTypingStream(chatId, otherUserId).listen(
      (typing) {
        _isOtherTyping = typing;
        notifyListeners();
      },
      onError: (_) {
        _isOtherTyping = false;
        notifyListeners();
      },
    );

    _onlineSub = _svc.otherOnlineStream(chatId, otherUserId).listen(
      (online) {
        _isOtherOnline = online;
        notifyListeners();
      },
      onError: (_) {
        _isOtherOnline = false;
        notifyListeners();
      },
    );

    _lastSeenSub = _svc.otherLastSeenStream(chatId, otherUserId).listen(
      (lastSeen) {
        _otherLastSeenAt = lastSeen;
        notifyListeners();
      },
      onError: (_) {
        _otherLastSeenAt = null;
        notifyListeners();
      },
    );
  }

  void subscribeChat({
    required String chatId,
    required String myId,
    required String otherUserId,
  }) {
    subscribeMessagesAndSummary(chatId: chatId, myId: myId);
    attachPresence(chatId: chatId, myId: myId, otherUserId: otherUserId);
  }

  // ─── Send actions ────────────────────────────────────────

  Future<bool> sendText({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    required String otherUserId,
  }) async {
    if (text.trim().isEmpty) return false;
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.sendTextMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        text: text.trim(),
        otherUserId: otherUserId,
      );
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> sendImage({
    required String chatId,
    required String senderId,
    required String senderName,
    required File imageFile,
    String? otherUserId,
  }) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.sendImageMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        imageFile: imageFile,
        otherUserId: otherUserId,
      );
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> sendVoice({
    required String chatId,
    required String senderId,
    required String senderName,
    required File voiceFile,
    int? voiceDurationMs,
    String? otherUserId,
  }) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.sendVoiceMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        voiceFile: voiceFile,
        voiceDurationMs: voiceDurationMs,
        otherUserId: otherUserId,
      );
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> sendLocation({
    required String chatId,
    required String senderId,
    required String senderName,
    required double lat,
    required double lng,
    String? label,
  }) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.sendLocationMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        lat: lat,
        lng: lng,
        label: label,
      );
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _svc.deleteMessage(chatId: chatId, messageId: messageId);
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  // ─── Typing ─────────────────────────────────────────────

  void onTyping({required String chatId, required String userId}) {
    _svc.setTyping(chatId: chatId, userId: userId, isTyping: true);
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(seconds: 2),
      () => _svc.setTyping(chatId: chatId, userId: userId, isTyping: false),
    );
  }

  // ─── Read management ─────────────────────────────────────

  Future<void> markChatRead({
    required String chatId,
    required String userId,
  }) async {
    final uid = userId.trim();
    final cid = chatId.trim();
    if (uid.isEmpty || cid.isEmpty) return;

    // Optimistic local update first.
    _clearLocalUnread(chatId: cid, userId: uid);
    notifyListeners();

    try {
      await _svc.markMessagesSeen(chatId: cid, myId: uid);
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  Future<void> markAllVisibleChatsRead({
    required String userId,
    required bool isClient,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;

    // Optimistic local update — clear counts WITHOUT setting hold timers.
    // Setting holds for every chat would suppress new incoming messages for
    // 8 seconds, which is the root cause of the "unread not showing" bug.
    final now = DateTime.now();
    _allChats = _allChats.map((c) {
      final counts = Map<String, int>.from(c.unreadCounts)..[uid] = 0;
      final reads = Map<String, DateTime>.from(c.lastReadAt)..[uid] = now;
      return c.copyWith(unreadCount: 0, unreadCounts: counts, lastReadAt: reads);
    }).toList();
    if (_chatSummary != null) {
      final c = _chatSummary!;
      final counts = Map<String, int>.from(c.unreadCounts)..[uid] = 0;
      final reads = Map<String, DateTime>.from(c.lastReadAt)..[uid] = now;
      _chatSummary =
          c.copyWith(unreadCount: 0, unreadCounts: counts, lastReadAt: reads);
    }
    _totalUnreadCount = 0;
    notifyListeners();

    try {
      await _svc.markAllUserChatsSeen(userId: uid, isClient: isClient);
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
  }

  // ─── Leave / cleanup ─────────────────────────────────────

  void leaveChat({required String chatId, required String userId}) {
    _typingTimer?.cancel();
    if (userId.isNotEmpty) {
      _svc.setTyping(chatId: chatId, userId: userId, isTyping: false);
      _svc.setOnline(chatId: chatId, userId: userId, isOnline: false);
    }
    _msgSub?.cancel();
    _summarySub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _lastSeenSub?.cancel();
    _msgSub = null;
    _summarySub = null;
    _messages = [];
    _chatSummary = _summaryFromCurrentList(chatId);
    _isLoading = false;
    _isOtherTyping = false;
    _isOtherOnline = false;
    _otherLastSeenAt = null;
    _activeChatId = null;
    _activeMyId = null;
    _presenceOtherId = null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Internal helpers ────────────────────────────────────

  ChatSummary? _summaryFromCurrentList(String chatId) {
    for (final chat in _allChats) {
      if (chat.chatId == chatId || chat.bookingId == chatId) return chat;
    }
    return null;
  }

  ChatSummary _chatWithClearedUnread(ChatSummary chat, String userId,
      {bool setHold = true}) {
    if (setHold) {
      _holdReadClear(chat.chatId, userId);
      if (chat.bookingId.isNotEmpty && chat.bookingId != chat.chatId) {
        _holdReadClear(chat.bookingId, userId);
      }
    }

    final counts = Map<String, int>.from(chat.unreadCounts);
    counts[userId] = 0;
    final reads = Map<String, DateTime>.from(chat.lastReadAt);
    reads[userId] = DateTime.now();

    return chat.copyWith(
      unreadCount: 0,
      unreadCounts: counts,
      lastReadAt: reads,
    );
  }

  void _holdReadClear(String chatId, String userId) {
    final id = chatId.trim();
    final uid = userId.trim();
    if (id.isEmpty || uid.isEmpty) return;
    _readClearHoldSetAt['$id::$uid'] = DateTime.now();
  }

  /// A hold is valid only when BOTH conditions are true:
  ///  (a) less than 8 seconds since it was set, AND
  ///  (b) no new message has arrived since the hold was set.
  /// Passing [lastMessageAt] lets us detect condition (b).
  bool _hasReadClearHold(String chatId, String userId,
      [DateTime? lastMessageAt]) {
    final key = '${chatId.trim()}::${userId.trim()}';
    final setAt = _readClearHoldSetAt[key];
    if (setAt == null) return false;

    // (a) expired by time
    if (DateTime.now().difference(setAt).inSeconds > 8) {
      _readClearHoldSetAt.remove(key);
      return false;
    }
    // (b) a new message arrived after the hold was set — invalidate
    if (lastMessageAt != null && lastMessageAt.isAfter(setAt)) {
      _readClearHoldSetAt.remove(key);
      return false;
    }
    return true;
  }

  ChatSummary _applyReadClearHold(ChatSummary chat, String userId) {
    final uid = userId.trim();
    final lma = chat.lastMessageAt;

    // Check if a hold is active using timestamp comparison.
    // _hasReadClearHold cancels the hold if lastMessageAt > holdSetAt.
    final holdActive = _hasReadClearHold(chat.chatId, userId, lma) ||
        (chat.bookingId.isNotEmpty &&
            _hasReadClearHold(chat.bookingId, userId, lma));

    // No hold → always trust Firestore data.
    if (!holdActive) return chat;

    // Hold is active. Now use the Firestore counter as the tie-breaker.
    // This handles clock skew: if the server clock is slightly behind the
    // client clock, lastMessageAt < holdSetAt even for genuine new messages.
    //
    // Rule: if Firestore ALREADY shows unreadCounts[uid] == 0, our write
    // has landed — cancel the hold and show clean data.
    // If Firestore still shows > 0, it is the stale snapshot we must suppress.
    final firestoreUnread = (chat.unreadCounts[uid] ?? 0).clamp(0, 9999);
    if (firestoreUnread == 0) {
      // Write landed — release hold.
      _readClearHoldSetAt.remove('${chat.chatId}::$uid');
      _readClearHoldSetAt.remove('${chat.bookingId}::$uid');
      return chat;
    }

    // Stale snapshot — suppress with locally-cleared copy (hold lasts ≤8s).
    return _chatWithClearedUnread(chat, userId, setHold: false);
  }

  void _clearLocalUnread({
    required String chatId,
    required String userId,
  }) {
    _allChats = _allChats
        .map((c) =>
            c.chatId == chatId || c.bookingId == chatId
                ? _chatWithClearedUnread(c, userId)
                : c)
        .toList();

    if (_chatSummary != null &&
        (_chatSummary!.chatId == chatId ||
            _chatSummary!.bookingId == chatId)) {
      _chatSummary = _chatWithClearedUnread(_chatSummary!, userId);
    }
  }

  String _cleanError(Object e) =>
      e.toString().replaceAll('Exception: ', '').trim();

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgSub?.cancel();
    _summarySub?.cancel();
    _allChatsSub?.cancel();
    _totalUnreadSub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _lastSeenSub?.cancel();
    super.dispose();
  }
}
