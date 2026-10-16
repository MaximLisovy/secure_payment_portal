# Demo recording

Record the emulator window with the host's screen recorder. Android screenshots and recordings of the payment page are black because `FLAG_SECURE` remains active, including in simulated mode.

## Setup

- Run `flutter run --profile --flavor retail` on an Android emulator.
- Keep the application visible when starting a payment.
- Use the app bar's demo panel for simulated scenarios and the palette menu to switch brand. Both tools are absent in release builds.
- Label simulated scenarios as simulated; the app's badge must stay visible.

## Shot list

1. Open Retail Shop. Show the scan, the verified device, the summary and the Promo Banner.
2. Switch to Utility Pay. Show the change in colors, density, shape and motion, and scroll through the Bill Breakdown. The pay action stays in reach.
3. With real device security and real payment processing selected, tap Pay. Answer the notification permission prompt if it appears. Show progress in the app and the notification shade.
4. Background the app while processing. Show the updating notification, wait for completion, then reopen the app to show its receipt.
5. Start a new payment, cancel it from the notification, and show the cancelled state in the app. Retry and show that the next payment has its own result.
6. In the demo panel select simulated device security. Show a root block, a recording block that lifts when recording ends, and unavailable screen protection followed by recovery. Restore a clean simulated device between scenarios.
7. Select simulated payment processing and demonstrate a declined payment and a processing failure. Retry after returning the scenario to success.
8. Hold the simulated device check long enough to show several scan revolutions. Enable the performance overlay, then demonstrate reduced motion through the device accessibility settings.
9. Finish on the receipt and the two installed brand apps. Explain that the backend is simulated and native processing uses a foreground service.

## Evidence and limits

Use the exact validation results in the [AI Insight Report](ai/AI_INSIGHT_REPORT.md). The [manual QA checklist](MANUAL_QA.md) tracks physical-device checks, recording callback behavior and high-refresh-rate frame timing. An emulator recording does not prove 120 Hz performance on a phone.
