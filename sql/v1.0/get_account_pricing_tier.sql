-- =====================================================
-- get_account_pricing_tier
-- Atlas Project -- 2026-07-22
--
-- Para qué sirve: dado un account_id, regresa el CÓDIGO del nivel de
-- precio de esa cuenta (ej. 'PUBLICO_GENERAL', 'LA_VALISE') para que el
-- flujo de n8n pueda llamar a quote_service_price sin tener que repetir
-- el join a catalog_items en cada paso. Si la cuenta no tiene nivel
-- asignado (no debería pasar después de correr pricing_engine_v1.sql,
-- pero por si acaso), regresa NULL en vez de fallar.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.get_account_pricing_tier(p_account_id UUID)
 RETURNS TEXT
 LANGUAGE sql
AS $function$
    SELECT ci.code
      FROM accounts a
      JOIN catalog_items ci ON ci.id = a.pricing_client_tier_id
     WHERE a.id = p_account_id;
$function$;


CREATE OR REPLACE FUNCTION public.get_account_pricing_tier(p_account_id UUID)
 RETURNS TEXT
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.get_account_pricing_tier(p_account_id);
$function$;
