import 'edit_state.dart';

enum HistoryActionType {
  crop,
  filter,
  adjust,
}

class HistoryEntry {
  const HistoryEntry({
    required this.type,
    required this.toolName,
    required this.previousState,
    required this.nextState,
    required this.timestampMs,
  });

  final HistoryActionType type;
  final String toolName;
  final EditState previousState;
  final EditState nextState;
  final int timestampMs;
}
