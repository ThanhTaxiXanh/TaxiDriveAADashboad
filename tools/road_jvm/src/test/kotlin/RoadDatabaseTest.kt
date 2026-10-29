import com.thanhtaxixanh.dashboard.RoadDatabase
import java.io.File
import org.junit.Assert.*
import org.junit.Test

class RoadDatabaseTest {
    private val fixture get() = File(System.getenv("ROAD_FIXTURE"))
    @Test fun nativeRtreeCanReadThePythonBuilderContract() {
        RoadDatabase.open(fixture).use { db ->
            assertEquals(1, db.version)
            db.rawQuery("PRAGMA quick_check", null).use { assertTrue(it.moveToFirst()); assertEquals("ok", it.getString(0)) }
            db.rawQuery("SELECT count(*) FROM roads_rtree", null).use { assertTrue(it.moveToFirst()); assertEquals(2L, it.getLong(0)) }
            db.rawQuery("SELECT t.way FROM roads t JOIN roads_rtree r ON r.id=t.id WHERE r.minLon<=? AND r.maxLon>=? AND r.minLat<=? AND r.maxLat>=?", arrayOf("106.195","106.193","21.287","21.285")).use {
                assertTrue(it.moveToNext()); assertEquals(100L, it.getLong(0)); assertFalse(it.moveToNext())
            }
        }
    }
    @Test fun productionConnectionsAreReadOnlyAndDoNotCreateMissingFiles() {
        RoadDatabase.open(fixture).use { db ->
            assertThrows(Exception::class.java) { db.rawQuery("DELETE FROM roads",null).use { it.moveToNext() } }
            db.rawQuery("SELECT count(*) FROM roads",null).use { assertTrue(it.moveToFirst()); assertEquals(2L,it.getLong(0)) }
        }
        val missing=File(fixture.parentFile,"must-not-create.sqlite")
        assertFalse(missing.exists())
        assertThrows(Exception::class.java) { RoadDatabase.open(missing).close() }
        assertFalse(missing.exists())
    }
}
