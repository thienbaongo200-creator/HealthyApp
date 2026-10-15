import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/health_repository.dart';

// --- EVENTS ---
abstract class HealthAiEvent {}

class FetchHealthAiDataEvent extends HealthAiEvent {
  final String profileId;
  FetchHealthAiDataEvent({required this.profileId});
}

// --- STATES ---
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

// --- BLOC ---
class HealthAiBloc extends Bloc<HealthAiEvent, HealthAiState> {
  final HealthRepository _healthRepository;

  HealthAiBloc(this._healthRepository) : super(HealthAiInitial()) {
    on<FetchHealthAiDataEvent>((event, emit) async {
      emit(HealthAiLoading());
      try {
        final riskData = await _healthRepository.fetchAiRiskAssessment(event.profileId);
        if (riskData != null) {
          emit(HealthAiLoaded(aiRiskData: riskData));
        } else {
          emit(HealthAiError(message: "Không thể tải dữ liệu đánh giá rủi ro từ AI."));
        }
      } catch (e) {
        emit(HealthAiError(message: "Đã xảy ra lỗi: $e"));
      }
    });
  }
}