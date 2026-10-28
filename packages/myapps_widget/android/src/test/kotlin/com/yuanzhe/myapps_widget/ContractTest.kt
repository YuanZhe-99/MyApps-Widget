package com.yuanzhe.myapps_widget

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

/** Reads the repository-level contract fixtures that the Dart and Swift readers also check. */
class ContractTest {
    /**
     * Purpose: Find `contract/` from the Gradle working directory.
     * Inputs: None.
     * Returns: The directory.
     * Side effects: Reads the file system.
     * Notes: Walks up, since the working directory differs between a host app and the plugin.
     */
    private fun contractDir(): File {
        System.getenv("MYAPPS_WIDGET_CONTRACT")?.let { return File(it) }
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, "contract/expectations.json")
            if (candidate.exists()) return candidate.parentFile
            dir = dir.parentFile
        }
        error("contract/ not found; set MYAPPS_WIDGET_CONTRACT")
    }

    /**
     * Purpose: Check every fixture against `expectations.json`.
     * Inputs: None.
     * Returns: None.
     * Side effects: Reads fixtures.
     * Notes: Status names compare case-insensitively with underscores removed (TOO_NEW = tooNew).
     */
    @Test
    fun fixturesMatchExpectations() {
        val dir = contractDir()
        val expectations = JSONObject(File(dir, "expectations.json").readText())
        val kind = expectations.getString("expectedKind")
        val cases = expectations.getJSONObject("cases")
        val files = File(dir, "fixtures").listFiles()!!.map { it.name }.toSet()
        assertEquals(cases.keys().asSequence().toSet(), files)
        for (name in cases.keys()) {
            val want = cases.getJSONObject(name)
            val read = WidgetEnvelopeRead.decode(File(dir, "fixtures/$name").readText(), kind)
            assertEquals(name, want.getString("status").lowercase(), read.status.name.replace("_", "").lowercase())
            val e = read.envelope ?: continue
            assertEquals(name, want.getInt("payloadVersion"), e.payloadVersion)
            assertEquals(name, want.getLong("generatedAt"), e.generatedAt)
            assertEquals(name, want.getDouble("textScale"), e.textScale.toDouble(), 1e-6)
            assertEquals(name, want.getString("privacy"), e.privacy.wire)
            val refresh = want.getJSONArray("refreshAt")
            assertEquals(name, (0 until refresh.length()).map { refresh.getLong(it) }, e.refreshAt)
            assertEquals(name, if (want.isNull("instanceId")) null else want.getString("instanceId"), e.instanceId)
        }
    }

    /**
     * Purpose: Check that empty input reads as missing.
     * Inputs: None.
     * Returns: None.
     * Side effects: None.
     * Notes: None.
     */
    @Test
    fun missingInput() {
        assertEquals(WidgetEnvelopeStatus.MISSING, WidgetEnvelopeRead.decode(null).status)
        assertEquals(WidgetEnvelopeStatus.MISSING, WidgetEnvelopeRead.decode("").status)
    }
}
