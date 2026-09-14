import dev.pushnow.Client;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;
import org.json.JSONArray;

public class Probe {
    public static void main(String[] args) throws Exception {
        JSONObject input = new JSONObject(new String(System.in.readAllBytes(), StandardCharsets.UTF_8));
        Client client = new Client(Path.of("runtime/main.js"), null);
        JSONObject pending = client.beginAccountAuthorization(input.getString("apiURL"), input.getString("accessToken"), "Java integration");
        client.authorizeAccount(pending);
        JSONObject directory = client.recipients();
        JSONObject envelope = client.prepare(input.getJSONObject("notification"));
        JSONObject first = client.retry(envelope), second = client.retry(envelope);
        JSONObject sent = client.send(new JSONObject().put("title", "Immediate Java").put("body", "Second message").put("sound", "silent"));
        JSONObject defaultEnvelope = client.prepare(new JSONObject().put("title", "Default sound").put("sound", "default"));
        JSONObject omittedSoundEnvelope = client.prepare(new JSONObject().put("title", "Omitted sound"));
        JSONArray errors = new JSONArray();
        JSONObject[] invalid = {
            new JSONObject().put("title", "Unsupported").put("sound", "custom"),
            new JSONObject().put("title", "Foreign").put("deviceIds", new JSONArray().put("00000000-0000-0000-0000-000000000000"))
        };
        for (JSONObject n : invalid) {
            try { client.prepare(n); throw new AssertionError("Invalid notification accepted"); }
            catch (IllegalStateException e) { errors.put(e.getMessage()); }
        }
        try { client.retry(new JSONObject(envelope.toString()).put("sound", "silent")); throw new AssertionError("Changed sound accepted"); }
        catch (IllegalStateException e) { errors.put(e.getMessage()); }
        System.out.print(new JSONObject().put("envelope", envelope).put("first", first).put("second", second).put("sent", sent)
            .put("defaultEnvelope", defaultEnvelope).put("omittedSoundEnvelope", omittedSoundEnvelope)
            .put("deviceCount", directory.getJSONArray("devices").length()).put("errors", errors).put("logs", client.requestLogs()));
    }
}
