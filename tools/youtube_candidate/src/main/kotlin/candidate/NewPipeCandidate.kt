// SPDX-License-Identifier: GPL-3.0-or-later
// Scratch adapter, own implementation against NewPipeExtractor v0.26.5 APIs.
package candidate

import org.schabi.newpipe.extractor.MediaFormat
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.localization.ContentCountry
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.stream.AudioStream
import org.schabi.newpipe.extractor.stream.DeliveryMethod
import org.schabi.newpipe.extractor.stream.Stream
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.VideoStream
import org.schabi.newpipe.extractor.utils.ExtractorLogger
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/** Signed URLs are deliberately absent from toString and are never persisted. */
class StreamCandidate(
    val audioUrl: String,
    val videoUrl: String?,
    val muxed: Boolean,
    val label: String,
    val height: Int = 0
) {
    override fun toString() = "StreamCandidate(kind=" + label + ",height=" + height + ")"
}

class NewPipeCandidate(private val downloader: BoundedDownloader) {
    companion object { private val extractorLock = ReentrantLock() }
    fun resolve(id: String): List<StreamCandidate> = extractorLock.withLock {
        require(id.matches(Regex("[A-Za-z0-9_-]{11}")))
        // NewPipe global initialization is serialized; no downloader/logger can be
        // swapped while another extraction is active. Default logger is empty.
        ExtractorLogger.setLogger(null)
        NewPipe.init(downloader, Localization("vi", "VN"), ContentCountry("VN"))
        val info = StreamInfo.getInfo("https://www.youtube.com/watch?v=" + id)
        val choices = mutableListOf<StreamCandidate>()
        val muxed = info.videoStreams.filter {
            playable(it) && !it.isVideoOnly && it.format == MediaFormat.MPEG_4 && resolution(it) in 1..360
        }.sortedByDescending { resolution(it) }
        // One progressive MP4 source is the minimal fallback, avoiding two requests
        // from one Android manifest. The native player must still disable its video
        // track unless the existing GPS/parked-video policy allows showing it.
        muxed.firstOrNull()?.let { choices.add(StreamCandidate(it.content,null,true,"muxed_mp4",resolution(it))) }
        val audio = info.audioStreams.filter { playable(it) }.sortedWith(
            compareBy<AudioStream> { if (it.format == MediaFormat.M4A) 0 else 1 }
                .thenByDescending { it.averageBitrate }
        )
        audio.take(2).forEach { choices.add(StreamCandidate(it.content,null,false,"audio_only")) }
        check(choices.isNotEmpty()) { "No compatible progressive streams" }
        choices
    }
    private fun playable(stream: Stream): Boolean {
        if (!stream.isUrl || stream.deliveryMethod != DeliveryMethod.PROGRESSIVE_HTTP) return false
        return try {
            val uri = BoundedDownloader.checkedUri(stream.content)
            uri.host == "googlevideo.com" || uri.host.endsWith(".googlevideo.com")
        } catch (_: Exception) { false }
    }
    private fun resolution(stream: VideoStream): Int = Regex("^([0-9]+)p").find(stream.resolution)?.groupValues?.get(1)?.toIntOrNull() ?: 0
}
