package mx.securelink.backend.api;

import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class ResourceSync {
    private static final int LEASE_SECONDS = 5;
    private final JdbcTemplate db;
    private final WireGuardClient agent;
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
    private volatile long lastApplied;

    public ResourceSync(JdbcTemplate db, WireGuardClient agent) {
        this.db = db;
        this.agent = agent;
    }

    @PostConstruct void start() { scheduler.scheduleWithFixedDelay(this::refresh, 0, 1, TimeUnit.SECONDS); }
    @PreDestroy void stop() { scheduler.shutdownNow(); }
    boolean available() { return System.currentTimeMillis() - lastApplied < 5000; }

    static boolean permitted(ZonedDateTime now, int days, LocalTime start, LocalTime end) {
        int today = now.getDayOfWeek().getValue() - 1;
        LocalTime time = now.toLocalTime();
        if (!start.isBefore(end) && time.isBefore(end)) {
            return (days & (1 << ((today + 6) % 7))) != 0;
        }
        if ((days & (1 << today)) == 0 || time.isBefore(start)) return false;
        return !start.isBefore(end) || time.isBefore(end);
    }

    private void refresh() {
        Instant captured = Instant.now();
        try {
            List<List<Object>> entries = db.query("""
                SELECT DISTINCT c.clave_publica,c.direccion_ip,r.protocolo,r.puerto,r.direccion,
                       g.dias,g.inicio,g.fin,g.zona
                FROM concesion_recurso g JOIN recurso_interno r ON r.id=g.recurso_id AND r.activo=TRUE
                JOIN red_vpn n ON n.id_red=g.red_id AND n.estado='ACTIVA' AND n.bloqueo_operacion IS NULL
                JOIN miembro_red_vpn m ON m.id_red=g.red_id AND m.id_usuario=g.usuario_id AND m.estado='ACTIVO'
                    AND m.fecha_ingreso=g.membresia_desde
                JOIN usuario u ON u.id_usuario=g.usuario_id AND u.estado='ACTIVO'
                JOIN dispositivo d ON d.id_red=g.red_id AND d.id_usuario=g.usuario_id AND d.estado='ACTIVO'
                JOIN configuracion_vpn c ON c.id_dispositivo=d.id_dispositivo
                    AND c.estado_deseado='ACTIVA' AND c.estado_aplicado='ACTIVA'
                WHERE c.clave_publica IS NOT NULL AND c.direccion_ip IS NOT NULL
                LIMIT 65
                """, (rs, n) -> {
                    ZoneId zone = ZoneId.of(rs.getString(9));
                    int days = rs.getInt(6);
                    LocalTime start = LocalTime.parse(rs.getString(7));
                    LocalTime end = LocalTime.parse(rs.getString(8));
                    if (!permitted(captured.atZone(zone), days, start, end)) return List.<Object>of();
                    // Check minute boundaries and zone transitions at second resolution.
                    Instant expires = captured.plusSeconds(LEASE_SECONDS);
                    for (Instant t = captured.truncatedTo(java.time.temporal.ChronoUnit.SECONDS).plusSeconds(1);
                         t.isBefore(expires); t=t.plusSeconds(1)) {
                        if (!permitted(t.atZone(zone), days, start, end)) { expires=t; break; }
                    }
                    return List.<Object>of(rs.getString(1), rs.getString(2), rs.getString(3),
                        rs.getInt(4), rs.getString(5), expires.toEpochMilli());
                });
            // The agent socket accepts an 8192-byte request. Fail closed if over capacity.
            if (entries.size() > 64) {
                agent.call(Map.of("op", "resource_sync", "capturedAt", captured.toEpochMilli(), "entries", List.of()));
                lastApplied = 0;
                return;
            }
            agent.call(Map.of("op", "resource_sync", "capturedAt", captured.toEpochMilli(),
                "entries", entries.stream().filter(row -> !row.isEmpty()).toList()));
            lastApplied = captured.toEpochMilli();
        } catch (RuntimeException failure) {
            lastApplied = 0;
        }
    }
}
