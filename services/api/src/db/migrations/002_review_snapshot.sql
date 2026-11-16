-- Foto del contenido al enviarlo a revisión: permite mostrar al revisor las
-- diferencias si el autor lo modifica durante la revisión (y reiniciar la lista).
ALTER TABLE content_items ADD COLUMN submitted_data jsonb;
ALTER TABLE content_items ADD COLUMN submitted_at timestamptz;
-- Renovación automática en la tienda de pruebas.
ALTER TABLE subscriptions ADD COLUMN auto_renew boolean NOT NULL DEFAULT true;
ALTER TABLE subscriptions ADD COLUMN expiry_notice_pending boolean NOT NULL DEFAULT false;
