package com.thanhtaxixanh.dashboard

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import io.flutter.FlutterInjector

// A single application-owned SQLite helper serves both Dart engines. Event text
// is never sent to Diagnostics.values or diagnostic log files.
class EventDatabase(private val context: Context) : SQLiteOpenHelper(context, "calendar.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE events (id TEXT PRIMARY KEY, source TEXT NOT NULL, payload TEXT NOT NULL)")
        db.execSQL("CREATE TABLE options (id TEXT PRIMARY KEY, value TEXT NOT NULL)")
        val asset = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/events_vn.json")
        val seed = JSONObject(context.assets.open(asset).bufferedReader().use { it.readText() }).getJSONArray("events")
        for (i in 0 until seed.length()) put(db, seed.getJSONObject(i))
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}
    private fun put(db: SQLiteDatabase, event: JSONObject) {
        val values = ContentValues().apply {
            put("id", event.getString("id")); put("source", event.getString("source")); put("payload", event.toString())
        }
        db.insertWithOnConflict("events", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }
    private fun find(db: SQLiteDatabase, id: String): JSONObject? = db.query("events", arrayOf("payload"), "id=?", arrayOf(id), null, null, null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else null
    }
    private fun userEvent(input: JSONObject): JSONObject {
        val id = input.getString("id")
        require(id.matches(Regex("user_[A-Za-z0-9_-]{1,75}")))
        val title = input.getString("title").trim()
        val note = input.optString("note", "")
        require(title.isNotEmpty() && title.length <= 120 && note.length <= 2000)
        require(input.getString("source") == "user")
        val calendar = input.getString("calendar")
        require(calendar in listOf("solar", "lunar"))
        val day = input.getInt("day"); val month = input.getInt("month")
        val maxDay = if (calendar == "lunar") 30 else 31
        require(month in 1..12 && day in 1..maxDay)
        val year = if (input.isNull("year")) null else input.getInt("year")
        require(year == null || year in 1900..2100)
        if (calendar == "solar") LocalDate.of(year ?: 2000, month, day)
        val color = input.optLong("color", 0xff41b69b)
        require(color in 0..0xffffffffL)
        return JSONObject().put("id", id).put("title", title).put("calendar", calendar)
            .put("day", day).put("month", month).put("year", year ?: JSONObject.NULL)
            .put("source", "user").put("note", note).put("color", color)
            .put("isPublicHoliday", false).put("enabled", input.optBoolean("enabled", true))
            .put("includeLeap", input.optBoolean("includeLeap", false))
    }
    fun archive(): String {
        val events = JSONArray()
        val db = readableDatabase
        db.query("events", arrayOf("payload"), null, null, null, null, "id").use {
            while (it.moveToNext()) events.put(JSONObject(it.getString(0)))
        }
        val monthly = db.query("options", arrayOf("value"), "id=?", arrayOf("monthly"), null, null, null).use { it.moveToFirst() && it.getString(0) == "true" }
        return JSONObject().put("version", 1).put("events", events).put("showMonthly", monthly).toString()
    }
    fun save(raw: String) {
        require(raw.length <= 10000)
        val event = userEvent(JSONObject(raw))
        val db = writableDatabase
        require(find(db, event.getString("id"))?.optString("source") != "seed")
        put(db, event)
    }
    fun toggle(id: String, enabled: Boolean) {
        val db = writableDatabase
        val event = find(db, id) ?: error("Missing event")
        put(db, event.put("enabled", enabled))
    }
    fun delete(id: String) {
        val db = writableDatabase
        require(find(db, id)?.optString("source") == "user")
        db.delete("events", "id=?", arrayOf(id))
    }
    fun monthly(enabled: Boolean) {
        writableDatabase.insertWithOnConflict("options", null, ContentValues().apply { put("id", "monthly"); put("value", enabled.toString()) }, SQLiteDatabase.CONFLICT_REPLACE)
    }
    fun importArchive(raw: String) {
        require(raw.toByteArray(Charsets.UTF_8).size <= 1024 * 1024)
        val archive = JSONObject(raw)
        require(archive.getInt("version") == 1)
        val incoming = archive.getJSONArray("events")
        require(incoming.length() <= 1000)
        val db = writableDatabase
        val seen = mutableSetOf<String>()
        val validated = mutableListOf<JSONObject>()
        for (i in 0 until incoming.length()) {
            val value = incoming.getJSONObject(i)
            val id = value.getString("id")
            require(seen.add(id))
            if (value.getString("source") == "seed") {
                val actual = find(db, id) ?: error("Unknown seed")
                require(actual.getString("source") == "seed")
                validated.add(actual.put("enabled", value.getBoolean("enabled")))
            } else {
                require(find(db, id)?.optString("source") != "seed")
                validated.add(userEvent(value))
            }
        }
        db.beginTransaction()
        try {
            for (value in validated) put(db, value)
            monthly(archive.optBoolean("showMonthly", false))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
}
