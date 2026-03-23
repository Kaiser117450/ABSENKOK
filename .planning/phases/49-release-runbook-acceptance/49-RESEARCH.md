# Phase 49: Release Runbook & Acceptance - Research

**Researched:** 2026-03-23
**Domain:** Windows PowerShell-backed Android release operations
**Confidence:** MEDIUM

## Summary

Phase 49 is not a product-implementation phase. It is an operator-proof phase: the work is to turn the already-established APK-first release contract into a runbook that a second operator can follow without hidden tribal knowledge. The only safe planning target is the live command surface that already exists in `tool/release_env.ps1`, `tool/release_preflight.ps1`, and `tool/release_build.ps1`.

The release path is now explicit enough to document as a reproducible sequence: verify the Java 21 JBR / Flutter baseline, run the preflight lane, build the canonical signed APK, optionally retain a bundle, preserve split debug info and mapping output, and record smoke evidence in the same staged release directory. Phase 49 should not invent a new release workflow; it should document the exact one already encoded in the helper scripts and then prove it works for another operator.

**Primary recommendation:** Plan Phase 49 around one documented local release lane plus one evidence run that reproduces the canonical APK-first artifact set and records acceptance beside it.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-01 | A second operator can reproduce the expected APK-first release artifact set from the documented local runbook without guessing secret/bootstrap prerequisites. | `tool/release_env.ps1` defines the supported Java 21 JBR and Flutter baseline; `tool/release_preflight.ps1` defines the fail-fast gate; `tool/release_build.ps1` defines the canonical APK-first artifact flow, release manifest, and smoke evidence contract; `android/key.properties.example` defines the secret bootstrap placeholders. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PowerShell | `powershell.exe` / 5.1-compatible surface | Operator shell for release commands | The tracked release instructions are explicitly written for Windows PowerShell, not `pwsh` only. |
| Flutter SDK | 3.41.1 | Build the Android app | The repo contract pins this version and treats it as the canonical CLI. |
| Android Gradle Plugin | 8.11.1 | Android build integration | The release helper and contract both enforce this pin. |
| Gradle wrapper | 8.14 | Android build orchestration | The preflight script asserts the wrapper pin before packaging. |
| Kotlin Android plugin | 1.9.25 | Android module compilation | This is the pinned compatibility line for v7.0. |
| Java runtime | Java 21 JBR | Gradle runtime | `tool/release_env.ps1` resolves and validates this explicitly. |
| adb / platform-tools | Android SDK platform-tools | Device smoke install and launch | Smoke verification needs `adb devices`, install, and launch commands. |
| Git | current repo checkout | Capture revision and dirty state in release manifest | `tool/release_build.ps1` records git metadata into the manifest when available. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `tool/release_env.ps1` | repo script | Resolves Java 21 JBR and canonical Flutter CLI | Always first in the documented release lane. |
| `tool/release_preflight.ps1` | repo script | Fails fast on analyze/test/release-compile drift | Always before any packaging or signing. |
| `tool/release_build.ps1` | repo script | Stages the canonical APK-first release artifact set | Always for check-only, build, and smoke runs. |
| `android/key.properties.example` | repo placeholder | Documents upload-keystore bootstrap keys | Use as the secret schema reference for operators. |
| `docs/android-release-contract.md` | repo doc | The tracked operator contract for v7.0 release behavior | Use as the canonical written contract that Phase 49 must not contradict. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Windows PowerShell helper lane | Ad hoc manual Flutter/Gradle commands | More drift, weaker reproducibility, and less truthful smoke evidence. |
| APK-first canonical artifact | AAB-first retention by default | Contradicts the current shipped-product contract and Phase 48.1 alignment. |
| Manual adb steps scattered in the runbook | `tool/release_build.ps1 -SmokeVerify` | Hand-rolled device steps are more fragile and harder to keep aligned with manifest evidence. |

**Installation:**
```bash
n/a
```

## Architecture Patterns

### Recommended Project Structure
```text
tool/
├── release_env.ps1          # environment contract and Java/Flutter bootstrap
├── release_preflight.ps1    # fail-fast analyze/test/compile gate
└── release_build.ps1        # packaging, staging, manifest, smoke evidence

docs/
└── android-release-contract.md

android/
└── key.properties.example   # private signing schema placeholder
```

### Pattern 1: Contract-First Release Lane
**What:** The release flow is encoded as helper scripts plus a contract doc, not as tribal knowledge in a README.
**When to use:** Any time an operator must reproduce a release lane on a fresh machine.
**Example:**
```powershell
powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly
powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly
```

