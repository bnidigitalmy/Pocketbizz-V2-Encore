import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    productsApi: ref.watch(productsApiProvider),
    inventoryApi: ref.watch(inventoryApiProvider),
    salesApi: ref.watch(salesApiProvider),
  );
});

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>(
  (ref) => DashboardController(ref.watch(dashboardRepositoryProvider))..load(),
);

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._repository) : super(const DashboardState.loading());

  final DashboardRepository _repository;

  Future<void> load() async {
    try {
      final metrics = await _repository.fetchMetrics();
      state = DashboardState.data(metrics);
    } on Object catch (error) {
      state = DashboardState.error(error.toString());
    }
  }
}

class DashboardState {
  const DashboardState._({
    required this.isLoading,
    this.metrics,
    this.error,
  });

  const DashboardState.loading() : this._(isLoading: true);

  const DashboardState.data(DashboardMetrics metrics)
      : this._(isLoading: false, metrics: metrics);

  const DashboardState.error(String message)
      : this._(isLoading: false, error: message);

  final bool isLoading;
  final DashboardMetrics? metrics;
  final String? error;
}

