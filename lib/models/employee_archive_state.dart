Map<String, Object?> buildEmployeeArchiveStatePayload({
  required bool isActive,
  required DateTime archivedAtWhenInactive,
  DateTime? existingArchivedAt,
}) {
  return {
    'is_active': isActive,
    'archived_at': resolveEmployeeArchivedAt(
      isActive: isActive,
      archivedAtWhenInactive: archivedAtWhenInactive,
      existingArchivedAt: existingArchivedAt,
    )?.toUtc().toIso8601String(),
  };
}

DateTime? resolveEmployeeArchivedAt({
  required bool isActive,
  required DateTime archivedAtWhenInactive,
  DateTime? existingArchivedAt,
}) {
  if (isActive) return null;
  return existingArchivedAt ?? archivedAtWhenInactive;
}
