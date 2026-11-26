CREATE TABLE IF NOT EXISTS recurso_interno (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    direccion VARCHAR(15) CHARACTER SET ascii NOT NULL,
    protocolo ENUM('TCP','UDP') NOT NULL,
    puerto INT UNSIGNED NOT NULL CHECK (puerto BETWEEN 1 AND 65535),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_recurso_destino (direccion, protocolo, puerto)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS concesion_recurso (
    red_id BIGINT UNSIGNED NOT NULL,
    usuario_id BIGINT UNSIGNED NOT NULL,
    recurso_id BIGINT NOT NULL,
    dias INT UNSIGNED NOT NULL CHECK (dias BETWEEN 1 AND 127),
    inicio TIME NOT NULL,
    fin TIME NOT NULL,
    zona VARCHAR(64) CHARACTER SET ascii NOT NULL,
    membresia_desde DATETIME(6) NOT NULL,
    PRIMARY KEY (red_id, usuario_id, recurso_id),
    FOREIGN KEY (red_id, usuario_id) REFERENCES miembro_red_vpn(id_red, id_usuario),
    FOREIGN KEY (recurso_id) REFERENCES recurso_interno(id)
) ENGINE=InnoDB;

INSERT INTO recurso_interno(nombre, direccion, protocolo, puerto)
VALUES ('Laboratorio HTTP', '172.30.77.10', 'TCP', 80)
ON DUPLICATE KEY UPDATE direccion = recurso_interno.direccion;
