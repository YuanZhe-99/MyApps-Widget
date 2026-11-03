package com.yuanzhe.myapps_widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Answers `com.yuanzhe.myapps_widget/bridge`: stores envelopes and redraws the named providers. */
class MyAppsWidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    /**
     * Purpose: Register the bridge channel.
     * Inputs: `binding`.
     * Returns: None.
     * Side effects: Installs the method-channel handler and registers the channel for
     * `actionsQueued` calls.
     * Notes: Engine lifetime.
     */
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
            synchronized(attached) { attached.add(it) }
        }
    }

    /**
     * Purpose: Unregister the bridge channel.
     * Inputs: `binding`.
     * Returns: None.
     * Side effects: Removes the handler and the `actionsQueued` registration.
     * Notes: None.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.let { synchronized(attached) { attached.remove(it) } }
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    /**
     * Purpose: Handle `publish`, `clear`, `placedSizes`, `pendingActions` and `acknowledgeActions`.
     * Inputs: `call` — `kind`, `androidProviders`, and for `publish` the `envelope` string; for
     * `acknowledgeActions` the `ids` list; `result`.
     * Returns: None; answers `result` (`placedSizes` with `EnvelopeStore.placedSizes`,
     * `pendingActions` with the raw queue text or null).
     * Side effects: `publish` and `clear` write `EnvelopeStore` and broadcast redraws;
     * `acknowledgeActions` rewrites the action queue; the others only read.
     * Notes: A missing `kind` is a `bad_args` error for the envelope calls; the queue calls take
     * no kind. Storage never throws to Dart otherwise.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("detached", "No application context", null)
        when (call.method) {
            "pendingActions" -> return result.success(WidgetActionQueue.raw(ctx))
            "acknowledgeActions" -> {
                WidgetActionQueue.remove(ctx, call.argument<List<String>>("ids") ?: emptyList())
                return result.success(null)
            }
        }
        val kind = call.argument<String>("kind")
        if (kind.isNullOrEmpty()) return result.error("bad_args", "kind is required", null)
        val providers = call.argument<List<String>>("androidProviders") ?: emptyList()
        when (call.method) {
            "publish" -> {
                EnvelopeStore.write(ctx, kind, call.argument<String>("envelope") ?: "")
                EnvelopeStore.requestUpdate(ctx, providers)
                result.success(null)
            }
            "clear" -> {
                EnvelopeStore.clear(ctx, kind)
                EnvelopeStore.requestUpdate(ctx, providers)
                result.success(null)
            }
            "placedSizes" -> result.success(EnvelopeStore.placedSizes(ctx, providers))
            else -> result.notImplemented()
        }
    }

    companion object {
        /** Matches `MyAppsWidgetBridge.channelName` in Dart. */
        const val CHANNEL = "com.yuanzhe.myapps_widget/bridge"

        /** Channels of the attached Flutter engines, told when a widget queues an action. */
        private val attached = mutableSetOf<MethodChannel>()

        /**
         * Purpose: Tell every attached engine that the action queue grew.
         * Inputs: None.
         * Returns: None.
         * Side effects: Invokes `actionsQueued` on the main thread.
         * Notes: No engine attached (app closed) is fine; the app drains on its next start.
         */
        fun notifyActionsQueued() {
            val channels = synchronized(attached) { attached.toList() }
            if (channels.isEmpty()) return
            Handler(Looper.getMainLooper()).post {
                channels.forEach { it.invokeMethod("actionsQueued", null) }
            }
        }
    }
}
