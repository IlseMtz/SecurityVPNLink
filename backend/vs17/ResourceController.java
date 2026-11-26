package mx.securelink.backend.api;

import java.time.*;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController
@RequestMapping("/api/v1")
public class ResourceController {
    private final JdbcTemplate db;
    private final ManagementSupport permissions;
    private final ResourceSync sync;

    public ResourceController(JdbcTemplate db, ManagementSupport permissions, ResourceSync sync) {
        this.db = db;
        this.permissions = permissions;
        this.sync = sync;
    }

    public record Resource(@NotBlank @Size(max=120) String nombre,
                           @NotBlank String direccion,
                           @NotNull @Pattern(regexp="TCP|UDP") String protocolo,
                           @NotNull @Min(1) @Max(65535) Integer puerto,
                           @NotNull Boolean activo) {}

    public record Grant(@Positive long usuarioId, @Positive long recursoId,
                        @Min(1) @Max(127) int dias,
                        @NotNull @Pattern(regexp="(?:[01][0-9]|2[0-3]):[0-5][0-9]:00") String inicio,
                        @NotNull @Pattern(regexp="(?:[01][0-9]|2[0-3]):[0-5][0-9]:00") String fin,
                        @NotBlank @Size(max=64) String zona) {}

    private long actor(Authentication authentication) { return Long.parseLong(authentication.getName()); }

    @GetMapping("/administracion/recursos")
    public List<Map<String, Object>> resources(Authentication authentication) {
        permissions.global(actor(authentication));
        return db.queryForList("SELECT * FROM recurso_interno ORDER BY id");
    }

    @PostMapping("/administracion/recursos")
    @Transactional
    public void create(Authentication authentication, @Valid @RequestBody Resource resource) {
        save(authentication, null, resource);
    }

    @PostMapping("/administracion/recursos/{id}")
    @Transactional
    public void edit(Authentication authentication, @PathVariable long id,
                     @Valid @RequestBody Resource resource) {
        save(authentication, id, resource);
    }

    private void save(Authentication authentication, Long id, Resource r) {
        long user = actor(authentication);
        permissions.global(user);
        if (!r.direccion().matches("172\\.30\\.77\\.(?:[2-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Dirección fuera del segmento de laboratorio");
        }
        if (id == null) {
            db.update("INSERT INTO recurso_interno(nombre,direccion,protocolo,puerto,activo) VALUES (?,?,?,?,?)",
                      r.nombre().strip(), r.direccion(), r.protocolo(), r.puerto(), r.activo());
            id = db.queryForObject("SELECT id FROM recurso_interno WHERE direccion=? AND protocolo=? AND puerto=?",
                                   Long.class, r.direccion(), r.protocolo(), r.puerto());
        } else {
            var stored = db.queryForList("SELECT id FROM recurso_interno WHERE id=? FOR UPDATE", Long.class, id);
            if (stored.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
            // Changing a destination or disabling it invalidates the corresponding consent.
            db.update("""
                DELETE FROM concesion_recurso WHERE recurso_id=? AND EXISTS (
                    SELECT 1 FROM recurso_interno WHERE id=? AND
                     (direccion<>? OR protocolo<>? OR puerto<>? OR ?=FALSE))
                """, id, id, r.direccion(), r.protocolo(), r.puerto(), r.activo());
            db.update("UPDATE recurso_interno SET nombre=?,direccion=?,protocolo=?,puerto=?,activo=? WHERE id=?",
                      r.nombre().strip(), r.direccion(), r.protocolo(), r.puerto(), r.activo(), id);
        }
        permissions.audit(user, "RECURSO_GUARDADO", "RECURSO", id.toString(), null);
    }

    @GetMapping("/redes/{red}/recursos")
    public Map<String, Object> policy(Authentication authentication, @PathVariable long red) {
        permissions.owner(red, actor(authentication), false);
        return Map.of("recursos", db.queryForList("SELECT * FROM recurso_interno WHERE activo=TRUE ORDER BY id"),
            "concesiones", db.query("""
                SELECT g.usuario_id,g.recurso_id,g.dias,g.inicio,g.fin,g.zona FROM concesion_recurso g
                JOIN miembro_red_vpn m ON m.id_red=g.red_id AND m.id_usuario=g.usuario_id
                  AND m.fecha_ingreso=g.membresia_desde AND m.estado='ACTIVO'
                WHERE g.red_id=? ORDER BY g.usuario_id,g.recurso_id
                """, (rs, n) -> new Grant(rs.getLong(1), rs.getLong(2), rs.getInt(3),
                    rs.getString(4), rs.getString(5), rs.getString(6)), red),
            "agenteDisponible", sync.available());
    }

    @PostMapping("/redes/{red}/recursos/concesiones")
    @Transactional
    public void grant(Authentication authentication, @PathVariable long red, @Valid @RequestBody Grant g) {
        long user = actor(authentication);
        permissions.owner(red, user, true);
        try { ZoneId.of(g.zona()); } catch (DateTimeException invalid) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Zona horaria inválida");
        }
        var resources = db.queryForList("SELECT id FROM recurso_interno WHERE id=? AND activo=TRUE FOR UPDATE",
                                        Long.class, g.recursoId());
        var eligible = db.query("""
            SELECT m.fecha_ingreso FROM miembro_red_vpn m JOIN usuario u ON u.id_usuario=m.id_usuario
            WHERE m.id_red=? AND m.id_usuario=? AND m.estado='ACTIVO' AND u.estado='ACTIVO' FOR UPDATE
            """, (rs, n) -> rs.getObject(1, LocalDateTime.class), red, g.usuarioId());
        if (resources.isEmpty() || eligible.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Recurso o miembro inactivo");
        }
        db.update("""
            INSERT INTO concesion_recurso(red_id,usuario_id,recurso_id,dias,inicio,fin,zona,membresia_desde)
            VALUES (?,?,?,?,?,?,?,?) AS nueva
            ON DUPLICATE KEY UPDATE dias=nueva.dias,inicio=nueva.inicio,fin=nueva.fin,zona=nueva.zona,
                membresia_desde=nueva.membresia_desde
            """, red, g.usuarioId(), g.recursoId(), g.dias(), g.inicio(), g.fin(), g.zona(), eligible.getFirst());
        permissions.audit(user, "RECURSO_AUTORIZADO", "CONCESION", g.usuarioId()+":"+g.recursoId(), red);
    }

    @PostMapping("/redes/{red}/recursos/{resource}/usuarios/{user}/retiro")
    @Transactional
    public void remove(Authentication authentication, @PathVariable long red,
                       @PathVariable long resource, @PathVariable long user) {
        long operator = actor(authentication);
        permissions.owner(red, operator, true);
        if (db.update("DELETE FROM concesion_recurso WHERE red_id=? AND usuario_id=? AND recurso_id=?", red, user, resource) > 0) {
            permissions.audit(operator, "RECURSO_RETIRADO", "CONCESION", user+":"+resource, red);
        }
    }
}
