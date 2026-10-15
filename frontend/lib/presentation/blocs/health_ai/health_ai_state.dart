abstract class HealthAiState {}

class HealthAiInitial extends HealthAiState {}

class HealthAiLoading extends HealthAiState {}

class HealthAiLoaded extends HealthAiState {
  final Map<String, dynamic> aiRiskData;
  HealthAiLoaded({required this.aiRiskData});
}

class HealthAiError extends HealthAiState {
  final String message;
  HealthAiError({required this.message});
}