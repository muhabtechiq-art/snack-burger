# Windows Runbook: EGL Context Lost

## Symptom
- Repeated logs:
  - `EGL Error: Context Lost (12302)`
  - `Could not make the context current`

## Immediate Recovery (Support Team)
1. Stop running app.
2. Run:
   - `flutter clean`
   - `flutter run -d windows`
3. If still failing, run with software rendering:
   - `flutter run -d windows --enable-software-rendering`

## Root-Cause Checklist
- Intel/NVIDIA/AMD driver outdated.
- Sleep/wake happened during active debug session.
- External display was attached/detached.
- RDP session attached/detached.

## Permanent Mitigation
- Update GPU driver to latest stable version.
- Reboot device after driver update.
- Avoid long debug sessions across sleep/wake cycles.
- If field device is unstable, use software rendering profile temporarily.

## Escalation Data
- Device model + GPU model.
- Driver version.
- Last 200 terminal lines around EGL errors.
- Whether issue reproduces with software rendering.
