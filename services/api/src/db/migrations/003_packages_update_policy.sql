-- Al publicar una versión que ya generó su paquete de prueba, los paquetes se
-- regeneran: la publicación necesita poder actualizarlos (solo publicadores).
CREATE POLICY pkg_update ON packages FOR UPDATE USING (vtm_role() IN ('system','superadmin','content_admin')) WITH CHECK (vtm_role() IN ('system','superadmin','content_admin'));
