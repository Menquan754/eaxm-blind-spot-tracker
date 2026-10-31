# Zhizong · HarmonyOS PC Learning Blind-Spot Tracker

<p align="left">
  <img src="app_icon.png" width="96" alt="Zhizong app icon" />
</p>

**Zhizong (知踪)** is a native HarmonyOS PC (2in1) application for university students. It records
wrong answers, evaluates weak knowledge points, builds Ebbinghaus review plans, and generates
practice exams from a built-in course library.

English description: *HarmonyOS PC app for tracking learning blind spots with knowledge cards and review plans.*

## Features

- **Subjects & knowledge points** — built-in university courses (Calculus, Linear Algebra,
  Probability, Physics, C Programming, Data Structures), with custom subjects and knowledge
  points.
- **Knowledge cards** — key concepts, formulas and common-mistake tips generated from each
  knowledge point, with a one-click jump from a knowledge point to its questions.
- **Question bank & practice** — multiple-choice and true/false questions, instant grading,
  explanations, and keyword search.
- **Mock exams** — custom duration, countdown, auto-submit, no answer peeking during the exam,
  and full-paper analysis afterwards.
- **Weakness analysis** — per-knowledge-point scoring and trend charts drawn with Canvas.
- **Review plans** — monthly calendar, freely scheduled review tasks, Ebbinghaus stages,
  postpone/complete actions.
- **PC-first UX** — three-column adaptive layout, window size limits, keyboard/mouse support,
  light/dark theme following the system.
- **Offline first** — all data is stored locally with `relationalStore`; no network permission
  required.

## Tech Stack

| Item | Value |
| --- | --- |
| Language | ArkTS (strict mode) |
| UI framework | ArkUI, declarative components |
| App model | Stage model |
| Database | `@ohos.data.relationalStore` (SQLite) |
| Charts | Canvas (no third-party chart library) |
| Tests | Hypium (`@ohos/hypium`), Hamock |
| Build | Hvigor |

## Requirements

| Item | Requirement |
| --- | --- |
| DevEco Studio | 6.0 or newer (tested with DevEco Studio 6.x) |
| HarmonyOS SDK | API 24 — compatible SDK **6.1.1(24)** |
| Target SDK | 26.0.0 (configured in `build-profile.json5`) |
| Device | 2in1 PC / tablet emulator or phone (module supports `2in1` and `phone`) |
| Account | A Huawei ID is required **only** to generate a local signing certificate |

## How to Run

HarmonyOS apps are signed before they can be installed, so a cloned project cannot be launched
by double-clicking. This repository intentionally contains **no signing keys, certificates or
passwords**. Follow these steps:

1. **Clone the repository**

   ```bash
   git clone https://github.com/Menquan754/eaxm-blind-spot-tracker.git
   cd eaxm-blind-spot-tracker
   ```

2. **Install the SDK** — open DevEco Studio → *Settings → SDK Manager*, and install
   **HarmonyOS SDK API 24 (6.1.1)**. The project uses Stage model and ArkTS.

3. **Import the project** — in DevEco Studio choose *File → Open*, then select the **repository
   root folder** (the folder that contains `build-profile.json5` and `entry/`). Do not open only
   the `entry` module.

4. **Sync dependencies** — wait for the automatic Hvigor sync. If it does not start, run:

   ```bash
   ohpm install
   ```

   Then use *File → Sync Project with Hvigor* (or the Sync button in the toolbar).

5. **Configure your own signing (required)** —
   *File → Project Structure → Signing Configs*:
   - Tick **Automatically generate signature**.
   - Sign in with your Huawei ID when prompted.
   - Click **Apply / OK**.

   DevEco Studio will generate a local key/certificate and write your signing information into
   your **local copy** of `build-profile.json5`. Those values are personal secrets: do **not**
   commit them. The repository ships `signingConfigs` empty on purpose.

6. **Select a device** — start a **2in1 (PC) emulator** or connect a HarmonyOS PC/phone, then
   select the `entry` module and click **Run**.

7. **First launch** — the app creates its local database and seeds the built-in course library
   automatically. No manual database setup is needed.

> **Troubleshooting**
> - `Failed to install HAP` → signing is missing or expired; redo step 5.
> - Dependency errors → delete `oh_modules/` and run `ohpm install` again.
> - If DevEco Studio rewrites `build-profile.json5` with your passwords, never push that file
>   change; `.gitignore` already excludes certificates, keystores and `local.properties`.

### Build and test from the command line

```bash
# Build a debug HAP (signing config must exist in your local build-profile.json5)
hvigorw assembleHap --mode module -p product=default -p buildMode=debug

# Run unit tests (Hypium)
hvigorw test
```

## Project Structure

```text
.
├── AppScope/                     # App-level config, name, icon, resources
├── entry/                        # Entry module
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/     # UIAbility lifecycle, window & theme
│       │   ├── pages/            # home, knowledge, practice, review, trend, wrongbook, settings
│       │   ├── components/       # Shared UI components
│       │   ├── service/          # Weakness, practice, review, seed services
│       │   ├── database/         # relationalStore access layer
│       │   ├── model/            # Entities
│       │   └── common/           # Theme, utilities
│       ├── resources/            # Strings, colors, media
│       └── module.json5          # Module config (2in1 / phone)
│   └── src/test/                 # Hypium unit tests
├── docs/                         # License scan report
├── build-profile.json5           # Build config (signingConfigs intentionally empty)
├── oh-package.json5              # Dependencies
└── LICENSE                       # Apache License 2.0
```

## License

This project is licensed under the **Apache License 2.0** — see [LICENSE](LICENSE).

A third-party license scan was performed with ScanCode Toolkit; the full report is available at
[docs/license-scan-report.md](docs/license-scan-report.md). Summary: no third-party source code
or license headers were detected in the repository; the only detected license is the project's
own Apache-2.0 `LICENSE`.

## Source File Header Convention

Every `.ets` / `.ts` file should start with a short English header:

```ts
/**
 * @file KnowledgePage.ets
 * @brief Manages subjects, knowledge points, cards and questions with jump support.
 * @author Menquan754
 */
```

Utility / service example:

```ts
/**
 * @file Utils.ets
 * @brief Provides shared date, text and formatting helpers for all pages.
 * @author Menquan754
 */
```

Rules:

- `@file` — file name, including extension.
- `@brief` — one sentence, **English only**, **15 words or fewer**.
- `@author` — GitHub handle or full name.

## Author

Menquan754 — <https://github.com/Menquan754>
