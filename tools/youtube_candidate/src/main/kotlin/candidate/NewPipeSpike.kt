// SPDX-License-Identifier: GPL-3.0-or-later
package candidate

import java.net.HttpURLConnection
import kotlin.system.exitProcess

private data class ProbeResult(val status: Int, val bytes: Int, val mediaSignature: Boolean)

private fun selectedBytes(raw: String): ProbeResult {
    val initial = BoundedDownloader.checkedUri(raw)
    require(initial.host == "googlevideo.com" || initial.host.endsWith(".googlevideo.com"))
    var uri = initial
    for (redirect in 0..3) {
        val connection = uri.toURL().openConnection() as HttpURLConnection
        try {
            connection.instanceFollowRedirects=false
            connection.connectTimeout=10000
            connection.readTimeout=10000
            connection.setRequestProperty("User-Agent",BoundedDownloader.USER_AGENT)
            connection.setRequestProperty("Range","bytes=0-2047")
            connection.setRequestProperty("Accept-Encoding","identity")
            val code=connection.responseCode
            if (code in setOf(301,302,303,307,308)) {
                val next=connection.getHeaderField("Location") ?: return ProbeResult(code,0,false)
                uri=BoundedDownloader.checkedUri(uri.resolve(next).toString())
                if (uri.host != "googlevideo.com" && !uri.host.endsWith(".googlevideo.com")) return ProbeResult(code,0,false)
                continue
            }
            if (code != 200 && code != 206) return ProbeResult(code,0,false)
            var read=0
            val buffer=ByteArray(2048)
            connection.inputStream.use { stream ->
                while (read<buffer.size) {
                    val count=stream.read(buffer,read,buffer.size-read)
                    if (count<0) break
                    read+=count
                }
            }
            // Positive HTTP alone can be an HTML challenge; accept an ISO BMFF
            // ftyp box or WebM EBML magic instead. This remains a byte probe.
            val mp4=read>=8 && String(buffer,4,4,Charsets.US_ASCII)=="ftyp"
            val webm=read>=4 && buffer.take(4).map { it.toInt() and 255 }==listOf(0x1a,0x45,0xdf,0xa3)
            return ProbeResult(code,read,mp4 || webm)
        } finally { connection.disconnect() }
    }
    return ProbeResult(0,0,false)
}

/** CLI intentionally emits status/counts only, never request/response bodies or URLs. */
fun main(args: Array<String>) {
    val fixture=args.firstOrNull() ?: "aqz-KE-bpKQ" // Blender Foundation public test fixture.
    var success=false
    BoundedDownloader().use { downloader ->
        try {
            val selected=NewPipeCandidate(downloader).resolve(fixture)
            for (candidate in selected.take(2)) {
                val result=try { selectedBytes(candidate.audioUrl) } catch (_: Exception) { ProbeResult(0,0,false) }
                val okay=result.status in setOf(200,206) && result.bytes>0 && result.mediaSignature
                println("NEWPIPE_SPIKE {\"version\":\"0.26.5\",\"kind\":\""+candidate.label+"\",\"height\":"+candidate.height+",\"status\":"+result.status+",\"bytes\":"+result.bytes+",\"media_signature\":"+result.mediaSignature+",\"stream_read\":"+okay+"}")
                if (okay) { success=true; break }
            }
        } catch (error: Throwable) {
            val name=error.javaClass.simpleName.replace(Regex("[^A-Za-z0-9_]"),"").take(80)
            println("NEWPIPE_SPIKE {\"version\":\"0.26.5\",\"stream_read\":false,\"error_type\":\""+name+"\"}")
        }
    }
    if (!success) exitProcess(2)
}
