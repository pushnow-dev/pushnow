package dev.pushnow;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import org.json.JSONArray;
import org.json.JSONObject;

/** Account-bound v2 SDK. Node.js 22+ and the bundled runtime are required.
 * Use one client per thread; config and pending authorization contain private keys.
 */
public final class Client {
    private final String node;
    private final Path runtime;
    private final Duration timeout;
    private JSONObject config;
    private final JSONArray requestLogs = new JSONArray();

    public Client(Path runtime, JSONObject config) {
        this(runtime, config, "node", Duration.ofSeconds(660));
    }
    public Client(Path runtime, JSONObject config, String node, Duration timeout) {
        this.runtime = runtime.toAbsolutePath();
        this.config = config; this.node = node; this.timeout = timeout;
    }
    public JSONArray requestLogs() { return new JSONArray(requestLogs.toString()); }
    private JSONObject call(String operation, JSONObject arguments) {
        JSONObject input = new JSONObject().put("operation", operation).put("config", config);
        for (String key : arguments.keySet()) input.put(key, arguments.get(key));
        Process process = null;
        JSONObject reply;
        try {
            process = new ProcessBuilder(node, runtime.toString())
                .redirectError(ProcessBuilder.Redirect.DISCARD).start();
            final Process running = process;
            CompletableFuture<byte[]> output = CompletableFuture.supplyAsync(() -> {
                try { return running.getInputStream().readAllBytes(); }
                catch (Exception e) { throw new IllegalStateException("BRIDGE_RUNTIME_FAILED"); }
            });
            CompletableFuture<Void> writer = CompletableFuture.runAsync(() -> {
                try (var stdin = running.getOutputStream()) {
                    stdin.write(input.toString().getBytes(StandardCharsets.UTF_8));
                } catch (Exception e) { throw new IllegalStateException("BRIDGE_RUNTIME_FAILED"); }
            });
            if (!process.waitFor(timeout.toMillis(), TimeUnit.MILLISECONDS) || process.exitValue() != 0)
                throw new IllegalStateException("BRIDGE_RUNTIME_FAILED");
            writer.get(5, TimeUnit.SECONDS);
            reply = new JSONObject(new String(output.get(5, TimeUnit.SECONDS), StandardCharsets.UTF_8));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt(); throw new IllegalStateException("BRIDGE_INTERRUPTED");
        } catch (Exception e) { throw new IllegalStateException("BRIDGE_RUNTIME_FAILED"); }
        finally { if (process != null && process.isAlive()) process.destroyForcibly(); }
        JSONArray logs = reply.optJSONArray("logs");
        if (logs != null) for (Object log : logs) requestLogs.put(log);
        if (!reply.optBoolean("ok")) throw new IllegalStateException(reply.getJSONObject("error").getString("code"));
        return reply.getJSONObject("data");
    }
    public JSONObject beginAccountAuthorization(String apiURL, String accessToken, String name) {
        return call("beginAccountAuthorization", new JSONObject()
            .put("apiURL", apiURL).put("accessToken", accessToken).put("name", name));
    }
    public JSONObject authorizeAccount(JSONObject pending) {
        config = call("finishAccountAuthorization", new JSONObject().put("pending", pending)); return config;
    }
    public JSONObject recipients() { return call("recipients", new JSONObject()); }
    public JSONObject prepare(JSONObject notification) { return call("prepare", new JSONObject().put("notification", notification)); }
    public JSONObject send(JSONObject notification) { return call("send", new JSONObject().put("notification", notification)); }
    public JSONObject retry(JSONObject envelope) { return call("retry", new JSONObject().put("envelope", envelope)); }
}
