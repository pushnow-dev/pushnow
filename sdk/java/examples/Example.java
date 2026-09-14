import dev.pushnow.Client;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.PosixFilePermissions;
import org.json.JSONObject;

public class Example {
    private static void save(Path path, JSONObject value) throws Exception {
        Files.createFile(path, PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));
        Files.writeString(path, value.toString(), StandardOpenOption.WRITE);
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 1) { System.out.println("Use authorize or send"); return; }
        Path configFile = Path.of("private-config.json"), outbox = Path.of("outbox.json");
        String root = System.getenv("PUSHNOW_ROOT_FINGERPRINT");
        if (args[0].equals("authorize")) {
            Client client = new Client(Path.of("runtime/main.js"), root, null);
            JSONObject pending = client.beginAuthorization("https://api.pushnow.dev", "Java automation");
            System.out.println("Approve code: " + pending.getJSONObject("authorization").getString("user_code"));
            System.out.println("Compare sender fingerprint: " + pending.getString("fingerprint"));
            save(configFile, client.authorize(pending));
            System.out.println("Authorized. Private configuration stored locally.");
        } else if (args[0].equals("send")) {
            Client client = new Client(Path.of("runtime/main.js"), root, new JSONObject(Files.readString(configFile)));
            JSONObject envelope;
            if (Files.exists(outbox)) envelope = new JSONObject(Files.readString(outbox));
            else {
                envelope = client.prepare(new JSONObject().put("title", "Build finished").put("body", "Your artifact is ready."));
                save(outbox, envelope);
            }
            JSONObject result = client.retry(envelope);
            System.out.println("API accepted: " + result.getString("message_id") + " deduplicated: " + result.getBoolean("deduplicated"));
        } else System.out.println("Use authorize or send");
    }
}
