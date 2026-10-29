// SPDX-License-Identifier: GPL-3.0-or-later
// Scratch candidate only; not linked into the dashboard APK.
package candidate

import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URI
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.zip.GZIPInputStream

/** No cookie jar, account import, proxy selection, disk cache or request logging. */
class BoundedDownloader : Downloader(), AutoCloseable {
    companion object {
        const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
        private const val BODY_LIMIT = 16 * 1024 * 1024
        private val HOST_SUFFIXES = listOf("youtube.com", "googlevideo.com", "googleapis.com", "google.com", "ytimg.com", "ggpht.com")
        fun checkedUri(raw: String): URI {
            val uri = URI(raw)
            val host = uri.host?.lowercase(Locale.ROOT) ?: throw IOException("Missing host")
            require(uri.scheme == "https" && uri.rawUserInfo == null && (uri.port == -1 || uri.port == 443))
            require(HOST_SUFFIXES.any { host == it || host.endsWith("." + it) })
            return uri
        }
        private fun readBounded(input: InputStream, limit: Int): ByteArray {
            val result = ByteArrayOutputStream()
            val buffer = ByteArray(16384)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (count > limit - result.size()) throw IOException("Extractor response exceeds limit")
                result.write(buffer, 0, count)
            }
            return result.toByteArray()
        }
    }
    private val active = ConcurrentHashMap.newKeySet<HttpURLConnection>()
    @Volatile private var closed = false

    override fun execute(request: Request): Response {
        check(!closed) { "Downloader closed" }
        var uri = checkedUri(request.url())
        var method = request.httpMethod().uppercase(Locale.ROOT)
        require(method in setOf("GET", "HEAD", "POST"))
        var body = request.dataToSend()
        for (redirect in 0..5) {
            if (closed || Thread.currentThread().isInterrupted) throw IOException("Extractor cancelled")
            val connection = uri.toURL().openConnection() as HttpURLConnection
            active.add(connection)
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 10000
                connection.readTimeout = 15000
                connection.requestMethod = method
                connection.useCaches = false
                connection.setRequestProperty("User-Agent", USER_AGENT)
                connection.setRequestProperty("Accept-Encoding", "identity")
                for ((name, values) in request.headers()) {
                    if (name.equals("Cookie", true) || name.equals("Authorization", true)) {
                        // Library-generated ephemeral consent/visitor cookies can be required.
                        // No persistent/account cookie source is supplied by this downloader.
                    }
                    values.forEachIndexed { index, value ->
                        if (index == 0) connection.setRequestProperty(name, value)
                        else connection.addRequestProperty(name, value)
                    }
                }
                if (method == "POST") {
                    val payload = body ?: ByteArray(0)
                    require(payload.size <= 1024 * 1024)
                    connection.doOutput = true
                    connection.setFixedLengthStreamingMode(payload.size)
                    connection.outputStream.use { it.write(payload) }
                }
                val code = connection.responseCode
                if (code == 429 || code == 503 && connection.getHeaderField("Location")?.contains("sorry") == true) {
                    throw ReCaptchaException("Server rejected the extractor request", uri.toString())
                }
                if (code in setOf(301,302,303,307,308)) {
                    if (redirect == 5) throw IOException("Too many redirects")
                    val location = connection.getHeaderField("Location") ?: throw IOException("Missing redirect")
                    uri = checkedUri(uri.resolve(location).toString())
                    if (code == 303 || ((code == 301 || code == 302) && method == "POST")) {
                        method = "GET"; body = null
                    }
                    continue
                }
                val headers: Map<String, List<String>> = connection.headerFields.entries.mapNotNull { entry ->
                    val key = entry.key ?: return@mapNotNull null
                    key to entry.value.toList()
                }.toMap()
                val bytes = if (method == "HEAD") ByteArray(0) else {
                    val raw = if (code < 400) connection.inputStream else connection.errorStream
                    if (raw == null) ByteArray(0) else raw.use { original ->
                        val stream = if (connection.contentEncoding.equals("gzip", true)) GZIPInputStream(original) else original
                        readBounded(stream, BODY_LIMIT)
                    }
                }
                val response = bytes.toString(Charsets.UTF_8)
                if (uri.path.startsWith("/sorry/")) throw ReCaptchaException("Server challenge", uri.toString())
                return Response(code, connection.responseMessage ?: "", headers, response, uri.toString())
            } finally {
                active.remove(connection)
                connection.disconnect()
            }
        }
        throw IOException("Redirect failed")
    }
    override fun close() {
        closed = true
        active.toList().forEach { it.disconnect() }
        active.clear()
    }
}
