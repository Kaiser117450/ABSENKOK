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
