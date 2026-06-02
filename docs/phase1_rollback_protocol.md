# Phase 1 Strict Rollback Protocol

## Purpose
ضمان تراجع فوري إذا سببت مرحلة 1 أي عدم استقرار.

## Rollback Trigger (any one)
- UI stuck on reconnect unexpectedly.
- repeated uncaught runtime errors in stream lifecycle.
- order dashboard fails to reach stable live state under normal network.

## Immediate Action
1. Open `lib/core/config/stability_phase1_flags.dart`.
2. Set:
   - `enablePhase1RealtimeHardening = false`
   - (optional) keep `enablePhase1HealthSignals = false`
3. Rebuild and verify.

This forces fallback to legacy stream logic while keeping the app running.

## Re-Enable Conditions
- root cause identified and fixed
- analyze passes
- regression test for reconnect and orders dashboard passes

## Verification Checklist After Rollback
- pending orders list updates normally
- accept action removes pending order
- no repeated stream errors in terminal
