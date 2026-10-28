package com.yuanzhe.myapps_widget

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

/** Envelope format version this reader fully understands; matches the Dart `widgetEnvelopeVersion`. */
const val WIDGET_ENVELOPE_VERSION = 1

/** Privacy level of an envelope; unknown wire values read as [NORMAL]. */
enum class WidgetPrivacy(val wire: String) {
    NORMAL("normal"),
    SENSITIVE("sensitive"),
    HIDDEN("hidden");

    companion object {
        /**
         * Purpose: Read a level from its wire name.
         * Inputs: `value` — any JSON value.
         * Returns: The matching level, or [NORMAL].
         * Side effects: None.
         * Notes: Mirrors `WidgetPrivacy.fromWire` in Dart.
         */
        fun fromWire(value: Any?): WidgetPrivacy = values().firstOrNull { it.wire == value } ?: NORMAL
    }
}

/** The widget text size multiplier range, shared with Dart and Swift. */
object WidgetTextScale {
    const val MIN = 0.9f
    const val MAX = 1.5f
    const val DEFAULT = 1.0f

    /**
     * Purpose: Keep a text scale inside the supported range.
     * Inputs: `scale`.
     * Returns: The value clamped to [MIN]..[MAX], rounded to one decimal; [DEFAULT] for NaN or infinity.
     * Side effects: None.
     * Notes: Mirrors `WidgetTextScale.clamp` in Dart.
     */
    fun clamp(scale: Double): Float {
        if (!scale.isFinite()) return DEFAULT
        val clamped = scale.coerceIn(MIN.toDouble(), MAX.toDouble())
        return ((clamped * 10).roundToInt() / 10.0).toFloat()
    }
}

/** A decoded envelope. [payload] is the app's own object; this package never interprets it. */
data class WidgetEnvelope(
    val version: Int,
    val kind: String,
    val payloadVersion: Int,
    val generatedAt: Long,
    val textScale: Float,
    val privacy: WidgetPrivacy,
    val refreshAt: List<Long>,
    val instanceId: String?,
    val payload: JSONObject,
) {
    /**
     * Purpose: Scale a layout text size by the envelope's text scale.
     * Inputs: `base` — sp at 100%.
     * Returns: The scaled size in sp.
     * Side effects: None.
     * Notes: Pair with `RemoteViews.setScaledTextSize`.
     */
    fun sp(base: Float): Float = base * textScale
}

/** Outcome of reading a stored envelope; the check order matches Dart's `WidgetEnvelopeRead.decode`. */
enum class WidgetEnvelopeStatus { MISSING, INVALID, TOO_NEW, OK }

/** A read result: the status and, for [WidgetEnvelopeStatus.OK], the envelope. */
data class WidgetEnvelopeRead(val status: WidgetEnvelopeStatus, val envelope: WidgetEnvelope? = null) {
    companion object {
        /**
         * Purpose: Decode stored text with the shared contract rules.
         * Inputs: `raw` — the stored string or null; `expectedKind` — the kind being rendered, or null.
         * Returns: The read result.
         * Side effects: None.
         * Notes: missing → invalid JSON or payload → tooNew → kind mismatch → ok. Missing fields take
         * defaults, out-of-range values are clamped, and malformed `refreshAt` items are skipped.
         */
        fun decode(raw: String?, expectedKind: String? = null): WidgetEnvelopeRead {
            if (raw.isNullOrEmpty()) return WidgetEnvelopeRead(WidgetEnvelopeStatus.MISSING)
            val json = try {
                JSONObject(raw)
            } catch (e: Exception) {
                return WidgetEnvelopeRead(WidgetEnvelopeStatus.INVALID)
            }
            val payload = json.opt("payload") as? JSONObject
                ?: return WidgetEnvelopeRead(WidgetEnvelopeStatus.INVALID)
            val version = number(json.opt("v"))?.toInt() ?: 0
            if (version > WIDGET_ENVELOPE_VERSION) return WidgetEnvelopeRead(WidgetEnvelopeStatus.TOO_NEW)
            val kind = json.opt("kind") as? String ?: ""
            if (expectedKind != null && kind != expectedKind) {
                return WidgetEnvelopeRead(WidgetEnvelopeStatus.INVALID)
            }
            val envelope = WidgetEnvelope(
                version = version,
                kind = kind,
                payloadVersion = number(json.opt("pv"))?.toInt() ?: 1,
                generatedAt = number(json.opt("generatedAt"))?.toLong() ?: 0L,
                textScale = WidgetTextScale.clamp(number(json.opt("textScale"))?.toDouble() ?: 1.0),
                privacy = WidgetPrivacy.fromWire(json.opt("privacy")),
                refreshAt = longs(json.opt("refreshAt") as? JSONArray),
                instanceId = json.opt("instanceId") as? String,
                payload = payload,
            )
            return WidgetEnvelopeRead(WidgetEnvelopeStatus.OK, envelope)
        }

        /**
         * Purpose: Read a finite JSON number.
         * Inputs: `value`.
         * Returns: The number, or null for anything else.
         * Side effects: None.
         * Notes: org.json may hand back Integer, Long or Double for the same JSON number.
         */
        private fun number(value: Any?): Number? {
            val n = value as? Number ?: return null
            return if (n.toDouble().isFinite()) n else null
        }

        /**
         * Purpose: Read the sorted numeric items of a JSON array.
         * Inputs: `array`, possibly null.
         * Returns: Sorted epoch milliseconds.
         * Side effects: None.
         * Notes: Non-numeric items are skipped.
         */
        private fun longs(array: JSONArray?): List<Long> {
            if (array == null) return emptyList()
            return (0 until array.length()).mapNotNull { number(array.opt(it))?.toLong() }.sorted()
        }
    }
}