### Pattern 2: Canonical Artifact + Co-Located Evidence
**What:** The signed APK, symbols, mapping, manifest, and smoke evidence all live under one versioned release directory.
**When to use:** Any acceptance workflow that needs proof the release is reproducible.
**Example:**
```powershell
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify
```

### Pattern 3: Secret Bootstrap via Placeholder Schema
**What:** The repo tracks the required signing keys as placeholders, not real secrets.
**When to use:** When documenting what the operator must prepare before building.
**Example:**
```text
storePassword=REPLACE_WITH_UPLOAD_KEYSTORE_PASSWORD
keyPassword=REPLACE_WITH_UPLOAD_KEY_PASSWORD
keyAlias=REPLACE_WITH_UPLOAD_KEY_ALIAS
storeFile=REPLACE_WITH_PRIVATE_UPLOAD_KEYSTORE_FILE
```

### Anti-Patterns to Avoid
- **Hand-written release steps in the runbook:** the helper scripts already define the source of truth.
- **PowerShell 7-only wording:** the documented lane must remain truthful for `powershell.exe` 5.1 compatibility.
- **AAB-first defaults:** the canonical retained artifact is the signed APK.
- **Secret values in repo docs:** only placeholders belong in planning/runbook docs.
- **Device smoke steps detached from the release directory:** evidence must sit beside the staged artifact set.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Environment discovery | Ad hoc checks for Java/Flutter | `tool/release_env.ps1` | It already enforces Java 21 JBR and the canonical Flutter CLI. |
| Preflight gating | Manual “looks good” checks | `tool/release_preflight.ps1` | It fails before packaging if analyze, tests, or compile are red. |
| Manifest assembly | Custom JSON generation in the runbook | `tool/release_build.ps1` | It already stages `release-manifest.json` with canonical artifact metadata. |
| Smoke install/launch | Manual adb command list | `tool/release_build.ps1 -SmokeVerify` | It already writes `smoke-check.txt` and binds evidence to the same release record. |
| Secret schema guessing | Inventing keystore fields | `android/key.properties.example` | It defines the exact placeholder names to document. |

**Key insight:** Phase 49 should document the release helper surface, not recreate it. The more the runbook copies the helper logic verbatim, the more likely it is to drift from the actual operator contract.

## Common Pitfalls

### Pitfall 1: PATH Java Drift
**What goes wrong:** The machine has a different `java.exe` on PATH than the one the release contract expects.
**Why it happens:** Operator machines often have multiple JDK installs.
**How to avoid:** Require `tool/release_env.ps1`, which resolves `ABSENKOK_JAVA_HOME` first and otherwise falls back to Android Studio JBR.
**Warning signs:** Gradle launches but the version line is not Java 21 JBR.

### Pitfall 2: Secret Bootstrap Omission
**What goes wrong:** The runbook mentions signing but not the required `key.properties` setup.
**Why it happens:** The private upload keystore cannot be inferred from the repo.
**How to avoid:** Document the placeholder schema from `android/key.properties.example` and state clearly that the real file stays private and machine-local.
**Warning signs:** `bundleRelease` or `assembleRelease` fails because signing properties are missing.

### Pitfall 3: pwsh / powershell Mismatch
**What goes wrong:** The runbook is written for `pwsh` only and no longer matches the tested operator lane.
**Why it happens:** The helper has a PowerShell 5.1-compatible contract and the docs need to match it.
**How to avoid:** Name `powershell.exe` explicitly in the runbook and keep the command examples aligned with the tracked contract.
**Warning signs:** Operators can run the doc only after modifying shell syntax.

### Pitfall 4: Evidence Split Across Locations
**What goes wrong:** APK, manifest, symbols, mapping, and smoke evidence are written into different directories.
**Why it happens:** Ad hoc release scripts often scatter outputs by tool default.
**How to avoid:** Treat the versioned `build/releases/android/ABSENKOK-v<versionName>+<versionCode>/` directory as the single release record.
**Warning signs:** Acceptance evidence cannot be reviewed from one directory tree.

### Pitfall 5: Smoke Verification Without Device Context
**What goes wrong:** The runbook promises smoke verification without an attached device or emulator.
**Why it happens:** Device availability is easy to gloss over in docs.
**How to avoid:** State that `-SmokeVerify` requires `adb devices` to see at least one attached Android target.
**Warning signs:** `adb devices` is empty and the smoke lane fails with no-device status.

## Code Examples

Verified patterns from local source:

### Release Environment Check
```powershell
# Source: [tool/release_env.ps1](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/tool/release_env.ps1)
powershell -ExecutionPolicy Bypass -File tool/release_env.ps1 -CheckOnly
```

### Release Preflight
```powershell
# Source: [tool/release_preflight.ps1](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/tool/release_preflight.ps1)
powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1
```

