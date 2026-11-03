package com.yuanzhe.myapps_widget

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** One queued tap on an interactive widget control; mirrors Dart's `WidgetAction`. */
data class WidgetAction(
    val id: String,
    val kind: String,
    val action: String,
    /** Epoch milliseconds. */
    val at: Long,
    val args: JSONObject,
    val instanceId: String? = null,
) {
    /**
     * Purpose: Serialize to the stored JSON object.
     * Inputs: None.
     * Returns: `JSONObject`.
     * Side effects: None.
     * Notes: `instanceId` is written only when present.
     */
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("kind", kind)
        .put("action", action)
        .put("at", at)
        .put("args", args)
        .also { if (instanceId != null) it.put("instanceId", instanceId) }
}

/**
 * The pending-action queue in the private `myapps_widget` preferences, key `actions`: a JSON array
 * shared by every kind of the app, oldest first. See `doc/en-us/actions.md`.
 */
object WidgetActionQueue {
    /** Preference key of the queue; part of the storage contract. */
    const val KEY = "actions"

    /** Most entries kept; appending beyond it drops the oldest. */
    const val MAX_LENGTH = 200

    private val lock = Any()

    /**
     * Purpose: Decode stored queue text with the shared contract rules.
     * Inputs: `raw` — the stored string or null.
     * Returns: The valid actions in stored order; empty for missing, invalid or non-array text.
     * Side effects: None.
     * Notes: Entries without non-empty string `id`, `kind`, `action` or a numeric `at` are
     * skipped; a non-object `args` reads as `{}` and a non-string `instanceId` as null.
     */
    fun decode(raw: String?): List<WidgetAction> {
        if (raw.isNullOrEmpty()) return emptyList()
        val array = try {
            JSONArray(raw)
        } catch (e: Exception) {
            return emptyList()
        }
        return (0 until array.length()).mapNotNull { entry(array.opt(it)) }
    }

    /**
     * Purpose: Read one queue entry.
     * Inputs: `value` — any JSON value.
     * Returns: The action, or null when it is malformed.
     * Side effects: None.
     * Notes: Booleans and numeric strings are not numbers.
     */
    private fun entry(value: Any?): WidgetAction? {
        val json = value as? JSONObject ?: return null
        fun text(key: String): String? = (json.opt(key) as? String)?.takeIf { it.isNotEmpty() }
        val id = text("id") ?: return null
        val kind = text("kind") ?: return null
        val action = text("action") ?: return null
        val at = (json.opt("at") as? Number)?.takeIf { it.toDouble().isFinite() } ?: return null
        return WidgetAction(
            id = id,
            kind = kind,
            action = action,
            at = at.toLong(),
            args = json.opt("args") as? JSONObject ?: JSONObject(),
            instanceId = json.opt("instanceId") as? String,
        )
    }

    /**
     * Purpose: Return the stored queue text.
     * Inputs: `context`.
     * Returns: The raw JSON array text, or null when nothing is queued.
     * Side effects: Reads preferences.
     * Notes: Sent to Dart as is; Dart applies the same reading rules.
     */
    fun raw(context: Context): String? = EnvelopeStore.prefs(context).getString(KEY, null)

    /**
     * Purpose: Return the queued actions of one kind.
     * Inputs: `context`, `kind`.
     * Returns: Its actions, oldest first.
     * Side effects: Reads preferences.
     * Notes: Renderers replay these over the envelope so a tap shows at once.
     */
    fun pending(context: Context, kind: String): List<WidgetAction> =
        decode(raw(context)).filter { it.kind == kind }

    /**
     * Purpose: Append one action.
     * Inputs: `context`; `action`.
     * Returns: None.
     * Side effects: Rewrites the queue synchronously, keeping at most [MAX_LENGTH] newest.
     * Notes: Serialized with [remove] so a tap and an acknowledgement never lose each other.
     */
    fun append(context: Context, action: WidgetAction) {
        synchronized(lock) {
            val next = (decode(raw(context)) + action).takeLast(MAX_LENGTH)
            write(context, next)
        }
    }

