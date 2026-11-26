ALTER TABLE red_vpn
  ADD COLUMN limite_equipos_usuario TINYINT UNSIGNED NOT NULL DEFAULT 5,
  ADD CONSTRAINT ck_red_limite_equipos_usuario
    CHECK (limite_equipos_usuario BETWEEN 1 AND 5);
