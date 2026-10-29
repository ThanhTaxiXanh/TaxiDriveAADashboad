package com.thanhtaxixanh.dashboard

import androidx.sqlite.SQLiteConnection
import androidx.sqlite.SQLiteStatement
import androidx.sqlite.driver.bundled.BundledSQLiteDriver
import androidx.sqlite.driver.bundled.SQLITE_OPEN_READONLY
import java.io.File

// Android's platform SQLite does not consistently enable R-tree. Use the same
// bundled AndroidX driver on Android and in the native JVM contract tests.
class RoadDatabase private constructor(private val connection: SQLiteConnection) : AutoCloseable {
    companion object {
        fun open(file: File): RoadDatabase = RoadDatabase(BundledSQLiteDriver().open(file.absolutePath, SQLITE_OPEN_READONLY))
    }
    val version: Int get() = rawQuery("PRAGMA user_version", null).use { check(it.moveToFirst()); it.getLong(0).toInt() }
    fun rawQuery(sql: String, arguments: Array<String>?): RoadRows {
        val statement = connection.prepare(sql)
        try { arguments?.forEachIndexed { index, value -> statement.bindText(index + 1, value) } }
        catch (error: Exception) { statement.close(); throw error }
        return RoadRows(statement)
    }
    override fun close() = connection.close()
}
class RoadRows(private val statement: SQLiteStatement) : AutoCloseable {
    fun moveToFirst(): Boolean = statement.step()
    fun moveToNext(): Boolean = statement.step()
    fun getString(column: Int): String = statement.getText(column)
    fun getDouble(column: Int): Double = statement.getDouble(column)
    fun getLong(column: Int): Long = statement.getLong(column)
    override fun close() = statement.close()
}
