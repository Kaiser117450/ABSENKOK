# Android Release Contract

Dokumen ini adalah kontrak release Android v7.0 yang ditrack di repository. Jangan mengandalkan `java.exe` pertama di PATH atau `android/local.properties` sebagai source of truth bersama; `android/local.properties` tetap menjadi bukti machine-local, sedangkan kontrak repo hidup di helper dan dokumen ini.

## Supported Toolchain

| Surface | Supported value |
| --- | --- |
| Gradle runtime JDK | Android Studio JBR Java 21 |
| Canonical Flutter CLI | `C:\flutter\bin\flutter.bat` |
| Flutter SDK | 3.41.1 |
| Android Gradle Plugin | 8.11.1 |
| Gradle wrapper | 8.14 |
| Kotlin Android plugin | 1.9.25 |

Pinned v7.0 baseline: Flutter 3.41.1, AGP 8.11.1, Gradle 8.14, Kotlin 1.9.25, and Java 21 JBR.

Catatan: app module tetap menargetkan Java/Kotlin 17 di `android/app/build.gradle.kts`; kontrak ini hanya memastikan Gradle berjalan di Java 21 JBR yang sudah terbukti kompatibel untuk v7.0.

## How To Verify The Environment

Jalankan helper Windows yang ditrack sebelum perintah release apa pun:

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly
```

Helper tersebut akan:

- memakai `ABSENKOK_JAVA_HOME` bila diset, kalau tidak fallback ke `C:\Program Files\Android\Android Studio\jbr`
- memverifikasi runtime Java 21
- mengekspor `JAVA_HOME` untuk sesi PowerShell saat ini
- memastikan canonical Flutter lane tetap `C:\flutter\bin\flutter.bat`

## Operator Notes

- `android/local.properties` boleh tetap berbeda per mesin dan tidak perlu ditrack.
- Kontrak ini sengaja fokus ke runtime/toolchain baseline. Instruksi signing, packaging, atau CI/CD belum termasuk di Phase 47.
- Release commands Windows harus masuk lewat helper `tool/release_env.ps1` supaya drift antara PATH Java dan Java 21 JBR terlihat lebih awal.
- Mulai Phase 48, artifact `release` harus memakai private upload key; file nyata `android/key.properties` dan upload keystore tetap private dan tidak boleh masuk source control.
- Repo hanya menyediakan `android/key.properties.example` sebagai schema placeholder untuk `storePassword`, `keyPassword`, `keyAlias`, dan `storeFile`.

## Release Preflight

Satu lane preflight yang ditrack untuk v7.0 adalah:

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1
```

Urutan stage yang dijalankan:

1. `C:\flutter\bin\flutter.bat analyze`
2. `C:\flutter\bin\flutter.bat test`
3. `android\gradlew.bat :app:compileReleaseSources`

Ekspektasi Phase 47:

- lane ini gagal cepat pada stage pertama yang merah
- lane ini tidak memanggil `assembleRelease`, `bundleRelease`, `packageRelease`, atau task signing
- pada checkout saat ini lane memang diperkirakan gagal di `flutter analyze` atau `flutter test`, dan itu adalah perilaku yang diinginkan
- ketika analyze dan test sudah hijau, lane yang sama tetap akan lanjut ke `:app:compileReleaseSources` untuk mengecek release-only compilation tanpa masuk ke packaging

Hasil observasi 2026-03-23: lane berhenti di `flutter analyze` dengan exit code `1` setelah menemukan 152 issue. Itu membuktikan preflight gagal sebelum packaging/signing dimulai, sehingga operator tidak perlu lompat ke `build apk --release` untuk mengetahui repo sedang merah.

## v7.0 Compatibility Decision

v7.0 sengaja menahan compatibility line berikut:

- Flutter 3.41.1
- AGP 8.11.1
- Gradle 8.14
- Kotlin 1.9.25
- Java 21 JBR

Keputusan ini disengaja untuk release hardening. Warning Flutter tentang umur dukungan Kotlin 1.9.25 diakui, tetapi milestone v7.0 tidak memakai `--android-skip-build-dependency-validation` dan tidak membuka surprise upgrade Kotlin/AGP/Gradle di mesin operator. Bila pin ini perlu berubah, `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`, `tool/release_preflight.ps1`, dan dokumen kontrak ini harus diperbarui dengan sengaja sebagai satu keputusan baru.
