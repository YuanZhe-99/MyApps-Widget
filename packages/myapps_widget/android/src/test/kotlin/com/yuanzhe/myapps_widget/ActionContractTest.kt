package com.yuanzhe.myapps_widget

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Reads the pending-action fixtures that the Dart and Swift queue readers also check. */
class ActionContractTest {
    /**
     * Purpose: Find `contract/` from the Gradle working directory.
     * Inputs: None.
     * Returns: The directory.
     * Side effects: Reads the file system.
     * Notes: Same lookup as `ContractTest`.
     */
    private fun contractDir(): File {
        System.getenv("MYAPPS_WIDGET_CONTRACT")?.let { return File(it) }
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, "contract/action_expectations.json")
            if (candidate.exists()) return candidate.parentFile
            dir = dir.parentFile
        }
        error("contract/ not found; set MYAPPS_WIDGET_CONTRACT")
    }

    /**
     * Purpose: Check every action fixture against `action_expectations.json`.
     * Inputs: None.
     * Returns: None.
     * Side effects: Reads fixtures.
     * Notes: `args` compare as JSON text after re-parsing, so key order does not matter.
     */
    @Test
    fun actionFixturesMatchExpectations() {
        val dir = contractDir()
        val cases = JSONObject(File(dir, "action_expectations.json").readText()).getJSONObject("cases")
        val files = File(dir, "actions").listFiles()!!.map { it.name }.toSet()
        assertEquals(cases.keys().asSequence().toSet(), files)
        for (name in cases.keys()) {
            val want = cases.getJSONArray(name)
            val read = WidgetActionQueue.decode(File(dir, "actions/$name").readText())
            assertEquals(name, want.length(), read.size)
            for (i in 0 until want.length()) {
                val w = want.getJSONObject(i)
                val a = read[i]
                assertEquals(name, w.getString("id"), a.id)
                assertEquals(name, w.getString("kind"), a.kind)
                assertEquals(name, w.getString("action"), a.action)
                assertEquals(name, w.getLong("at"), a.at)
                assertTrue(name, sameJson(w.getJSONObject("args"), a.args))
                assertEquals(name, if (w.isNull("instanceId")) null else w.getString("instanceId"), a.instanceId)
            }
        }
    }

    /**
     * Purpose: Compare two JSON objects key by key.
     * Inputs: `a`, `b`.
     * Returns: Whether they hold the same keys and textual values.
     * Side effects: None.
     * Notes: Numbers compare by their double value.
     */
    private fun sameJson(a: JSONObject, b: JSONObject): Boolean {
        if (a.keys().asSequence().toSet() != b.keys().asSequence().toSet()) return false
        return a.keys().asSequence().all { key ->
            val x = a.get(key)
            val y = b.get(key)
            if (x is Number && y is Number) x.toDouble() == y.toDouble() else x.toString() == y.toString()
        }
    }

    /**
     * Purpose: Check that empty input reads as an empty queue.
     * Inputs: None.
     * Returns: None.
     * Side effects: None.
     * Notes: None.
     */
    @Test
    fun missingQueue() {
        assertTrue(WidgetActionQueue.decode(null).isEmpty())
        assertTrue(WidgetActionQueue.decode("").isEmpty())
    }
}
