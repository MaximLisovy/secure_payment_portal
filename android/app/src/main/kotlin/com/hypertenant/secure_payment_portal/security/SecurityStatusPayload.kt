package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.bridge.ChannelContract
import com.hypertenant.secure_payment_portal.bridge.SecurityChannel

/**
 * The wire maps of the security channels: flat maps of primitives with explicit keys and a
 * `schemaVersion`, as documented in docs/platform_channels.md. The Dart side validates them.
 */
object SecurityStatusPayload {
    /** The `getSecurityStatus` reply. */
    fun status(
        root: RootReport,
        recording: Detection,
        window: WindowProtection,
    ): Map<String, Any> =
        mapOf(
            ChannelContract.KEY_SCHEMA_VERSION to ChannelContract.SCHEMA_VERSION,
            SecurityChannel.KEY_ROOT to root.state.wire,
            SecurityChannel.KEY_ROOT_SIGNALS to root.signals,
            SecurityChannel.KEY_SCREEN_RECORDING to recording.wire,
            SecurityChannel.KEY_WINDOW_PROTECTION to window.wire,
        )

    /** One event of the screen recording channel. */
    fun recording(recording: Detection): Map<String, Any> =
        mapOf(
            ChannelContract.KEY_SCHEMA_VERSION to ChannelContract.SCHEMA_VERSION,
            SecurityChannel.KEY_SCREEN_RECORDING to recording.wire,
        )
}
