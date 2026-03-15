# ABSENKOK

Repo ini saat ini menyimpan dua codebase yang berbeda dalam satu Git repository:

- Flutter app untuk sistem absensi NFC internal
- Astro website untuk landing page / marketing site

## Struktur Utama

- `lib/`, `android/`, `assets/`, `test/`, `pubspec.yaml`: aplikasi Flutter
- `src/`, `public/`, `package.json`, `astro.config.mjs`: website Astro
- `.planning/`, `.codex/`, `.claude/`: workflow, planning, dan automation files

## Branch Yang Disarankan

- `main`: snapshot gabungan yang saat ini berisi app Flutter + website Astro
- `app-flutter`: branch bersih untuk history aplikasi Flutter
- `website-astro`: branch bersih untuk history website Astro

Kalau ingin kerja fokus per area, pakai branch khusus sesuai kebutuhan dan gunakan `main` hanya sebagai branch gabungan.

## Menjalankan Flutter App

Prasyarat:

- Flutter SDK terpasang
- Android SDK / emulator bila ingin run di Android
- file `.env` tersedia jika dibutuhkan environment lokal

Perintah umum:

```bash
flutter pub get
flutter run
```

Perintah tambahan:

```bash
flutter test
flutter analyze
flutter build apk --debug
```

## Menjalankan Website Astro

Prasyarat:

- Node.js dan npm terpasang

Perintah umum:

```bash
npm install
npm run dev
```

Perintah tambahan:

```bash
npm run build
npm run preview
npm run check
```

## Catatan

- Root repo ini memang berisi dua toolchain sekaligus, jadi file Flutter dan Astro akan hidup berdampingan.
- Jika nanti ingin dipisah total, opsi paling bersih adalah memindahkan website dan app ke repo terpisah.
