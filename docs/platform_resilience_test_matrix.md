# Platform Resilience Test Matrix

## Scope
- Platforms: Web + Windows
- Focus: realtime stability, reconnect behavior, error visibility, self-healing

## Mandatory Scenarios

| ID | Platform | Scenario | Steps | Expected Result |
|---|---|---|---|---|
| R-01 | Web | Network drop | Open orders dashboard, disable internet 30s, restore | UI shows reconnect state, then auto-recovers without refresh |
| R-02 | Web | Browser background/wake | Keep tab open, switch away 10+ min, return | Stream resumes, stale/reconnecting hint disappears after sync |
| R-03 | Web | Token/session change | Sign out/in during active stream | No crash, stream re-subscribes after auth state becomes valid |
| R-04 | Windows | Sleep/wake | Run app, put device sleep, wake | App either recovers stream or shows clear reconnect action |
| R-05 | Windows | Display change | Connect/disconnect monitor while stream active | No silent blank state; reconnect/error state is visible |
| R-06 | Windows | RDP connect/disconnect | Attach/detach RDP session | No unrecoverable crash loop; restart runbook steps documented |
| R-07 | Both | Supabase transient error | Simulate backend disconnect/timeout | Exponential backoff attempts logged, eventual recovery |
| R-08 | Both | Order status tracking | Open order status page by order id, update status server-side | Timeline updates: pending -> accepted -> delivering -> delivered |
| R-09 | Both | Retry UI | Force stream error | "Reconnect" action visible and successfully re-subscribes |
| R-10 | Both | Long run soak | Keep app running 4-8 hours | No memory leak trend, no increasing reconnect failures |

## Evidence To Capture
- Terminal logs with telemetry events:
  - `stream_disconnected`
  - `reconnect_attempt`
  - `order_submit_failed`
  - `order_status_update_failed`
- Timestamped screenshots for UI states: loading, reconnecting, stale, error, recovered.

## Pass Criteria
- 95% of reconnects succeed in <= 10 seconds.
- No unrecoverable blank screen in dashboard or order status page.
- Any failure state has a visible user action (`Reconnect`).
