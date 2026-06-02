# Release Gate Checklist (Stability First)

Use this checklist before handing a build to a customer.

## SLO Targets
- Order submit success >= 99.5%
- Auto reconnect success <= 10s in 95% of disconnect events
- Crash rate: no upward trend across last 7 days

## Pre-Release Checks
- [ ] `flutter analyze` passes with no errors.
- [ ] Web build and Windows debug/release build both succeed.
- [ ] Realtime dashboard reconnects automatically after network drop.
- [ ] Customer order status page reconnects automatically after app/tab wake.
- [ ] Retry button appears on forced error and works.
- [ ] Telemetry events appear in logs for disconnect/reconnect.
- [ ] Order state transitions verified end-to-end.

## Platform-Specific
- [ ] Windows: sleep/wake tested.
- [ ] Windows: display switch tested.
- [ ] Windows: RDP connect/disconnect tested (if relevant).
- [ ] Web: background tab wake behavior verified.
- [ ] Web: hard refresh does not break critical user flow.

## Regression Safety
- [ ] Admin pending orders still disappear immediately after accept.
- [ ] Notification sound behavior unchanged (once per new pending order).
- [ ] Customer can open order tracking from success snackbar.

## Go / No-Go Rule
- Go only if all P0 checks pass.
- If any P0 item fails, release is blocked until fix + retest.
