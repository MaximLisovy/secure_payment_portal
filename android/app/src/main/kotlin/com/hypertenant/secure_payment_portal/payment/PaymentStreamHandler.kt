package com.hypertenant.secure_payment_portal.payment

import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * The `…/payment/progress` event channel: collects the process-wide store while listened to.
 *
 * A `StateFlow` replays its current value to a new collector, which is the contract's "emit the
 * current state on listen", and a terminal state is simply the current value until the next payment,
 * so it is replayed too. Intermediate percents may be skipped if they arrive faster than they are
 * delivered; the latest is never lost. Emissions happen on the plugin scope, which is on main.
 *
 * `onCancel` stops the collector and drops the sink; a second `onListen`, with or without an
 * `onCancel` before it, leaves one collector and the new sink.
 */
class PaymentStreamHandler(
    private val scope: CoroutineScope,
    private val store: PaymentProgressStore,
) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var collector: Job? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        collector?.cancel()
        sink = events
        collector = scope.launch { store.state.collect { sink?.success(PaymentProgressPayload.of(it)) } }
    }

    override fun onCancel(arguments: Any?) {
        collector?.cancel()
        collector = null
        sink = null
    }
}
