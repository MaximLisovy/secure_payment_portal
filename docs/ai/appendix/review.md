# Appendix D: Review summary

Part of the [AI Insight Report](../AI_INSIGHT_REPORT.md). Two independent reviews supplied findings that the developer
consolidated into 13 approved fixes. Both put payment correctness first. Their findings also covered protection timing,
root confidence and cancellation, release isolation, performance evidence, maintainability and documentation accuracy.
The supplied consolidation did not include separate reports or scores; this summary attributes no invented findings to
individual reviewers.

## Two-review findings and approved fixes

**Payment correctness.** Transport failures previously looked like rejected payments and could enable an unsafe retry.
[5f000e0](https://github.com/MaximLisovy/secure_payment_portal/commit/5f000e0) retains uncertain attempts, accepts stream updates
and actively queries native snapshots with backoff for 30 seconds; expiry withholds retry.
[bb95594](https://github.com/MaximLisovy/secure_payment_portal/commit/bb95594) bounds silent startup to five seconds.
[78f7d4e](https://github.com/MaximLisovy/secure_payment_portal/commit/78f7d4e) validates wire ranges and contains mapping errors.
[1042c93](https://github.com/MaximLisovy/secure_payment_portal/commit/1042c93) prevents cancelled permission preparation from
starting later. Regression tests cover both previously surviving mutations, late terminals and replacement attempts.
The tested classification separates proven start rejections from unknown outcomes caused by timeouts, unavailable plugins,
malformed or unscoped events and stream errors. Snapshot absence cannot establish that no attempt started; the recovery
window covers native processing plus margin while staying below the service limit.

**Security.** [0497ce2](https://github.com/MaximLisovy/secure_payment_portal/commit/0497ce2) withholds sensitive content until
window protection is confirmed. [78338d7](https://github.com/MaximLisovy/secure_payment_portal/commit/78338d7) requires a
conclusive strong clean root check. [309d4cd](https://github.com/MaximLisovy/secure_payment_portal/commit/309d4cd) bounds waits
without joining blocked probes. The file-access ambiguity and fail-closed availability trade-off remain documented.

**Release and maintainability.** [2bd79d4](https://github.com/MaximLisovy/secure_payment_portal/commit/2bd79d4) isolates each
release brand and its demo catalog; actual APK strings were checked across AOT architectures and decompressed entries.
[33b2d3f](https://github.com/MaximLisovy/secure_payment_portal/commit/33b2d3f) adds rolling frame statistics.
[ad905cf](https://github.com/MaximLisovy/secure_payment_portal/commit/ad905cf) moves simulation controls behind DI, annotates
test hooks, removes unused permission data and corrects promo assumptions.

**Claims and deliverables.** [5e5d2fb](https://github.com/MaximLisovy/secure_payment_portal/commit/5e5d2fb),
[458cdef](https://github.com/MaximLisovy/secure_payment_portal/commit/458cdef) and
[ff958fc](https://github.com/MaximLisovy/secure_payment_portal/commit/ff958fc) correct reply-liveness, recorder, setup and
AI-attribution claims. [caa2ca1](https://github.com/MaximLisovy/secure_payment_portal/commit/caa2ca1) packages both release and
arm64 profile APKs with hashes and source revision. Historical notification and recorder corrections remain in
[Prompt Log highlight 2](../PROMPT_LOG.md#2-the-device-overruled-the-ais-plan-its-comments-and-the-rule-file) and
[highlight 3](../PROMPT_LOG.md#3-an-emulator-experiment-refuted-the-recording-hypothesis).

Validation passed formatting, zero-issue analysis, 888 Dart tests, 226 Kotlin/JVM tests under JDK 21 and both flavor debug
builds. Release isolation checks passed. These are exercised cases, not proof of correctness.

Remaining limits: snapshots are not durable backend history; root heuristics are bypassable; recorder behavior varies by
API/OEM. The fixes and new statistics have no physical-phone rerun or new phone measurements. Historical observations and
untested checks remain in [Manual QA](../../MANUAL_QA.md). The 367-line flow coordinator remains a maintenance deviation.
Verdict-hold logic was unchanged. Significant decisions and validation belong in commit messages.