    /**
     * Purpose: Remove applied actions.
     * Inputs: `context`; `ids`.
     * Returns: None.
     * Side effects: Rewrites the queue synchronously.
     * Notes: Unknown ids are ignored. Malformed entries are dropped by the rewrite.
     */
    fun remove(context: Context, ids: Collection<String>) {
        if (ids.isEmpty()) return
        synchronized(lock) {
            write(context, decode(raw(context)).filter { it.id !in ids })
        }
    }

    /**
     * Purpose: Store a queue.
     * Inputs: `context`, `actions`.
     * Returns: None.
     * Side effects: Writes or removes the preference with `commit`.
     * Notes: An empty queue removes the key.
     */
    private fun write(context: Context, actions: List<WidgetAction>) {
        val edit = EnvelopeStore.prefs(context).edit()
        if (actions.isEmpty()) {
            edit.remove(KEY)
        } else {
            val array = JSONArray()
            actions.forEach { array.put(it.toJson()) }
            edit.putString(KEY, array.toString())
        }
        edit.commit()
    }
}

/**
 * Receives widget control taps built by [WidgetActions.pendingIntent], queues them, redraws the
 * kind's widgets and tells a running app.
 */
class WidgetActionReceiver : BroadcastReceiver() {
    /**
     * Purpose: Queue one tap.
     * Inputs: `context`; `intent` — the extras set by [WidgetActions.pendingIntent].
     * Returns: None.
     * Side effects: Appends to [WidgetActionQueue], broadcasts redraws to the given providers and
     * calls `actionsQueued` on every attached Flutter engine.
     * Notes: Runs without a Flutter engine when the app is closed; the app drains the queue later.
     */
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != WidgetActions.ACTION) return
        val kind = intent.getStringExtra(WidgetActions.EXTRA_KIND) ?: return
        val name = intent.getStringExtra(WidgetActions.EXTRA_ACTION) ?: return
        val args = try {
            JSONObject(intent.getStringExtra(WidgetActions.EXTRA_ARGS) ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }
        WidgetActionQueue.append(
            context,
            WidgetAction(
                id = UUID.randomUUID().toString(),
                kind = kind,
                action = name,
                at = System.currentTimeMillis(),
                args = args,
                instanceId = intent.getStringExtra(WidgetActions.EXTRA_INSTANCE),
            ),
        )
        val providers = intent.getStringArrayExtra(WidgetActions.EXTRA_PROVIDERS)?.toList() ?: emptyList()
        EnvelopeStore.requestUpdate(context, providers)
        MyAppsWidgetPlugin.notifyActionsQueued()
    }
}

/** Tap targets for interactive widget controls. */
object WidgetActions {
    /** Broadcast action of [WidgetActionReceiver]. */
    const val ACTION = "com.yuanzhe.myapps_widget.ACTION"
    const val EXTRA_KIND = "kind"
    const val EXTRA_ACTION = "action"
    const val EXTRA_ARGS = "args"
    const val EXTRA_INSTANCE = "instanceId"
    const val EXTRA_PROVIDERS = "providers"

    /**
     * Purpose: Build the tap action that queues an app action without opening the app.
     * Inputs: `context`; `kind`; `action` — the app's action name; `args`; `providers` — the
     * kind's provider class names to redraw; `requestCode`; optional `instanceId`.
     * Returns: An immutable broadcast `PendingIntent` to [WidgetActionReceiver].
     * Side effects: None.
     * Notes: The intent data carries kind, action, args and request code, so controls with
     * different arguments never collapse into one PendingIntent. Works on every Android version.
     */
    fun pendingIntent(
        context: Context,
        kind: String,
        action: String,
        args: JSONObject,
        providers: List<String>,
        requestCode: Int,
        instanceId: String? = null,
    ): PendingIntent {
        val data = Uri.Builder()
            .scheme("myapps-widget-action")
            .authority(kind)
            .appendPath(action)
            .appendQueryParameter("args", args.toString())
            .appendQueryParameter("code", requestCode.toString())
            .build()
        val intent = Intent(ACTION)
            .setClass(context, WidgetActionReceiver::class.java)
            .setData(data)
            .putExtra(EXTRA_KIND, kind)
            .putExtra(EXTRA_ACTION, action)
            .putExtra(EXTRA_ARGS, args.toString())
            .putExtra(EXTRA_PROVIDERS, providers.toTypedArray())
        if (instanceId != null) intent.putExtra(EXTRA_INSTANCE, instanceId)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
