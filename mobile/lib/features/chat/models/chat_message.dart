class ActivityEventModel {
  final String stage;
  final int index;
  final int total;
  final String title;
  final String detail;
  final String status; // 'pending' | 'in_progress' | 'completed' | 'failed'
  final DateTime timestamp;

  const ActivityEventModel({
    required this.stage,
    required this.index,
    required this.total,
    required this.title,
    required this.detail,
    required this.status,
    required this.timestamp,
  });

  factory ActivityEventModel.fromMap(Map<String, dynamic> map) {
    return ActivityEventModel(
      stage: map['stage']?.toString() ?? '',
      index: (map['index'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 7,
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      status: map['status']?.toString() ?? 'completed',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  ActivityEventModel copyWith({
    String? status,
    String? detail,
  }) {
    return ActivityEventModel(
      stage: stage,
      index: index,
      total: total,
      title: title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      timestamp: timestamp,
    );
  }
}

class CitationModel {
  final String fileId;
  final String filename;
  final int pageNumber;
  final String sectionTitle;
  final String display;
  final String snippet;

  const CitationModel({
    this.fileId = '',
    required this.filename,
    this.pageNumber = 1,
    this.sectionTitle = '',
    required this.display,
    this.snippet = '',
  });

  factory CitationModel.fromMap(Map<String, dynamic> map) {
    final fn = map['filename']?.toString() ?? 'Hujjat';
    final page = int.tryParse(map['page_number']?.toString() ?? '1') ?? 1;
    final section = map['section_title']?.toString() ?? '';
    final snippet = map['snippet']?.toString() ?? '';
    final fileId = map['file_id']?.toString() ?? '';
    final display = map['display']?.toString() ??
        (section.isNotEmpty
            ? '$fn • $page-sahifa ($section)'
            : '$fn • $page-sahifa');
    return CitationModel(
      fileId: fileId,
      filename: fn,
      pageNumber: page,
      sectionTitle: section,
      display: display,
      snippet: snippet,
    );
  }

  factory CitationModel.fromString(String raw) {
    if (raw.contains('filename:') || raw.contains('page_number:')) {
      final fnMatch = RegExp(r'filename:\s*([^,}\n]+)').firstMatch(raw);
      final pageMatch =
          RegExp(r'page_number:\s*([0-9]+)').firstMatch(raw);
      final fn = fnMatch?.group(1)?.trim() ?? 'Hujjat';
      final page = int.tryParse(pageMatch?.group(1)?.trim() ?? '1') ?? 1;
      return CitationModel(
        filename: fn,
        pageNumber: page,
        display: '$fn • $page-sahifa',
      );
    }
    return CitationModel(
      filename: raw,
      display: raw,
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final String status;
  final DateTime createdAt;
  final List<String> fileIds;
  final List<String> citations;
  final List<CitationModel> citationModels;
  final List<ActivityEventModel> activityEvents;
  final List<String> suggestedQuestions;
  final Map<String, dynamic>? extractedEntities;
  final String? analysisMode;
  final String? checkpointId;
  final bool isInterrupted;
  final String? interruptionMessage;
  final String? statusText;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.status,
    required this.createdAt,
    this.fileIds = const [],
    this.citations = const [],
    this.citationModels = const [],
    this.activityEvents = const [],
    this.suggestedQuestions = const [],
    this.extractedEntities,
    this.analysisMode,
    this.checkpointId,
    this.isInterrupted = false,
    this.interruptionMessage,
    this.statusText,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isStreaming => status == 'streaming';
  bool get isCancelled => status == 'cancelled';
  bool get isFailed => status == 'failed';
  bool get hasFiles => fileIds.isNotEmpty;
  bool get hasCitations => citations.isNotEmpty || citationModels.isNotEmpty;
  bool get hasSuggestions => suggestedQuestions.isNotEmpty;
  bool get hasStructuredData =>
      extractedEntities != null && extractedEntities!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['attached_file_ids'] as List?;
    final filesList = rawFiles != null
        ? rawFiles.map((e) => e.toString()).toList()
        : <String>[];

    final rawCitations = json['citations'] as List?;
    final citList = <String>[];
    final citModelList = <CitationModel>[];
    if (rawCitations != null) {
      for (final item in rawCitations) {
        if (item is Map<String, dynamic>) {
          final model = CitationModel.fromMap(item);
          citModelList.add(model);
          citList.add(model.display);
        } else if (item is Map) {
          final model =
              CitationModel.fromMap(Map<String, dynamic>.from(item));
          citModelList.add(model);
          citList.add(model.display);
        } else if (item != null) {
          final str = item.toString();
          final model = CitationModel.fromString(str);
          citModelList.add(model);
          citList.add(model.display);
        }
      }
    }

    final rawSuggestions = json['suggested_questions'] as List?;
    final sugList = rawSuggestions != null
        ? rawSuggestions.map((e) => e.toString()).toList()
        : <String>[];

    Map<String, dynamic>? entities;
    if (json['extracted_entities'] is Map) {
      entities = Map<String, dynamic>.from(json['extracted_entities']);
    }

    final rawEvents = json['activity_events'] as List?;
    final eventList = <ActivityEventModel>[];
    if (rawEvents != null) {
      for (final ev in rawEvents) {
        if (ev is Map<String, dynamic>) {
          eventList.add(ActivityEventModel.fromMap(ev));
        } else if (ev is Map) {
          eventList.add(ActivityEventModel.fromMap(Map<String, dynamic>.from(ev)));
        }
      }
    }

    final statusVal = json['status'] ?? 'completed';

    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      status: statusVal,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      fileIds: filesList,
      citations: citList,
      citationModels: citModelList,
      activityEvents: eventList,
      suggestedQuestions: sugList,
      extractedEntities: entities,
      analysisMode: json['analysis_mode'] as String?,
      checkpointId: json['checkpoint_id'] as String?,
      isInterrupted: (json['is_interrupted'] == true) || statusVal == 'interrupted',
      interruptionMessage: json['interruption_message'] as String?,
      statusText: json['status_text'] as String?,
    );
  }

  ChatMessage copyWith({
    String? content,
    String? status,
    List<String>? fileIds,
    List<String>? citations,
    List<CitationModel>? citationModels,
    List<ActivityEventModel>? activityEvents,
    List<String>? suggestedQuestions,
    Map<String, dynamic>? extractedEntities,
    String? analysisMode,
    String? checkpointId,
    bool? isInterrupted,
    String? interruptionMessage,
    String? statusText,
    bool clearStatusText = false,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt,
      fileIds: fileIds ?? this.fileIds,
      citations: citations ?? this.citations,
      citationModels: citationModels ?? this.citationModels,
      activityEvents: activityEvents ?? this.activityEvents,
      suggestedQuestions: suggestedQuestions ?? this.suggestedQuestions,
      extractedEntities: extractedEntities ?? this.extractedEntities,
      analysisMode: analysisMode ?? this.analysisMode,
      checkpointId: checkpointId ?? this.checkpointId,
      isInterrupted: isInterrupted ?? this.isInterrupted,
      interruptionMessage: interruptionMessage ?? this.interruptionMessage,
      statusText: clearStatusText ? null : (statusText ?? this.statusText),
    );
  }
}
