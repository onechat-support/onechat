-- ONEchat migración v1.5: permisos del rol de servicio
-- (las tablas creadas por SQL no lo incluían; la función de acceso
-- por nickname lo necesita para resolver el correo internamente)
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
