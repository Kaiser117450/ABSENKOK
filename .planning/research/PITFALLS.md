# Pitfalls Research

**Domain:** Flutter Android release hardening
**Researched:** 2026-03-23
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Chasing toolchain warnings before fixing the actual compile blockers

**What goes wrong:**
The team upgrades Kotlin, Java, or Flutter first while the release still fails because app code does not compile.

**Why it happens:**
Toolchain warnings are loud and look more "infrastructure-like" than the underlying Dart failures.

**How to avoid:**
Fail fast on analyze/test/release compile checks, fix the concrete source errors first, then address structural toolchain risks.

**Warning signs:**
Release discussions focus on Kotlin 2.x before the current `flutter build` errors in `shift_scheduler_screen.dart` and `schedule_sqlite_service.dart` are closed.

**Phase to address:**
Phase 46

---

### Pitfall 2: Shipping a release signed with the debug keystore

**What goes wrong:**
Artifacts are distributed with debug signing because `release` still points to the debug config.

**Why it happens:**
The template TODO is easy to leave in place and still allows `flutter run --release` to work locally.

**How to avoid:**
Move to an upload-keystore flow through `android/key.properties` and treat the absence of release signing as a blocker, not a convenience.

**Warning signs:**
`android/app/build.gradle.kts` still references `signingConfigs.getByName("debug")` inside `release`.

**Phase to address:**
Phase 48

---

### Pitfall 3: Java runtime drift across machines

**What goes wrong:**
One machine uses Android Studio JBR, another uses shell Java 25, and releases fail or behave differently depending on PATH order.

**Why it happens:**
`local.properties` captures one local path but the repo does not yet express the long-term build JVM contract.

**How to avoid:**
Check in daemon JVM criteria or make the release script set the known-good Java runtime explicitly.

**Warning signs:**
`java -version` differs from the Java path used by successful releases, or operators need tribal knowledge to know which JDK to use.

**Phase to address:**
Phase 47

---

### Pitfall 4: Version drift between planning, pubspec, and artifacts

**What goes wrong:**
Planning says the project shipped v6.3, but `pubspec.yaml` and output artifact names still identify a previous release.

**Why it happens:**
Version updates are handled manually and not treated as part of the release contract.

**How to avoid:**
Make version metadata part of the hardening milestone and validate artifact names against the milestone version before distribution.

**Warning signs:**
Release artifact names or app metadata mention `6.2.0` while the active milestone is v7.0.

**Phase to address:**
Phase 46

---

### Pitfall 5: Obfuscation without retained symbols

**What goes wrong:**
A shrunken or obfuscated release ships, but later crash stacks cannot be symbolized.

**Why it happens:**
Teams enable `--obfuscate` or rely on shrink tools without a versioned storage location for debug artifacts.

**How to avoid:**
Retain `--split-debug-info` output per version and document it as a required release artifact alongside the APK/AAB.

**Warning signs:**
Release scripts mention obfuscation, but there is no stable `build/debug-info/<version>/` retention rule.

**Phase to address:**
Phase 48

---

### Pitfall 6: Secret leakage through committed keystore material

**What goes wrong:**
The keystore or `key.properties` ends up in git, shared folders, or copied into scripts.

**Why it happens:**
The team wants a "working release fast" and shortcuts private secret handling.

**How to avoid:**
Keep the keystore and key properties private, gitignored, and documented only through placeholder/bootstrap instructions.

**Warning signs:**
Passwords appear in Gradle files, batch scripts, or README snippets.

**Phase to address:**
Phase 48

---

### Pitfall 7: Automating a release flow that is not yet deterministic locally

**What goes wrong:**
CI/CD is added, but failures remain opaque because the local release lane was never stabilized first.

**Why it happens:**
Automation feels like the fix, but it only amplifies local ambiguity.

**How to avoid:**
Finish the local release runbook and acceptance verification before introducing CI secrets and runners.

**Warning signs:**
The team cannot state one exact local command sequence that reliably produces the intended artifact set.

**Phase to address:**
Phase 49

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep debug signing for release | No secret setup today | Unsafe and ambiguous release provenance | Never for a distributed release |
| Bypass dependency validation flags | Build may proceed once | Toolchain drift stays hidden and will resurface later | Only for short-lived local diagnosis, never for the canonical release lane |
| Manually remember the correct Java path | No repo changes | Future operators and CI cannot reproduce the release | Never once more than one machine can ship |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Flutter CLI + Gradle | Assume shell Java is what Gradle should use | Pin the supported Gradle JVM explicitly |
| Release signing + Gradle | Hardcode passwords or paths in build files | Load private values from `android/key.properties` |
| Planning docs + version metadata | Treat milestone naming as separate from app version | Update milestone docs and `pubspec.yaml` together |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Running full packaging to discover basic code errors | 30-60 second failures before obvious compile issues surface | Add preflight analyze/test/compile gates | Immediately on every broken release attempt |
| Enabling shrink/obfuscation without verification | Release artifact builds, but runtime behavior or diagnostics degrade | Smoke-test the shrunken artifact and retain symbol output | As soon as a release-only issue appears |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing keystore files or `key.properties` | Credential leakage and permanent key rotation pain | Keep them private and out of VCS |
| Shipping debug-signed artifacts | Invalid production trust model | Require upload-key signing for release |
| Reusing one operator's local secrets without documentation | Single point of failure | Document the bootstrap contract without exposing secrets |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Artifact names do not match the milestone | Operators install the wrong build or cannot trace the shipped binary | Encode milestone version consistently in app metadata and output files |
| Release flow depends on tribal knowledge | Only one person can ship confidently | Turn the release flow into a short, deterministic runbook or script |

## "Looks Done But Isn't" Checklist

- [ ] **Release compile:** The repo passes the chosen preflight gates before signing starts.
- [ ] **Toolchain:** The supported Java/Flutter/Gradle contract is explicit, not implied by one developer machine.
- [ ] **Signing:** `release` no longer references the debug signing config.
- [ ] **Artifacts:** AAB/APK names and retained symbols match the active milestone version.
- [ ] **Operations:** Another operator could follow the documented steps without guessing hidden prerequisites.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Debug-signed release | HIGH | Generate or rotate the upload keystore, reconfigure signing, rebuild, and redistribute the corrected artifact |
| Java drift | MEDIUM | Pin the known-good JVM, document it, and rerun the release from a clean checkout |
| Version drift | MEDIUM | Align `pubspec.yaml`, planning docs, and artifact naming in one change set, then rebuild |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Compile blockers hidden by packaging | Phase 46 | Release preflight catches and closes code errors before packaging |
| Java runtime drift | Phase 47 | The supported JVM is explicit and reproducible on another machine |
| Debug signing | Phase 48 | `release` uses upload-key signing from private config |
| Missing symbols | Phase 48 | The release lane stores split debug info by version |
| Premature automation | Phase 49 | The local release runbook works end-to-end before CI is introduced |

## Sources

- Local repo: `android/app/build.gradle.kts`
- Local repo: `android/local.properties`
- Local repo: `build.log`
- Local repo: `flutter_build.log`
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Flutter: Continuous delivery with Flutter](https://docs.flutter.dev/deployment/cd)
- [Gradle: Gradle Daemon](https://docs.gradle.org/current/userguide/gradle_daemon.html)

---
*Pitfalls research for: Flutter Android release hardening*
*Researched: 2026-03-23*
