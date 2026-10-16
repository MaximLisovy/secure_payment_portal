package com.hypertenant.secure_payment_portal.payment

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.hypertenant.secure_payment_portal.R

/**
 * Builds the payment notification and its channel.
 *
 * The text is generic on purpose, taken from string resources: no amount, no merchant, and the
 * visibility is private, so a lock screen shows nothing about the payment. Every `PendingIntent`
 * is immutable. The channel has low importance: it never makes a sound or pops up.
 */
class PaymentNotificationFactory(private val context: Context) {
    /** Creates the channel; cheap and idempotent. Channels exist from API 26, compat skips below. */
    fun ensureChannel() {
        val channel =
            NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
                .setName(context.getString(R.string.payment_channel_name))
                .setDescription(context.getString(R.string.payment_channel_description))
                .build()
        NotificationManagerCompat.from(context).createNotificationChannel(channel)
    }

    fun build(spec: NotificationSpec): Notification {
        val title =
            context.getString(
                when (spec.kind) {
                    NotificationKind.PROCESSING -> R.string.payment_notification_processing
                    NotificationKind.COMPLETE -> R.string.payment_notification_complete
                    NotificationKind.FAILED -> R.string.payment_notification_failed
                }
            )
        val builder =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_payment)
                .setContentTitle(title)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setOnlyAlertOnce(true)
                .setOngoing(spec.isOngoing)
                .setAutoCancel(!spec.isOngoing)
                .setCategory(
                    if (spec.isOngoing) NotificationCompat.CATEGORY_PROGRESS else NotificationCompat.CATEGORY_STATUS
                )
                // API 31+: show the foreground-service notification at once, not after 10 s.
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        openAppIntent()?.let(builder::setContentIntent)
        if (spec.showsProgress) builder.setProgress(PERCENT_MAX, spec.percent, false)
        if (spec.showsCancel && spec.attemptId != null) {
            builder.addAction(0, context.getString(R.string.payment_notification_cancel), cancelIntent(spec.attemptId))
        }
        return builder.build()
    }

    private fun openAppIntent(): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context,
            REQUEST_OPEN,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun cancelIntent(attemptId: String): PendingIntent {
        val intent =
            Intent(context, PaymentCancelReceiver::class.java)
                .setAction(PaymentCancelAction.ACTION_CANCEL)
                // Intent data (API 1) makes each PendingIntent identity distinct. Extras alone
                // do not: an old notification must never cancel a replacement attempt.
                .setData(Uri.parse("payment-cancel:$attemptId"))
                .putExtra(PaymentCancelAction.EXTRA_ATTEMPT_ID, attemptId)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CANCEL,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        const val CHANNEL_ID = "payment_progress"
        const val NOTIFICATION_ID = 4_201
        private const val PERCENT_MAX = 100
        private const val REQUEST_OPEN = 1
        private const val REQUEST_CANCEL = 2
    }
}
