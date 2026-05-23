# UAT — Attendance Photo Redesign

Run through each step on a real kiosk device with a real admin account. Tick each box.

## Kiosk capture
- [ ] Scan NFC, position face badly (off-centre, too far): pill remains "Posisikan wajah…" with directional hint.
- [ ] Position face well; oval turns white solid, pill says "Tahan posisi…", progress arc draws.
- [ ] After 1 s aligned hold, oval turns green and pill says "Kedipkan mata sekali 👁️".
- [ ] Blink once: capture fires, photo flashes, attendance submits.
- [ ] Hold eyes closed without opening: capture does NOT fire. Pill remains "Kedipkan mata".
- [ ] Move face mid-blink-prompt: state resets to "Posisikan wajah".
- [ ] Print a face on paper and present it: cannot pass blink check (no closed→open transition observable).
- [ ] After 3 failed blink windows: "Coba Lagi" button appears. Tap → returns to searching.
- [ ] Tap Batal (if exposed): exits capture flow.

## Admin
- [ ] Within ~2 s of a kiosk capture, a new card appears at the top of the Grooming QC List tab (realtime).
- [ ] Beard photo: card shows red "Jenggot" chip and score <8.
- [ ] Hijab photo: card shows blue "Hijab" chip, "Rambut tertutup" chip, score ≥9 (regression).
- [ ] Topi photo (male crew): card shows grey "Topi" chip (NOT "Hijab"), score ≥9.
- [ ] Tap Override skor: dialog opens with slider + note field; Simpan disabled until note ≥10 chars.
- [ ] Submit override with valid note: pill updates to "old→new ✏", chip stays as AI judged.
- [ ] Open filter sheet: change to 7 hari + one outlet + Hanya butuh review on, Terapkan.
- [ ] Switch to Per Karyawan tab: cards sorted worst-first, sparkline draws.
- [ ] Tap "Detail per foto" on a card: returns to List tab filtered to that employee.
- [ ] Analytics tab: top violators bar chart, per-outlet pass rate, 30d trend line all render with current data.
- [ ] Tap Export CSV FAB: share sheet opens. CSV contains the agreed 17 columns including penutup_kepala.

## Operational safety
- [ ] Network drop during capture: attendance still queues offline; photo stored locally for retry (existing Phase 64 behaviour, not regressed).
- [ ] Vision API hard fail: attendance log still saved, attendance_photo_analysis row missing — admin UI shows no QC chips, score "-".
- [ ] USE_LEGACY_VISION_SCORING=true: new captures still produce a row, model_name='cloud-vision-legacy', per-criteria columns NULL — UI degrades to legacy chips.
