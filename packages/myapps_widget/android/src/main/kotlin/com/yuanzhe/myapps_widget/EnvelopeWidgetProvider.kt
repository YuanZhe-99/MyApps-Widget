package com.yuanzhe.myapps_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews

/**
 * Base for an app's widget provider: redraws on every system update, on resize and after
 * `EnvelopeStore.requestUpdate`, delegating the drawing to [render].
 */
abstract class EnvelopeWidgetProvider : AppWidgetProvider() {

    /**
     * Purpose: Build one instance's views.
     * Inputs: `context`; `appWidgetId`; `options` — the instance's size options, possibly null.
     * Returns: `RemoteViews`.
     * Side effects: None expected; read the envelope with `EnvelopeStore.read`.
     * Notes: Called on the main thread; keep it quick.
     */
    abstract fun render(context: Context, appWidgetId: Int, options: Bundle?): RemoteViews

    /**
     * Purpose: Redraw the given instances.
     * Inputs: `context`, `appWidgetManager`, `appWidgetIds`.
     * Returns: None.
     * Side effects: Pushes RemoteViews to the launcher.
     * Notes: Runs on add, on the system update period and after a publish.
     */
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, id, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    /**
     * Purpose: Redraw one instance after the user resizes it.
     * Inputs: `context`, `appWidgetManager`, `appWidgetId`, `newOptions`.
     * Returns: None.
     * Side effects: Pushes RemoteViews to the launcher.
     * Notes: None.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, render(context, appWidgetId, newOptions))
    }
}

/**
 * Purpose: Set a text size in sp scaled by a widget text scale.
 * Inputs: `viewId`; `baseSp` — the size at 100%; `scale` — usually `WidgetEnvelope.textScale`.
 * Returns: None.
 * Side effects: Mutates the RemoteViews.
 * Notes: The scale is clamped again, so a stray value cannot break a layout.
 */
fun RemoteViews.setScaledTextSize(viewId: Int, baseSp: Float, scale: Float) {
    setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, baseSp * WidgetTextScale.clamp(scale.toDouble()))
}

/** Tap targets for widgets. */
object WidgetLaunch {
    /**
     * Purpose: Build the tap action that opens the app, optionally on a deep link.
     * Inputs: `context`; `link` — a `<scheme>://widget/<kind>` URI or null for the launcher screen;
     * `requestCode` — distinct per distinct link so PendingIntents do not collapse.
     * Returns: An immutable `PendingIntent`.
     * Side effects: None.
     * Notes: The link is delivered as the launch intent's data; the app routes it.
     */
    fun pendingIntent(context: Context, link: Uri? = null, requestCode: Int = 0): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (link != null) {
            intent.action = Intent.ACTION_VIEW
            intent.data = link
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
