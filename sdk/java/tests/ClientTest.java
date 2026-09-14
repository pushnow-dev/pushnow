import dev.pushnow.Client;
import java.nio.file.Path;
import java.time.Duration;
import org.json.JSONObject;

public class ClientTest {
    public static void main(String[] args) {
        Client tokenOnly = new Client(Path.of("runtime/main.js"), "0".repeat(64), new JSONObject().put("source_key", "private"));
        try { tokenOnly.recipients(); throw new AssertionError("Token-only accepted"); }
        catch (IllegalStateException e) { if (!e.getMessage().equals("E2EE_CONFIG_REQUIRED")) throw e; }
        if (tokenOnly.requestLogs().length() != 0) throw new AssertionError("Unexpected request");
        Client missing = new Client(Path.of("runtime/main.js"), "", null, "/missing/node", Duration.ofSeconds(1));
        try { missing.recipients(); throw new AssertionError("Missing runtime accepted"); }
        catch (IllegalStateException e) { if (!e.getMessage().equals("BRIDGE_RUNTIME_FAILED")) throw e; }
        System.out.println("PASS Java token-only rejection and redacted runtime errors");
    }
}
