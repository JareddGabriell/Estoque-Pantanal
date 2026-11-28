package app.beverageinventory.api;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.util.Map;

/**
 * Lightweight connectivity check used by the mobile app
 * to decide whether the server is reachable before syncing.
 */
@Path("/api/ping")
public class PingResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> ping() {
        return Map.of(
                "status", "ok",
                "serverTime", Instant.now().toString()
        );
    }
}
