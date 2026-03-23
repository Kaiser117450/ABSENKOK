# Android Local Release Runbook

Runbook ini adalah panduan operator untuk memproduksi release Android lokal v7.0 dengan lane APK-first yang ditrack di repository. Gunakan dokumen ini bersama [android-release-contract.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/docs/android-release-contract.md). Jangan membuat helper baru, jangan mem-bypass preflight, dan jangan memindahkan flow ini ke `pwsh`-only syntax.

## Scope

- Target release: `ABSENKOK-v7.0.0+8013`
- Shell yang didukung: `powershell.exe` / Windows PowerShell 5.1
- Canonical artifact: signed optimized `.apk`
- Optional artifact: `.aab` hanya jika operator memang meminta `-IncludeAppBundle`
- Smoke evidence wajib berasal dari lane yang sama dengan canonical APK

## Prerequisites

### 1. Gunakan shell yang benar

Semua command di bawah dijalankan dari root repository ini lewat `powershell.exe`, bukan shell lain:

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly
```

### 2. Siapkan bootstrap signing secara lokal

Repository hanya menyimpan schema placeholder di `android/key.properties.example`. File nyata `android/key.properties` dan upload keystore harus tetap private dan untracked.

Salin placeholder ini ke file lokal `android/key.properties`:

```text
storePassword=REPLACE_WITH_UPLOAD_KEYSTORE_PASSWORD
keyPassword=REPLACE_WITH_UPLOAD_KEY_PASSWORD
keyAlias=REPLACE_WITH_UPLOAD_KEY_ALIAS
storeFile=REPLACE_WITH_PRIVATE_UPLOAD_KEYSTORE_FILE
```

Contoh bentuk `storeFile` yang valid secara lokal:

```text
storeFile=C:\private\android\absenkok-upload-key.jks
```

Checklist bootstrap:

- `android/key.properties` ada secara lokal dan tidak masuk git
- path pada `storeFile` menunjuk ke upload keystore yang benar
- keystore dapat dibaca oleh user Windows yang menjalankan release

### 3. Pastikan smoke target tersedia

Smoke verification butuh Android device atau emulator yang terlihat oleh `adb devices`.

```powershell
adb devices
```

Lanjut hanya jika ada minimal satu target dengan state `device`.

## Release Record Yang Diharapkan

Successful run harus menghasilkan satu release record di:

```text
build/releases/android/ABSENKOK-v7.0.0+8013/
```

Isi minimum yang diharapkan:

- `ABSENKOK-v7.0.0+8013.apk`
- `release-manifest.json`
- `smoke-check.txt`
- `symbols/`
- `mapping.txt` bila dihasilkan shrinker

Optional only:

- `ABSENKOK-v7.0.0+8013.aab` bila operator menjalankan lane dengan `-IncludeAppBundle`

## Exact Command Order

### Step 1. Verify environment contract

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly
```

Stop jika Java 21 JBR atau canonical Flutter CLI tidak match.

### Step 2. Run fail-fast preflight

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1
```

Stop jika analyze, test, atau `:app:compileReleaseSources` gagal. Jangan gunakan bypass flag.

### Step 3. Inspect the packaging contract without cutting artifacts

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly
```

Untuk memastikan smoke contract dan jalur `adb` juga terbaca dengan benar sebelum build nyata:

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly -SmokeVerify
```

Command ini tidak menggantikan release nyata. Fungsinya hanya mengonfirmasi release label, canonical APK path, optional bundle path, dan smoke evidence target.

Pada baseline v7.0 saat ini, check-only smoke lane juga harus memperlihatkan:

- `Bundle retention: omitted` pada default APK-first lane
- `App package: com.enakko.absensi_enakko_flutter`
- path `adb.exe` yang akan dipakai untuk smoke verification

### Step 4. Cut the canonical APK-first release and smoke-verify it

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify
```

Command ini harus:

1. masuk lewat `tool/release_env.ps1`
2. menjalankan `tool/release_preflight.ps1`
3. build signed `.apk` dengan `--split-debug-info`
4. stage release record ke `build/releases/android/ABSENKOK-v7.0.0+8013/`
5. install canonical APK ke device/emulator
6. launch app
7. tulis `smoke-check.txt`

Kalau run ini sukses, `release-manifest.json` harus tetap menyatakan canonical artifact sebagai `.apk` dan `BundleRetentionState` harus tetap `omitted` kecuali operator sengaja memakai `-IncludeAppBundle`.

### Step 5. Optional bundle retention

Jalankan ini hanya jika operator memang butuh `.aab` selain canonical APK:

```powershell
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify -IncludeAppBundle
```

`-IncludeAppBundle` tidak mengubah canonical artifact. Canonical artifact tetap `.apk`.

## Acceptance Checklist

Release lokal siap ditinjau hanya jika semua poin ini benar:

- `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1` lulus tanpa bypass
- release directory `build/releases/android/ABSENKOK-v7.0.0+8013/` dibuat
- canonical APK ada di `build/releases/android/ABSENKOK-v7.0.0+8013/ABSENKOK-v7.0.0+8013.apk`
- `release-manifest.json` menunjuk canonical artifact ke `.apk`
- `smoke-check.txt` berasal dari run yang sama
- `symbols/` retained
- `mapping.txt` retained bila file itu dihasilkan
- `.aab` hanya ada bila memang diminta lewat `-IncludeAppBundle`

## If The Run Blocks

Perlakukan hal-hal di bawah ini sebagai blocker nyata, bukan alasan untuk bypass:

- `android/key.properties` belum dibuat atau salah isi
- upload keystore tidak ada / path `storeFile` salah
- `adb devices` tidak menunjukkan target
- preflight merah
- smoke verification gagal install atau launch

Kalau salah satu blocker muncul:

1. stop di step yang gagal
2. simpan output command yang gagal
3. catat blocker ke acceptance evidence phase
4. jangan distribusikan artifact parsial sebagai release valid

## Notes

- Runbook ini sengaja fokus pada local deterministic release lane.
- CI/CD, GitHub Release publishing, dan Play Store flow tetap di luar scope Phase 49.
- `docs/android-release-contract.md` tetap menjadi contract summary; runbook ini adalah operator sequence yang lebih konkret.
