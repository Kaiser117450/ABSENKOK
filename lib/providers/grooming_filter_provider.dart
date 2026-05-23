import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/grooming_qc_service.dart';

class GroomingFilterNotifier extends StateNotifier<GroomingFilter> {
  GroomingFilterNotifier() : super(GroomingFilter.last30Days());

  void setRange({required DateTime since, required DateTime until}) {
    state = GroomingFilter(
      since: since,
      until: until,
      outletIds: state.outletIds,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void toggleOutlet(String outletId) {
    final next = Set<String>.from(state.outletIds);
    if (!next.add(outletId)) next.remove(outletId);
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: next,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void setEmployeeQuery(String? query) {
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: state.outletIds,
      employeeQuery: query,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void setNeedsReviewOnly(bool value) {
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: state.outletIds,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: value,
      overriddenOnly: state.overriddenOnly,
    );
  }

  void setOverriddenOnly(bool value) {
    state = GroomingFilter(
      since: state.since,
      until: state.until,
      outletIds: state.outletIds,
      employeeQuery: state.employeeQuery,
      needsReviewOnly: state.needsReviewOnly,
      overriddenOnly: value,
    );
  }

  void reset() {
    state = GroomingFilter.last30Days();
  }
}

final groomingFilterProvider =
    StateNotifierProvider<GroomingFilterNotifier, GroomingFilter>(
        (_) => GroomingFilterNotifier());

final groomingRowsProvider =
    StreamProvider.autoDispose<List<GroomingRow>>((ref) {
  final filter = ref.watch(groomingFilterProvider);
  return GroomingQcService.instance.watchRows(filter);
});
