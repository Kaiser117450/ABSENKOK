# Stack Research

**Domain:** Flutter Android release hardening for an internally distributed kiosk app
**Researched:** 2026-03-23
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter SDK | 3.41.1 stable | Primary build entry point for `appbundle`, `apk`, obfuscation, and symbolize flows | This is already the repo-local and global SDK in use, so the milestone should harden around the current proven baseline instead of mixing hardening with a framework migration. |
| Dart SDK | 3.11.0 | Compiler/runtime behind Flutter release builds | Comes with Flutter 3.41.1 and should stay pinned through the milestone so release failures are attributable to repo changes, not SDK churn. |
| Android Gradle Plugin | 8.11.1 | Android build DSL for signing, shrink, resources, and packaging | Already configured in `android/settings.gradle.kts`; modern enough for current release work without introducing migration risk. |
| Gradle Wrapper | 8.14 | Reproducible Gradle runtime for every machine and CI host | The wrapper is already checked in, which makes it the correct place to lock build behavior instead of relying on whatever Gradle a machine happens to have. |
| Gradle Daemon JVM | Java 21 (Android Studio JBR) | Known-good JVM for running Gradle and AGP | Local project state and `android/local.properties` already point to Android Studio JBR, while the shell currently resolves to Temurin 25. That mismatch needs to become explicit and versioned. |

### Supporting Libraries

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `keytool` | JDK-provided | Generate the upload keystore | Use once to create or rotate the private upload key for release signing. |
| `key.properties` | project-local secret file | Private indirection between Gradle and the upload keystore | Use for release signing values; keep it out of source control. |
| R8 | Built into Android release builds | Shrink code/resources for release artifacts | Keep enabled, but only after the release build compiles cleanly and the shrunken artifact is smoke-tested. |
| `flutter symbolize` + `--split-debug-info` | Flutter CLI feature | Preserve readable crash diagnostics after obfuscation | Use whenever Dart obfuscation is enabled for release packaging. |
| `flutter build appbundle` | Flutter CLI feature | Produce the canonical Play-distribution artifact | Use as the primary release artifact once the pipeline is healthy. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `flutter analyze` | Fast-fail static validation before packaging | Should run before release packaging so compile drift is caught early. |
| `flutter test` | Regression gate before release | The release workflow should fail before signing if tests fail. |
| `flutter doctor -v` | Environment diagnosis | Useful for verifying the effective Java binary and Flutter SDK path. |
| `gradlew updateDaemonJvm` | Check in supported Gradle daemon JVM criteria | Recommended once the team commits to Java 21 as the build baseline. |

## Installation

```powershell
# Verify repo-local SDK baseline
& 'C:\Users\HYPE R Series\Desktop\projekan\absensi apk\flutter\bin\flutter.bat' --version

# Fail fast before packaging
flutter analyze
flutter test

# Canonical release artifact
flutter build appbundle --release

# Operator APK when side-loading is still needed
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Check in a daemon JVM contract for Java 21 | Rely on per-machine `JAVA_HOME` and shell Java | Only acceptable if one trusted machine is the only build host; not acceptable once releases can be cut from multiple machines or CI. |
| `flutter build appbundle` as the canonical release output | APK-only release flow | Acceptable only for direct outlet side-loads with no Play/Internal App Sharing path. Even then, keep AAB support available for future distribution. |
| Local scripted release lane first | Immediate cloud CI release automation | Use CI only after a local clean-checkout release path is stable and secrets handling is proven. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Release builds signed with the debug keystore | Debug signing is not a safe or supportable distribution contract | Private upload keystore referenced through `android/key.properties` |
| `--android-skip-build-dependency-validation` as the normal release path | It hides real toolchain drift instead of fixing it | Codify the supported Java/Kotlin/Gradle baseline and fix the actual incompatibility or compile issue |
| Unversioned shell `JAVA_HOME` assumptions | The current shell resolves to Java 25, which is not the repo's proven-good setup | Checked-in daemon JVM criteria or explicit release script that pins Android Studio JBR |
| Manual version bumps that drift from milestone docs | The repo is already at v6.3 in planning while `pubspec.yaml` still says `6.2.0+8012` | One release contract that updates milestone version, build number, and artifact name together |

## Stack Patterns by Variant

**If the artifact is for Play or Internal App Sharing:**
- Use `flutter build appbundle --release`
- Because Flutter and Android docs both treat the signed bundle as the main distribution artifact

**If the artifact is for manual outlet tablet installation:**
- Use a signed release APK from the same validated config
- Because operators may still need a side-loadable binary, but it should come from the exact same release baseline

**If Dart obfuscation is enabled:**
- Use `--split-debug-info` and retain the symbol directory per version
- Because obfuscation without symbols turns post-release crash analysis into guesswork

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Flutter 3.41.1 | Dart 3.11.0 | Current repo-local baseline; keep fixed through v7.0 hardening. |
| AGP 8.11.1 | Gradle 8.14 | Already paired in checked-in Gradle files; preserve this pair unless a blocker proves otherwise. |
| Java 21 daemon | Java 17 `sourceCompatibility` / `jvmTarget` | Running Gradle on 21 while compiling app code for 17 is a valid split; codify it explicitly. |
| Kotlin 1.9.25 | Flutter 3.41.1 with warning | Current builds warn that future Flutter support expects Kotlin 2.1.0+, but repo constraints around `nfc_manager` mean this should be treated as an explicit compatibility risk, not an ad hoc upgrade. |

## Sources

- Local repo: `android/settings.gradle.kts` — AGP 8.11.1 and Kotlin 1.9.25
- Local repo: `android/gradle/wrapper/gradle-wrapper.properties` — Gradle 8.14 wrapper
- Local repo: `android/local.properties` — current Java home points to Android Studio JBR
- Local repo: `android/app/build.gradle.kts` — release signing still uses `debug`
- Local repo: `build.log` and `flutter_build.log` — current release failures and Kotlin validation warning
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android) — signing, `key.properties`, Gradle release config, AAB/APK release flow
- [Flutter: Continuous delivery with Flutter](https://docs.flutter.dev/deployment/cd) — local-first release automation guidance and `flutter build appbundle`
- [Android Developers: Configure your build](https://developer.android.com/build) — release signing expectations, wrapper consistency, AAB recommendation
- [Gradle: Gradle Daemon](https://docs.gradle.org/current/userguide/gradle_daemon.html) — checked-in daemon JVM criteria and JVM precedence rules

---
*Stack research for: Flutter Android release hardening*
*Researched: 2026-03-23*
