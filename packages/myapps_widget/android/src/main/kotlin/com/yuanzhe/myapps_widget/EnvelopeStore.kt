package com.yuanzhe.myapps_widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

/** Device-local store of one envelope per kind, shared by the plugin and the app's widget providers. */
object EnvelopeStore {
    /** Private preferences file; inside the app's own sandbox, so no app prefix is needed. */
    const val PREFERENCES = "myapps_widget"

    /**
     * Purpose: Return the preference key for a kind.
     * Inputs: `kind`.
     * Returns: `envelope.<kind>`.
     * Side effects: None.
     * Notes: Part of the storage contract; see `doc/en-us/envelope.md`.
     */
    fun key(kind: String): String = "envelope.$kind"

    /**
     * Purpose: Open the store's preferences.
     * Inputs: `context`.
     * Returns: `SharedPreferences`.
     * Side effects: None.
     * Notes: Never synced or backed up by the apps.
     */
    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    /**
     * Purpose: Read and decode a kind's envelope.
     * Inputs: `context`, `kind`.
     * Returns: The read result, checked against `kind`.
     * Side effects: Reads preferences.
     * Notes: Call from a provider's render path.
     */
    fun read(context: Context, kind: String): WidgetEnvelopeRead =
        WidgetEnvelopeRead.decode(prefs(context).getString(key(kind), null), kind)

    /**
     * Purpose: Store a kind's envelope text.
     * Inputs: `context`, `kind`, `envelope` — the JSON string from Dart.
     * Returns: None.
     * Side effects: Writes preferences synchronously, so a redraw right after reads it.
     * Notes: Stored as received; readers validate.
     */
    fun write(context: Context, kind: String, envelope: String) {
        prefs(context).edit().putString(key(kind), envelope).commit()
    }

    /**
     * Purpose: Remove a kind's envelope.
     * Inputs: `context`, `kind`.
     * Returns: None.
     * Side effects: Writes preferences.
     * Notes: Renderers then see `MISSING`.
     */
    fun clear(context: Context, kind: String) {
        prefs(context).edit().remove(key(kind)).commit()
    }

    /**
     * Purpose: Ask every placed instance of the given providers to redraw.
     * Inputs: `context`; `providers` — fully qualified `AppWidgetProvider` class names.
     * Returns: None.
     * Side effects: Sends `ACTION_APPWIDGET_UPDATE` broadcasts to the app's own providers.
     * Notes: Providers with no placed instance are skipped. Uses the runtime package name, so it
     * works with any applicationId suffix.
     */
    fun requestUpdate(context: Context, providers: List<String>) {
        val manager = AppWidgetManager.getInstance(context)
        for (className in providers) {
            val component = ComponentName(context.packageName, className)
            val ids = try {
                manager.getAppWidgetIds(component)
            } catch (e: Exception) {
                continue
            }
            if (ids.isEmpty()) continue
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .setComponent(component)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }

    /**
     * Purpose: Report the size the launcher gives every placed instance of the named providers.
     * Inputs: `context`; `providers` — provider class names, resolved like [requestUpdate].
     * Returns: One map per instance: `provider`, `widgetId`, and `minWidth`, `minHeight`,
     * `maxWidth`, `maxHeight` in dp from `getAppWidgetOptions`.
     * Side effects: None.
     * Notes: Portrait size is `minWidth × maxHeight`, landscape `maxWidth × minHeight`. These are
     * the dp the RemoteViews are laid out in; a launcher may still draw the result scaled.
     * Unresolvable providers are skipped.
     */
    fun placedSizes(context: Context, providers: List<String>): List<Map<String, Any>> {
        val manager = AppWidgetManager.getInstance(context)
        val sizes = mutableListOf<Map<String, Any>>()
        for (className in providers) {
            val ids = try {
                manager.getAppWidgetIds(ComponentName(context.packageName, className))
            } catch (e: Exception) {
                continue
            }
            for (id in ids) {
                val options = manager.getAppWidgetOptions(id)
                sizes += mapOf(
                    "provider" to className,
                    "widgetId" to id,
                    "minWidth" to options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
                    "minHeight" to options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT),
                    "maxWidth" to options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH),
                    "maxHeight" to options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT),
                )
            }
        }
        return sizes
    }
}
