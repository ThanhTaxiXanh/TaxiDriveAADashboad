import com.thanhtaxixanh.dashboard.MediaPolicy
import org.junit.Assert.*
import org.junit.Test

class MediaPolicyTest {
    @Test fun movingOrUncertainLocationCannotShowVideo() {
        assertTrue(MediaPolicy.videoAllowed(true,1000,5.0,0.0))
        assertTrue(MediaPolicy.videoAllowed(true,10000,30.0,4.99))
        for (speed in listOf(-1.0,5.0,60.0,Double.NaN,Double.POSITIVE_INFINITY)) assertFalse(MediaPolicy.videoAllowed(true,1000,5.0,speed))
        for (age in listOf(-1L,10001L,30000L)) assertFalse(MediaPolicy.videoAllowed(true,age,5.0,0.0))
        assertFalse(MediaPolicy.videoAllowed(false,1000,5.0,0.0))
        assertFalse(MediaPolicy.videoAllowed(true,1000,50.0,0.0))
        assertFalse(MediaPolicy.videoAllowed(true,1000,Double.NaN,0.0))
    }
    @Test fun positionUsesElapsedTimeAndStopsAtDuration() {
        assertEquals(15000L,MediaPolicy.position(5000,1000,11000,1f,true,60000))
        assertEquals(5000L,MediaPolicy.position(5000,1000,11000,1f,false,60000))
        assertEquals(60000L,MediaPolicy.position(59000,1000,11000,1f,true,60000))
        assertEquals(5000L,MediaPolicy.position(5000,11000,1000,1f,true,60000))
    }
}