### APK-First Build and Smoke Verification
```powershell
# Source: [tool/release_build.ps1](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/tool/release_build.ps1)
powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual release commands scattered across notes | Helper scripts plus tracked contract doc | Phase 47-48.1 | Operator instructions are now reproducible and fail-fast. |
| AAB-first retained artifact contract | APK-first retained artifact contract | Phase 48.1 | Phase 49 can document one shipped-product path instead of two competing ones. |
| Smoke evidence separate from artifact retention | Smoke evidence stored beside the canonical APK record | Phase 48.1 | Acceptance can prove one release directory is self-contained. |

**Deprecated/outdated:**
- `android/local.properties` as a shared source of truth: it remains machine-local evidence only, not the contract itself.
- `pwsh`-only documentation: the supported release lane is still written against `powershell.exe` compatibility.
- Debug-keystore release signing: replaced by private upload-keystore signing.

## Open Questions

1. **What exact secret/bootstrap wording should the runbook use?**
   - What we know: the placeholder schema is fixed in `android/key.properties.example`.
   - What's unclear: how verbose Phase 49 should be about file placement versus just naming the required fields.
   - Recommendation: document the fields and a minimal example path, but keep the actual secret values and keystore file private.

2. **Should acceptance include `-IncludeAppBundle` or only the default APK-first lane?**
   - What we know: the canonical retained artifact is the APK and bundle retention is optional.
   - What's unclear: whether Phase 49 should prove the optional bundle path as part of the acceptance evidence.
   - Recommendation: make the default acceptance prove the APK-first lane, then note the bundle path as optional and not required unless the operator contract explicitly asks for it.

3. **How much device detail belongs in the runbook?**
   - What we know: `-SmokeVerify` requires adb-visible hardware or emulator.
   - What's unclear: whether to document one device naming convention or keep it device-agnostic.
   - Recommendation: keep the runbook device-agnostic and require only that `adb devices` shows a target.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | PowerShell release scripts + existing Flutter test suite |
| Config file | `tool/release_env.ps1`, `tool/release_preflight.ps1`, `tool/release_build.ps1` |
| Quick run command | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly` |
| Full suite command | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPS-01 | A second operator can reproduce the APK-first release artifact set without guessing bootstrap prerequisites | acceptance / operator repro | `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -SmokeVerify` | ✅ `tool/release_build.ps1`, `tool/release_env.ps1`, `tool/release_preflight.ps1` |

### Sampling Rate
- **Per task commit:** `powershell -ExecutionPolicy Bypass -File tool/release_build.ps1 -CheckOnly`
- **Per wave merge:** `powershell -ExecutionPolicy Bypass -File tool/release_preflight.ps1`
- **Phase gate:** Full repro lane with `-SmokeVerify` and artifact inspection before Phase 49 is marked complete

### Wave 0 Gaps
- None for planning: the release helpers, contract doc, and placeholder signing schema already exist.
- Acceptance still requires an attached Android target for smoke verification, but that is an operator/runtime dependency, not a missing repo artifact.

## Sources

### Primary (HIGH confidence)
- [docs/android-release-contract.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/docs/android-release-contract.md) - supported toolchain, release preflight, artifact contract, and v7.0 compatibility line
- [tool/release_env.ps1](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/tool/release_env.ps1) - Java 21 JBR and canonical Flutter bootstrap
- [tool/release_preflight.ps1](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/tool/release_preflight.ps1) - fail-fast preflight order and contract assertions
- [tool/release_build.ps1](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/tool/release_build.ps1) - canonical artifact staging, manifest, symbols, mapping, and smoke evidence
- [android/key.properties.example](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/android/key.properties.example) - private signing placeholder schema
- [48.1-01 summary](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/48.1-apk-first-release-artifact-alignment/48.1-01-SUMMARY.md) - APK-first contract and optional bundle retention
- [48.1-02 summary](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/phases/48.1-apk-first-release-artifact-alignment/48.1-02-SUMMARY.md) - PowerShell 5.1 smoke evidence alignment
- [.planning/REQUIREMENTS.md](C:/Users/HYPE%20R%20Series/Desktop/projekan/absensi%20apk/absensi_enakko_flutter/.planning/REQUIREMENTS.md) - OPS-01 requirement traceability

### Secondary (MEDIUM confidence)
- None required; local repo sources were sufficient for planning research.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - directly stated in tracked release helper scripts and contract doc.
- Architecture: HIGH - release flow is explicitly encoded in helper scripts and phase 48.1 summaries.
- Pitfalls: MEDIUM - the pitfalls are strongly implied by the scripts and contract, but the operator side still needs real acceptance execution.

**Research date:** 2026-03-23
**Valid until:** 2026-04-22
