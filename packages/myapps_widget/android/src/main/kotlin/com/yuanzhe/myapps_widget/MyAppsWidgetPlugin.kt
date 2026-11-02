package com.yuanzhe.myapps_widget

import android.content.Context
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
     * Side effects: Installs the method-channel handler.
     * Notes: Engine lifetime.
     */
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    /**
     * Purpose: Unregister the bridge channel.
     * Inputs: `binding`.
     * Returns: None.
     * Side effects: Removes the handler.
     * Notes: None.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    /**
     * Purpose: Handle `publish`, `clear` and `placedSizes`.
     * Inputs: `call` — `kind`, `androidProviders`, and for `publish` the `envelope` string; `result`.
     * Returns: None; answers `result` (`placedSizes` with `EnvelopeStore.placedSizes`).
     * Side effects: `publish` and `clear` write `EnvelopeStore` and broadcast redraws;
     * `placedSizes` only reads.
     * Notes: A missing `kind` is a `bad_args` error; storage never throws to Dart otherwise.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("detached", "No application context", null)
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
    }
}
