package com.hypertenant.secure_payment_portal.payment

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Runs one payment as a foreground service, so processing survives the app being backgrounded and
 * the user sees that something is going on.
 *
 * **Type: `shortService`.** A payment is short, user-initiated and must finish; that is what the
 * type is for. It needs no type-specific permission (only `FOREGROUND_SERVICE`), and its limits are
 * ones this work meets: a 3 minute timeout (our simulation takes about 8 seconds), no sticky
 * restart (we want none), and a duty to stop when `onTimeout` fires. `dataSync` would need its own
 * permission, has a daily limit from Android 15, and says "data transfer", which this is not.
 * `shortService` is ignored if combined with another type, so it is declared alone.
 * `ServiceCompat.startForeground` passes the type from API 34 and masks it to nothing on 29 to 33,
 * where types are not enforced, so no branching of ours is needed. If a real backend call could
 * outlast three minutes, the type must change.
 *
 * **Lifecycle.**
 * - `onStartCommand` goes foreground first, within the five seconds the system allows, then checks
 *   the store: it runs the payment only if it is the one `Running`, so a start that lost a race, a
 *   duplicate, or a payment cancelled before the service got here does nothing. It returns
 *   `START_NOT_STICKY`: a payment never restarts by itself.
 * - It runs the payment in a scope the service owns, cancelled in `onDestroy`.
 * - On a terminal state it posts the final notification at once, then `stopForeground` and
 *   `stopSelf(startId)`: success and failure leave their notification (detached, dismissible),
 *   a cancel removes it.
 * - A cancel, from the app or the notification, only sets the store; the work sees the payment
 *   leave `Running` and stops within a step.
 * - `onTimeout` fails the payment and stops. On Android 15 both overloads are called, so it is
 *   idempotent.
 * - `onDestroy` fails the payment *this instance* was running, so the UI is never left on a
 *   stale "running". It does not touch another payment: a new one may have been claimed in the
 *   moment between one service stopping and the next starting.
 *
 * The service never references the Flutter engine or an Activity: it talks to the process through
 * [PaymentProgressStore] only.
 */
class PaymentProcessingService : Service() {
    private val store = PaymentProgressStore.shared
    private lateinit var notifications: PaymentNotificationFactory
    private var scope: CoroutineScope? = null
    private var work: Job? = null

    /** The payment this instance is running, or null. */
    private var currentPaymentId: String? = null
    private var finished = false

    override fun onCreate() {
        super.onCreate()
        notifications = PaymentNotificationFactory(this).also { it.ensureChannel() }
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val request = requestFrom(intent)
        // First, before anything can go wrong: the system gives a few seconds to do this.
        if (!goForeground()) {
            request?.let { store.fail(it.paymentId, PaymentFailureCodes.PROCESSING) }
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val state = store.state.value
        if (request == null || state !is PaymentProgress.Running || state.paymentId != request.paymentId) {
            // Cancelled before the service got here, or a start nobody claimed: nothing to run.
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (work?.isActive == true) return START_NOT_STICKY // A duplicate start: already running.

        currentPaymentId = request.paymentId
        finished = false
        work = scope?.launch { process(request, startId) }
        return START_NOT_STICKY
    }

    // API 34: the 3 minute limit of a short service.
    override fun onTimeout(startId: Int) = timedOut(startId)

    // API 35: called as well, for the same limit. Idempotent, so both may run.
    override fun onTimeout(startId: Int, fgsType: Int) = timedOut(startId)

    override fun onDestroy() {
        currentPaymentId?.let { store.fail(it, PaymentFailureCodes.PROCESSING) }
        scope?.cancel()
        scope = null
        super.onDestroy()
    }

    private suspend fun process(request: PaymentRequest, startId: Int) {
        val updater = scope?.launch { NotificationUpdater().run(store.state) { notify(it) } }
        try {
            PaymentSession(store, SimulatedPaymentProcessor()).run(request)
        } finally {
            updater?.cancel()
        }
        finish(startId)
    }

    private fun timedOut(startId: Int) {
        currentPaymentId?.let { store.fail(it, PaymentFailureCodes.PROCESSING) }
        work?.cancel()
        finish(startId)
    }

    /** Posts how the payment ended, leaves or removes the notification, and stops. Once. */
    private fun finish(startId: Int) {
        if (finished) return
        finished = true
        currentPaymentId = null
        val spec = NotificationSpec.forState(store.state.value)
        if (spec != null && !spec.isOngoing) {
            // Detach first, then post the final notification: while it is still the foreground
            // notification the system keeps it non-cancellable and drops its auto-cancel flag, so
            // updating it after it has been detached is what makes it a normal, dismissible one
            // that disappears when tapped.
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
            notify(spec)
        } else {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        }
        stopSelf(startId)
    }

    /** Foreground with the starting notification. False if the system refuses. */
    private fun goForeground(): Boolean =
        try {
            ServiceCompat.startForeground(
                this,
                PaymentNotificationFactory.NOTIFICATION_ID,
                notifications.build(NotificationSpec.starting()),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
            true
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException (API 31), a missing permission, and so on.
            false
        }

    // With the notification permission denied (API 33+) or notifications switched off, the
    // payment still runs; there is just nothing to show. notify() is skipped, not failed.
    @SuppressLint("MissingPermission")
    private fun notify(spec: NotificationSpec) {
        val manager = NotificationManagerCompat.from(this)
        if (!manager.areNotificationsEnabled()) return
        try {
            manager.notify(PaymentNotificationFactory.NOTIFICATION_ID, notifications.build(spec))
        } catch (e: SecurityException) {
            // Permission revoked between the check and the call: same as denied.
        }
    }

    private fun requestFrom(intent: Intent?): PaymentRequest? =
        PaymentRequest.of(
            intent?.getStringExtra(EXTRA_PAYMENT_ID),
            intent?.getLongExtra(EXTRA_AMOUNT_MINOR, 0) ?: 0,
            intent?.getStringExtra(EXTRA_CURRENCY),
        )

    companion object {
        private const val EXTRA_PAYMENT_ID = "paymentId"
        private const val EXTRA_AMOUNT_MINOR = "amountMinor"
        private const val EXTRA_CURRENCY = "currency"

        fun intentFor(context: Context, request: PaymentRequest): Intent =
            Intent(context, PaymentProcessingService::class.java)
                .putExtra(EXTRA_PAYMENT_ID, request.paymentId)
                .putExtra(EXTRA_AMOUNT_MINOR, request.amountMinor)
                .putExtra(EXTRA_CURRENCY, request.currency)
    }
}
