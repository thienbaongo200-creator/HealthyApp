abstract class HealthAiEvent {}

class FetchHealthAiDataEvent extends HealthAiEvent {
  final String profileId;
  FetchHealthAiDataEvent({required this.profileId});
}