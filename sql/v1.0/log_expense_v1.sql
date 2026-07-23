-- =====================================================
-- FASE 1 -- Registrar un gasto (chofer o prueba de administrador)
-- Atlas Project -- 2026-07-23
--
-- Requiere haber corrido antes:
--   sql/migrations/20260723_fase1_expense_categories_status.sql
--
-- p_payload:
--   category_name   (obligatorio, debe existir en expense_categories.name)
--   amount          (obligatorio)
--   description     (opcional)
--   driver_id       (opcional -- null cuando lo registra un administrador
--                     de prueba, no un chofer real)
--   created_by      (person_id de quien lo registra -- chofer o admin)
--   currency_code   (opcional, default 'MXN')
--
-- Devuelve JSON enriquecido (ADS-007), nunca solo TRUE/FALSE.
-- =====================================================

CREATE OR REPLACE FUNCTION atlas.log_expense(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_category_id UUID;
    v_expense_id UUID;
    v_amount NUMERIC;
    v_category_name TEXT;
BEGIN
    v_category_name := trim(p_payload->>'category_name');
    v_amount := NULLIF(p_payload->>'amount', '')::numeric;

    IF v_category_name IS NULL OR v_category_name = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'se requiere category_name');
    END IF;

    IF v_amount IS NULL OR v_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'el monto debe ser mayor a cero');
    END IF;

    SELECT id INTO v_category_id
    FROM expense_categories
    WHERE name = v_category_name
    LIMIT 1;

    IF v_category_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'no existe la categoría de gasto "' || v_category_name || '"'
        );
    END IF;

    INSERT INTO expenses(
        expense_category_id,
        driver_id,
        amount,
        currency_id,
        expense_datetime,
        description,
        status_id,
        created_by
    )
    VALUES(
        v_category_id,
        NULLIF(p_payload->>'driver_id', '')::uuid,
        v_amount,
        atlas.catalog('CURRENCY', COALESCE(p_payload->>'currency_code', 'MXN')),
        now(),
        p_payload->>'description',
        atlas.catalog('EXPENSE_STATUS', 'REGISTRADO'),
        NULLIF(p_payload->>'created_by', '')::uuid
    )
    RETURNING id INTO v_expense_id;

    RETURN jsonb_build_object(
        'success', true,
        'expense_id', v_expense_id
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.log_expense(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
SELECT atlas.log_expense(p_payload);
$function$;
