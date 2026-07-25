-- =====================================================
-- FASE 6 -- Directorio de clientes (CATALOGO_.xlsx, hoja "CLIENTES")
-- Atlas Project -- 2026-07-24 (v2 -- corrige error de teléfono duplicado)
--
-- CORRECCIÓN sobre la versión anterior: el primer intento falló con
-- "duplicate key value violates unique constraint uq_people_phone"
-- porque "BESTUR" (Efraín Méndez López) y "Operadora Turística
-- Bestur" en realidad comparten el MISMO contacto real (Efraín
-- Méndez, mismo teléfono y correo) -- y `people.phone`/`people.email`
-- son columnas únicas. Mismo caso con "Alejandra" (contacto de Eco
-- Turistic y de Rodsega/José Luis Rodríguez).
--
-- Esta versión busca primero si ya existe una persona con ese
-- teléfono o correo antes de crear una nueva -- si existe, reutiliza
-- esa misma persona y solo agrega un contacto nuevo enlazándola a la
-- cuenta adicional (una persona sí puede ser contacto de varias
-- cuentas). Es seguro volver a correr todo el archivo desde el
-- principio -- lo que ya se había creado en el primer intento se
-- detecta y no se duplica.
--
-- Un caso más que apareció al revisar todos los teléfonos/correos:
-- "Leandro Delgado" (cliente individual) tenía el mismo correo que
-- "Leticia", la contacto de Viajes San Miguel (g7sanmigueltours@
-- gmail.com) -- pero son dos personas distintas (nombres distintos),
-- así que aquí NO los fusioné -- solo dejé el correo de Leandro en
-- blanco (con una nota) para no violar el campo único, ya que ese
-- correo ya le pertenece a Leticia en el sistema. Si Leandro tiene su
-- propio correo, dímelo y se lo agrego.
--
-- Contexto original: 52 clientes reales (hoteles, tour operators,
-- agencias y algunos individuos) que le mandan reservaciones a la
-- empresa. Esto alimenta accounts/organizations/people/contacts para
-- que el correo entrante pueda reconocer automáticamente de qué
-- cliente se trata.
--
-- Clasifiqué cada renglón como ORGANIZATION o INDIVIDUAL según si
-- traía una Razón Social real / se ve claramente como un negocio, o
-- si es el nombre de una persona sin negocio declarado.
--
-- El RFC genérico "XAXX010101000" no se guardó como si fuera un RFC
-- real -- se dejó en blanco para esos casos. No hay columnas
-- dedicadas para RFC/dirección en `organizations` todavía, así que
-- por ahora quedan documentadas en `notes`.
--
-- La identidad de cada organización para evitar duplicados en un
-- re-run es (commercial_name + legal_name) juntos -- "BESTUR" queda
-- como DOS organizaciones separadas (cuentas distintas), compartiendo
-- solo el mismo contacto humano.
--
-- IMPORTANTE -- pendiente manual: "HOTEL VILLA SANTA MONICA" y
-- "LA VALISE" son los mismos nombres de los niveles de precio
-- VILLA_SANTA_MONICA / LA_VALISE ya cargados en pricing_engine_v1.sql.
-- Esta migración NO les asigna el nivel especial automáticamente --
-- revisar duplicados primero (ver ejemplo al final del archivo).
-- =====================================================


--------------------------------------------------------
-- 1) ORGANIZACIONES (37) + sus cuentas + contacto principal
--------------------------------------------------------

-- HOTEL CASA DELPHINE (AMANDA KEIDAN)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'AMANDA KEIDAN', 'HOTEL CASA DELPHINE',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: KEAM771014733 | Dirección: CALZADA DE LA PRESA 69 CENTRO SAN MIGUEL DE ALLENDE C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL CASA DELPHINE' AND o.legal_name IS NOT DISTINCT FROM 'AMANDA KEIDAN'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL CASA DELPHINE' AND legal_name IS NOT DISTINCT FROM 'AMANDA KEIDAN'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'AMANDA KEIDAN' IS NOT NULL
      AND (
          ('52 55 4738 6267' IS NOT NULL AND phone = '52 55 4738 6267')
          OR ('admin@casadelphine.com' IS NOT NULL AND email = 'admin@casadelphine.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'AMANDA KEIDAN', '52 55 4738 6267', 'admin@casadelphine.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'AMANDA KEIDAN' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- VIÑEDO SAN MIGUEL (BODEGA DE VINO SAN MIGUEL DE ALLENDE)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'BODEGA DE VINO SAN MIGUEL DE ALLENDE', 'VIÑEDO SAN MIGUEL',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: BVS1708098A4 | Dirección: ADOLFO LOPEZ MATEOS, LOS GAVILANES , SAN MIGUEL DE ALLENDE GTO C.P. 37270',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'VIÑEDO SAN MIGUEL' AND o.legal_name IS NOT DISTINCT FROM 'BODEGA DE VINO SAN MIGUEL DE ALLENDE'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'VIÑEDO SAN MIGUEL' AND legal_name IS NOT DISTINCT FROM 'BODEGA DE VINO SAN MIGUEL DE ALLENDE'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'CYNTHIA' IS NOT NULL
      AND (
          ('52 477 289 1368' IS NOT NULL AND phone = '52 477 289 1368')
          OR ('eventos@vinedosanmiguel.com.mx' IS NOT NULL AND email = 'eventos@vinedosanmiguel.com.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'CYNTHIA', '52 477 289 1368', 'eventos@vinedosanmiguel.com.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'CYNTHIA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- DOS BUHOS (COMERCIALIZADORA DOS BUHOS)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'COMERCIALIZADORA DOS BUHOS', 'DOS BUHOS',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: CDB201214N74 | Dirección: CARRETERA 111 SAN MIGUEL DE ALLENDE-QUERETARO C.P. 37884',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'DOS BUHOS' AND o.legal_name IS NOT DISTINCT FROM 'COMERCIALIZADORA DOS BUHOS'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'DOS BUHOS' AND legal_name IS NOT DISTINCT FROM 'COMERCIALIZADORA DOS BUHOS'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('52 415 124 7583' IS NOT NULL AND phone = '52 415 124 7583')
          OR ('facturacion@dosbuhos.com' IS NOT NULL AND email = 'facturacion@dosbuhos.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '52 415 124 7583', 'facturacion@dosbuhos.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- SECTUR (CONSEJO DE PROMOCION TURISTICA DE MEXICO S.A. DE C.V.)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'CONSEJO DE PROMOCION TURISTICA DE MEXICO S.A. DE C.V.', 'SECTUR',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: CPT991022DE7 | Dirección: VIADUCTO #105, ESCANDON, DEL. MIGUEL HIDALGO,CDMX C.P. 11800',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'SECTUR' AND o.legal_name IS NOT DISTINCT FROM 'CONSEJO DE PROMOCION TURISTICA DE MEXICO S.A. DE C.V.'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'SECTUR' AND legal_name IS NOT DISTINCT FROM 'CONSEJO DE PROMOCION TURISTICA DE MEXICO S.A. DE C.V.'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          (NULL IS NOT NULL AND phone = NULL)
          OR ('pherrera@visitmexico.com' IS NOT NULL AND email = 'pherrera@visitmexico.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, NULL, 'pherrera@visitmexico.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HACIENDA ARCANGELES (CORPORATIVO VELA, S DE RL)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'CORPORATIVO VELA, S DE RL', 'HACIENDA ARCANGELES',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: CVE110217CB6 | Dirección: REAL DEL CONDE 20, ARCOS DE SAN MIGUEL,  SAN MIGUEL DE ALLENDE, GTO C.P. 37740',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HACIENDA ARCANGELES' AND o.legal_name IS NOT DISTINCT FROM 'CORPORATIVO VELA, S DE RL'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HACIENDA ARCANGELES' AND legal_name IS NOT DISTINCT FROM 'CORPORATIVO VELA, S DE RL'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('52 415 140 0656' IS NOT NULL AND phone = '52 415 140 0656')
          OR ('info_hla@fhb.com.mx' IS NOT NULL AND email = 'info_hla@fhb.com.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '52 415 140 0656', 'info_hla@fhb.com.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- EDYEN TRANSPORTES (EDYEN TRANSPORTES SA DE CV)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'EDYEN TRANSPORTES SA DE CV', 'EDYEN TRANSPORTES',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: ETR091112GP6 | Dirección: INSURGENTES SUR 1180 INT 804, TLACOQUEMÉCATL DEL VALLE, DELEG. BENITO JUÁREZ, CDMX C.P. 32000',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'EDYEN TRANSPORTES' AND o.legal_name IS NOT DISTINCT FROM 'EDYEN TRANSPORTES SA DE CV'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'EDYEN TRANSPORTES' AND legal_name IS NOT DISTINCT FROM 'EDYEN TRANSPORTES SA DE CV'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('55 2454 3800' IS NOT NULL AND phone = '55 2454 3800')
          OR ('victorh.garcia@edyen.com' IS NOT NULL AND email = 'victorh.garcia@edyen.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '55 2454 3800', 'victorh.garcia@edyen.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- BESTUR (EFRAIN MENDEZ LOPEZ)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'EFRAIN MENDEZ LOPEZ', 'BESTUR',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: MELE790622JV9 | Dirección: JUAN DE DIOS PEZA 26, COLONIA GUADALUPE, SAN MIGUEL DE ALLENDE , GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'BESTUR' AND o.legal_name IS NOT DISTINCT FROM 'EFRAIN MENDEZ LOPEZ'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'BESTUR' AND legal_name IS NOT DISTINCT FROM 'EFRAIN MENDEZ LOPEZ'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'EFRAIN MENDEZ' IS NOT NULL
      AND (
          ('52 415 105 5290' IS NOT NULL AND phone = '52 415 105 5290')
          OR ('efrix_22@hotmail.com' IS NOT NULL AND email = 'efrix_22@hotmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'EFRAIN MENDEZ', '52 415 105 5290', 'efrix_22@hotmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'EFRAIN MENDEZ' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- EL CHARCO DEL INGENIO
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'EL CHARCO DEL INGENIO', 'EL CHARCO DEL INGENIO',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: CIN9811186I7 | Dirección: JESUS 32 , CENTRO, SAN MIGUEL DE ALLENDE, GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'EL CHARCO DEL INGENIO' AND o.legal_name IS NOT DISTINCT FROM 'EL CHARCO DEL INGENIO'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'EL CHARCO DEL INGENIO' AND legal_name IS NOT DISTINCT FROM 'EL CHARCO DEL INGENIO'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('(415) 154-4715' IS NOT NULL AND phone = '(415) 154-4715')
          OR ('charcodelingenio@gmail.com' IS NOT NULL AND email = 'charcodelingenio@gmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '(415) 154-4715', 'charcodelingenio@gmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL FHB (FIBRA H BOUTIQUE)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'FIBRA H BOUTIQUE', 'HOTEL FHB',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: PLA101217BH2 | Dirección: PORTAL, CENTRO, SAN MIGUEL DE ALLENDE GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL FHB' AND o.legal_name IS NOT DISTINCT FROM 'FIBRA H BOUTIQUE'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL FHB' AND legal_name IS NOT DISTINCT FROM 'FIBRA H BOUTIQUE'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('415 151 1016' IS NOT NULL AND phone = '415 151 1016')
          OR ('ventas1@fhb.com.mx' IS NOT NULL AND email = 'ventas1@fhb.com.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '415 151 1016', 'ventas1@fhb.com.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- IMPERIO DE LOS ANGELES (GRUPO HOTELERO DEL BAJIO SA DE CV)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'GRUPO HOTELERO DEL BAJIO SA DE CV', 'IMPERIO DE LOS ANGELES',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: GHB980305T19 | Dirección: KM 2CARRETERA SAN MIGUEL-CELAYA , LOS FRAILES, SAN MIGUEL DE ALLENDE, GTO C.P. 37790',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'IMPERIO DE LOS ANGELES' AND o.legal_name IS NOT DISTINCT FROM 'GRUPO HOTELERO DEL BAJIO SA DE CV'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'IMPERIO DE LOS ANGELES' AND legal_name IS NOT DISTINCT FROM 'GRUPO HOTELERO DEL BAJIO SA DE CV'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('415 152 9300' IS NOT NULL AND phone = '415 152 9300')
          OR ('recepcion@imperiodeangeles.com.mx' IS NOT NULL AND email = 'recepcion@imperiodeangeles.com.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '415 152 9300', 'recepcion@imperiodeangeles.com.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HABITAS (HABITAS GUANAJUATO)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'HABITAS GUANAJUATO', 'HABITAS',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: HGU220201BG1 | Dirección: CARRETERA SAN MIGUEL DE ALLENDE A  DOLORES KILOMETRO 3.5, C.P. 37713',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HABITAS' AND o.legal_name IS NOT DISTINCT FROM 'HABITAS GUANAJUATO'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HABITAS' AND legal_name IS NOT DISTINCT FROM 'HABITAS GUANAJUATO'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'MARIANA GONZALEZ' IS NOT NULL
      AND (
          (NULL IS NOT NULL AND phone = NULL)
          OR (NULL IS NOT NULL AND email = NULL)
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'MARIANA GONZALEZ', NULL, NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'MARIANA GONZALEZ' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL SANTUARIO (HACIENDA EL SANTUARIO HOTEL Y SPA S.A. DE C.V.)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'HACIENDA EL SANTUARIO HOTEL Y SPA S.A. DE C.V.', 'HOTEL SANTUARIO',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: HSH9906289X7 | Dirección: TERRAPLEN 42, CENTRO SAN MIGUEL DE ALLENDE C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL SANTUARIO' AND o.legal_name IS NOT DISTINCT FROM 'HACIENDA EL SANTUARIO HOTEL Y SPA S.A. DE C.V.'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL SANTUARIO' AND legal_name IS NOT DISTINCT FROM 'HACIENDA EL SANTUARIO HOTEL Y SPA S.A. DE C.V.'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('+52 415 980 0192' IS NOT NULL AND phone = '+52 415 980 0192')
          OR ('calidadhhs@haciendaelsantuario.com' IS NOT NULL AND email = 'calidadhhs@haciendaelsantuario.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '+52 415 980 0192', 'calidadhhs@haciendaelsantuario.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL AMPARO (HOTEL AMPARO, S.A. DE C.V.)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'HOTEL AMPARO, S.A. DE C.V.', 'HOTEL AMPARO',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: HAM180804593 | Dirección: MESONES 3, COL. CENTRO, SAN MIGUEL DE ALLENDE, MÉXICO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL AMPARO' AND o.legal_name IS NOT DISTINCT FROM 'HOTEL AMPARO, S.A. DE C.V.'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL AMPARO' AND legal_name IS NOT DISTINCT FROM 'HOTEL AMPARO, S.A. DE C.V.'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('415 152 0819' IS NOT NULL AND phone = '415 152 0819')
          OR ('debbie@hotelamparo.com' IS NOT NULL AND email = 'debbie@hotelamparo.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '415 152 0819', 'debbie@hotelamparo.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL REAL DE MINAS (HOTEL REAL DE MINAS SAN MIGUEL DE ALLENDE SA DE CV)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'HOTEL REAL DE MINAS SAN MIGUEL DE ALLENDE SA DE CV', 'HOTEL REAL DE MINAS',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: HRM750508342 | Dirección: CAMINO VIEJO AL PANTEON 1, CENTRO , SAN MIGUEL DE ALLENDE, GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL REAL DE MINAS' AND o.legal_name IS NOT DISTINCT FROM 'HOTEL REAL DE MINAS SAN MIGUEL DE ALLENDE SA DE CV'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL REAL DE MINAS' AND legal_name IS NOT DISTINCT FROM 'HOTEL REAL DE MINAS SAN MIGUEL DE ALLENDE SA DE CV'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('415 980 0191' IS NOT NULL AND phone = '415 980 0191')
          OR ('bodas@realdeminas.com' IS NOT NULL AND email = 'bodas@realdeminas.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '415 980 0191', 'bodas@realdeminas.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL VILLA SANTA MONICA (INMOBILIARIA MARQUINA)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'INMOBILIARIA MARQUINA', 'HOTEL VILLA SANTA MONICA',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: IMA930212PT2 | Dirección: FRAY JOSE GUADALUPE MOJICA 22, CENTRO SAN MIGUEL DE ALLENDE C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL VILLA SANTA MONICA' AND o.legal_name IS NOT DISTINCT FROM 'INMOBILIARIA MARQUINA'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL VILLA SANTA MONICA' AND legal_name IS NOT DISTINCT FROM 'INMOBILIARIA MARQUINA'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('415 109 6358' IS NOT NULL AND phone = '415 109 6358')
          OR (NULL IS NOT NULL AND email = NULL)
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '415 109 6358', NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- SMXPERIENCE (JOSE ANTONIO QUERO RODRIGUEZ)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'JOSE ANTONIO QUERO RODRIGUEZ', 'SMXPERIENCE',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: QURA740101U7A | Dirección: CANAL 82, CENTRO, SAN MIGUEL DE ALLENDE , GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'SMXPERIENCE' AND o.legal_name IS NOT DISTINCT FROM 'JOSE ANTONIO QUERO RODRIGUEZ'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'SMXPERIENCE' AND legal_name IS NOT DISTINCT FROM 'JOSE ANTONIO QUERO RODRIGUEZ'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'TALINA' IS NOT NULL
      AND (
          ('415 566 9198' IS NOT NULL AND phone = '415 566 9198')
          OR ('administracion@smxperience.com' IS NOT NULL AND email = 'administracion@smxperience.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'TALINA', '415 566 9198', 'administracion@smxperience.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'TALINA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- ECO TURISTIC (JOSE LUIS RODRIGUEZ GARCIA)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'JOSE LUIS RODRIGUEZ GARCIA', 'ECO TURISTIC',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: ROGL691227R97 | Dirección: UMARAN 20B, CENTRO , SAN MIGUEL DE ALLENDE C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'ECO TURISTIC' AND o.legal_name IS NOT DISTINCT FROM 'JOSE LUIS RODRIGUEZ GARCIA'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'ECO TURISTIC' AND legal_name IS NOT DISTINCT FROM 'JOSE LUIS RODRIGUEZ GARCIA'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'ALEJANDRA' IS NOT NULL
      AND (
          ('415 153 0139' IS NOT NULL AND phone = '415 153 0139')
          OR (NULL IS NOT NULL AND email = NULL)
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'ALEJANDRA', '415 153 0139', NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'ALEJANDRA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- JULIO CÉSAR TOVAR DE ANDA
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'JULIO CÉSAR TOVAR DE ANDA', 'JULIO CÉSAR TOVAR DE ANDA',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: TOAJ6302164CA | Dirección: ANDADOR CAPITAL  4, INFONAVIT MALANQUIN, SAN MIGUEL DE ALLENDE C.P. 37755',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'JULIO CÉSAR TOVAR DE ANDA' AND o.legal_name IS NOT DISTINCT FROM 'JULIO CÉSAR TOVAR DE ANDA'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'JULIO CÉSAR TOVAR DE ANDA' AND legal_name IS NOT DISTINCT FROM 'JULIO CÉSAR TOVAR DE ANDA'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'JULIO TOVAR' IS NOT NULL
      AND (
          ('415 103 3323' IS NOT NULL AND phone = '415 103 3323')
          OR ('juliotourss@gmail.com' IS NOT NULL AND email = 'juliotourss@gmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'JULIO TOVAR', '415 103 3323', 'juliotourss@gmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'JULIO TOVAR' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO', 'MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: MSM8501019X6 | Dirección: BOULEVARD DE LA CONSPIRACIÓN C.P. 37748',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO' AND o.legal_name IS NOT DISTINCT FROM 'MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO' AND legal_name IS NOT DISTINCT FROM 'MUNICIPIO DE SAN MIGUEL DE ALLENDE GTO'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'MAYELA' IS NOT NULL
      AND (
          ('415 215 9303' IS NOT NULL AND phone = '415 215 9303')
          OR ('mayelalicea@sanmigueldeallende.gob.mx' IS NOT NULL AND email = 'mayelalicea@sanmigueldeallende.gob.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'MAYELA', '415 215 9303', 'mayelalicea@sanmigueldeallende.gob.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'MAYELA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- LA VALISE (NU TULUM)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'NU TULUM', 'LA VALISE',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: NTU190508AV5 | Dirección: JESÚS 17, ZONA CENTRO, 37700 SAN MIGUEL DE ALLENDE, GTO. C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'LA VALISE' AND o.legal_name IS NOT DISTINCT FROM 'NU TULUM'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'LA VALISE' AND legal_name IS NOT DISTINCT FROM 'NU TULUM'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'LUIS' IS NOT NULL
      AND (
          ('415 116 9484' IS NOT NULL AND phone = '415 116 9484')
          OR ('luisalberto@namronhospitality.com' IS NOT NULL AND email = 'luisalberto@namronhospitality.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'LUIS', '415 116 9484', 'luisalberto@namronhospitality.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'LUIS' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- CASA CHORRO (OPERADORA CASA CHORRO S. DE R.L. DE C.V.)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'OPERADORA CASA CHORRO S. DE R.L. DE C.V.', 'CASA CHORRO',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: OCC090630PL0 | Dirección: RECREO 15, CENTRO , SAN MIGUEL DE ALLENDE, GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'CASA CHORRO' AND o.legal_name IS NOT DISTINCT FROM 'OPERADORA CASA CHORRO S. DE R.L. DE C.V.'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'CASA CHORRO' AND legal_name IS NOT DISTINCT FROM 'OPERADORA CASA CHORRO S. DE R.L. DE C.V.'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('415 224 3553' IS NOT NULL AND phone = '415 224 3553')
          OR ('t.tigertranstours@hotmail.com' IS NOT NULL AND email = 't.tigertranstours@hotmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '415 224 3553', 't.tigertranstours@hotmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- DOS CASAS (OPERADORA DOS CASAS SA DE CV)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'OPERADORA DOS CASAS SA DE CV', 'DOS CASAS',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: ODC070104N32 | Dirección: QUEBRADA 101, CENTRO, SAN MIGUEL DE ALLENDE, GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'DOS CASAS' AND o.legal_name IS NOT DISTINCT FROM 'OPERADORA DOS CASAS SA DE CV'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'DOS CASAS' AND legal_name IS NOT DISTINCT FROM 'OPERADORA DOS CASAS SA DE CV'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          (NULL IS NOT NULL AND phone = NULL)
          OR ('dcastaneda@doscasas.com.mx' IS NOT NULL AND email = 'dcastaneda@doscasas.com.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, NULL, 'dcastaneda@doscasas.com.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- BESTUR (OPERADORA TURISTICA BESTUR)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'OPERADORA TURISTICA BESTUR', 'BESTUR',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: OTB051129CR7 | Dirección: JUAN DE DIOS PEZA 26, COLONIA GUADALUPE, SAN MIGUEL DE ALLENDE , GTO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'BESTUR' AND o.legal_name IS NOT DISTINCT FROM 'OPERADORA TURISTICA BESTUR'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'BESTUR' AND legal_name IS NOT DISTINCT FROM 'OPERADORA TURISTICA BESTUR'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'EFRAIN MENDEZ' IS NOT NULL
      AND (
          ('52 415 105 5290' IS NOT NULL AND phone = '52 415 105 5290')
          OR ('efrix_22@hotmail.com' IS NOT NULL AND email = 'efrix_22@hotmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'EFRAIN MENDEZ', '52 415 105 5290', 'efrix_22@hotmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'EFRAIN MENDEZ' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL ALBOR (OPERADORA TURISTICA OMV)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'OPERADORA TURISTICA OMV', 'HOTEL ALBOR',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: OTO190207CRA | Dirección: CAMINO 3 CRUCES KM. 0.9 SALTITO DE GUADALUPE SAN MIGUEL DE ALLENDE C.P. 37776',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL ALBOR' AND o.legal_name IS NOT DISTINCT FROM 'OPERADORA TURISTICA OMV'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL ALBOR' AND legal_name IS NOT DISTINCT FROM 'OPERADORA TURISTICA OMV'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('52 55 4738 6267' IS NOT NULL AND phone = '52 55 4738 6267')
          OR ('Ricardo.cano@aimbridge.com' IS NOT NULL AND email = 'Ricardo.cano@aimbridge.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '52 55 4738 6267', 'Ricardo.cano@aimbridge.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- JOSE LUIS RODRIGUEZ (RODSEGA S. DE RL. DE CV.)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'RODSEGA S. DE RL. DE CV.', 'JOSE LUIS RODRIGUEZ',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: ROD1306188R0 | Dirección: SAN MARTIN 21, SAN ANTONIO, SAN MIGUEL DE ALLENDE C.P. 37750',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'JOSE LUIS RODRIGUEZ' AND o.legal_name IS NOT DISTINCT FROM 'RODSEGA S. DE RL. DE CV.'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'JOSE LUIS RODRIGUEZ' AND legal_name IS NOT DISTINCT FROM 'RODSEGA S. DE RL. DE CV.'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'ALEJANDRA' IS NOT NULL
      AND (
          ('415 153 0139' IS NOT NULL AND phone = '415 153 0139')
          OR ('turisticosrodriguez@yahoo.com.mx' IS NOT NULL AND email = 'turisticosrodriguez@yahoo.com.mx')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'ALEJANDRA', '415 153 0139', 'turisticosrodriguez@yahoo.com.mx', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'ALEJANDRA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL NUMU (TESSERA CAPITAL)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'TESSERA CAPITAL', 'HOTEL NUMU',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: TCA1811076EA | Dirección: NEMESIO DIEZ #20, ZONA CENTRO, 37700 SAN MIGUEL DE ALLENDE, GUANAJUATO, MÉXICO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL NUMU' AND o.legal_name IS NOT DISTINCT FROM 'TESSERA CAPITAL'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL NUMU' AND legal_name IS NOT DISTINCT FROM 'TESSERA CAPITAL'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'GUILLERMO MALDONADO' IS NOT NULL
      AND (
          ('+52 415 148 1234' IS NOT NULL AND phone = '+52 415 148 1234')
          OR ('guillermo.maldonado2@numusanmiguelhotel.com' IS NOT NULL AND email = 'guillermo.maldonado2@numusanmiguelhotel.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'GUILLERMO MALDONADO', '+52 415 148 1234', 'guillermo.maldonado2@numusanmiguelhotel.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'GUILLERMO MALDONADO' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- RAUL ANGUIANO (TRANSPORTACIONES Y TOURS DE ALLENDE)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'TRANSPORTACIONES Y TOURS DE ALLENDE', 'RAUL ANGUIANO',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: TTA020628K56 | Dirección: FRANCISCO MARQUEZ NO. 33, COL. INDEPENDENCIA, SAN MIGUEL DE ALLENDE C.P. 37732',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'RAUL ANGUIANO' AND o.legal_name IS NOT DISTINCT FROM 'TRANSPORTACIONES Y TOURS DE ALLENDE'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'RAUL ANGUIANO' AND legal_name IS NOT DISTINCT FROM 'TRANSPORTACIONES Y TOURS DE ALLENDE'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'RAUL ANGUIANO' IS NOT NULL
      AND (
          ('+52 (415) 152 63 05' IS NOT NULL AND phone = '+52 (415) 152 63 05')
          OR ('contact@angelicatours.com' IS NOT NULL AND email = 'contact@angelicatours.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'RAUL ANGUIANO', '+52 (415) 152 63 05', 'contact@angelicatours.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'RAUL ANGUIANO' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL CASA 100
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'HOTEL CASA 100', 'HOTEL CASA 100',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: RECREO 100, SAN MIGUEL DE ALLENDE, MÉXICO C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL CASA 100' AND o.legal_name IS NOT DISTINCT FROM 'HOTEL CASA 100'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL CASA 100' AND legal_name IS NOT DISTINCT FROM 'HOTEL CASA 100'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'NELLIE' IS NOT NULL
      AND (
          ('52 415 167 0902' IS NOT NULL AND phone = '52 415 167 0902')
          OR ('hotelcasacien@gmail.com' IS NOT NULL AND email = 'hotelcasacien@gmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'NELLIE', '52 415 167 0902', 'hotelcasacien@gmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'NELLIE' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- HOTEL CONCEPCION
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'HOTEL CONCEPCION', 'HOTEL CONCEPCION',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: CALLE MESONES, NO. 24,ZONA CENTRO. SAN MIGUEL DE ALLENDE, GUANAJUATO. C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'HOTEL CONCEPCION' AND o.legal_name IS NOT DISTINCT FROM 'HOTEL CONCEPCION'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'HOTEL CONCEPCION' AND legal_name IS NOT DISTINCT FROM 'HOTEL CONCEPCION'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'ARMANDO LLAMAS' IS NOT NULL
      AND (
          ('415 688 386015 168 3729' IS NOT NULL AND phone = '415 688 386015 168 3729')
          OR ('reservaciones@concepcionhotelboutique.com' IS NOT NULL AND email = 'reservaciones@concepcionhotelboutique.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'ARMANDO LLAMAS', '415 688 386015 168 3729', 'reservaciones@concepcionhotelboutique.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'ARMANDO LLAMAS' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- CASA 63
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'CASA 63', 'CASA 63',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: CALLE MESONES #63, CENTRO, SAN MIGUEL DE ALLENDE GTO. C.P. 37700',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'CASA 63' AND o.legal_name IS NOT DISTINCT FROM 'CASA 63'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'CASA 63' AND legal_name IS NOT DISTINCT FROM 'CASA 63'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'ERIK' IS NOT NULL
      AND (
          ('415 150 1255' IS NOT NULL AND phone = '415 150 1255')
          OR ('reservaciones@casa63.com' IS NOT NULL AND email = 'reservaciones@casa63.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'ERIK', '415 150 1255', 'reservaciones@casa63.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'ERIK' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- CIVITATIS
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'CIVITATIS', 'CIVITATIS',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           NULL,
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'CIVITATIS' AND o.legal_name IS NOT DISTINCT FROM 'CIVITATIS'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'CIVITATIS' AND legal_name IS NOT DISTINCT FROM 'CIVITATIS'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          (NULL IS NOT NULL AND phone = NULL)
          OR ('civitatis.com' IS NOT NULL AND email = 'civitatis.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, NULL, 'civitatis.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- LUGGAGE & LUXURY
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'LUGGAGE & LUXURY', 'LUGGAGE & LUXURY',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: RECREO 8, SAN MIGUEL DE ALLENDE, MÉXICO C.P. 37000',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'LUGGAGE & LUXURY' AND o.legal_name IS NOT DISTINCT FROM 'LUGGAGE & LUXURY'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'LUGGAGE & LUXURY' AND legal_name IS NOT DISTINCT FROM 'LUGGAGE & LUXURY'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'RICHARD PHELPS' IS NOT NULL
      AND (
          ('1 (858) 354-9393' IS NOT NULL AND phone = '1 (858) 354-9393')
          OR ('rphelps@languageandluxury.com' IS NOT NULL AND email = 'rphelps@languageandluxury.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'RICHARD PHELPS', '1 (858) 354-9393', 'rphelps@languageandluxury.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'RICHARD PHELPS' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- TERRA MAYA
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'TERRA MAYA', 'TERRA MAYA',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: TERRA MAYA CALLE 58 352B, ENTRE 17 Y 19, PLAN DE AYALA,  MÉRIDA, YUC. C.P. 97118',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'TERRA MAYA' AND o.legal_name IS NOT DISTINCT FROM 'TERRA MAYA'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'TERRA MAYA' AND legal_name IS NOT DISTINCT FROM 'TERRA MAYA'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE NULL IS NOT NULL
      AND (
          ('999 481 9576' IS NOT NULL AND phone = '999 481 9576')
          OR ('contact@terra-maya.com' IS NOT NULL AND email = 'contact@terra-maya.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT NULL, '999 481 9576', 'contact@terra-maya.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NULL IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- CAMINOS DE AGUA
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'CAMINOS DE AGUA', 'CAMINOS DE AGUA',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: 4 PARTON CT, LAKE FOREST, IL 60045 C.P. 60045',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'CAMINOS DE AGUA' AND o.legal_name IS NOT DISTINCT FROM 'CAMINOS DE AGUA'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'CAMINOS DE AGUA' AND legal_name IS NOT DISTINCT FROM 'CAMINOS DE AGUA'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'DONN ZELLET' IS NOT NULL
      AND (
          (NULL IS NOT NULL AND phone = NULL)
          OR ('https://www.caminosdeagua.org/contact-1' IS NOT NULL AND email = 'https://www.caminosdeagua.org/contact-1')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'DONN ZELLET', NULL, 'https://www.caminosdeagua.org/contact-1', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'DONN ZELLET' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- VIAJES SAN MIGUEL (OPERADORA TURISTICA Y ARRENDADORES G7 S DE RL DE CV)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'OPERADORA TURISTICA Y ARRENDADORES G7 S DE RL DE CV', 'VIAJES SAN MIGUEL',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'RFC: OTA141210HW4 | Dirección: SAN RAFAEL 8A COL PROVIDENCIA SAN MIGUEL DE ALLENDE, GTO C.P. 37737',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'VIAJES SAN MIGUEL' AND o.legal_name IS NOT DISTINCT FROM 'OPERADORA TURISTICA Y ARRENDADORES G7 S DE RL DE CV'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'VIAJES SAN MIGUEL' AND legal_name IS NOT DISTINCT FROM 'OPERADORA TURISTICA Y ARRENDADORES G7 S DE RL DE CV'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'LETICIA' IS NOT NULL
      AND (
          ('52- 415 107 4336' IS NOT NULL AND phone = '52- 415 107 4336')
          OR ('g7sanmigueltours@gmail.com' IS NOT NULL AND email = 'g7sanmigueltours@gmail.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'LETICIA', '52- 415 107 4336', 'g7sanmigueltours@gmail.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'LETICIA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- GABY GALVAN (BODA SAN MIGUEL BY GABY GALVAN WEDDING)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'BODA SAN MIGUEL BY GABY GALVAN WEDDING', 'GABY GALVAN',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           NULL,
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'GABY GALVAN' AND o.legal_name IS NOT DISTINCT FROM 'BODA SAN MIGUEL BY GABY GALVAN WEDDING'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'GABY GALVAN' AND legal_name IS NOT DISTINCT FROM 'BODA SAN MIGUEL BY GABY GALVAN WEDDING'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'GABRIELA GALVAN' IS NOT NULL
      AND (
          ('415 124 9515' IS NOT NULL AND phone = '415 124 9515')
          OR ('gaby@bodasanmiguel.com' IS NOT NULL AND email = 'gaby@bodasanmiguel.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'GABRIELA GALVAN', '415 124 9515', 'gaby@bodasanmiguel.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'GABRIELA GALVAN' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);

-- GRETA ORTEGA (GRETA ORTEGA WEDDINGS & EVENT PLANNER)
WITH new_org AS (
    INSERT INTO organizations(legal_name, commercial_name, organization_type_id, notes, status_id)
    SELECT 'GRETA ORTEGA WEDDINGS & EVENT PLANNER', 'GRETA ORTEGA',
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           'Dirección: SAN MIGUEL DE ALLENDE',
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations o
        WHERE o.commercial_name = 'GRETA ORTEGA' AND o.legal_name IS NOT DISTINCT FROM 'GRETA ORTEGA WEDDINGS & EVENT PLANNER'
    )
    RETURNING id
),
target_org AS (
    SELECT id FROM new_org
    UNION ALL
    SELECT id FROM organizations
    WHERE commercial_name = 'GRETA ORTEGA' AND legal_name IS NOT DISTINCT FROM 'GRETA ORTEGA WEDDINGS & EVENT PLANNER'
      AND NOT EXISTS (SELECT 1 FROM new_org)
),
new_account AS (
    INSERT INTO accounts(organization_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
    SELECT t.id,
           atlas.catalog('ACCOUNT_TYPE', 'ORGANIZATION'),
           atlas.catalog('CURRENCY', 'MXN'),
           atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
           atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
           atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
    FROM target_org t
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.organization_id = t.id)
    RETURNING id, organization_id
),
target_account AS (
    SELECT id FROM new_account
    UNION ALL
    SELECT a.id FROM accounts a JOIN target_org t ON a.organization_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM new_account)
),
existing_person AS (
    SELECT id FROM people
    WHERE 'GRETA ORTEGA' IS NOT NULL
      AND (
          ('415 109 6033' IS NOT NULL AND phone = '415 109 6033')
          OR ('contact@gretaortega.com' IS NOT NULL AND email = 'contact@gretaortega.com')
      )
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, status_id)
    SELECT 'GRETA ORTEGA', '415 109 6033', 'contact@gretaortega.com', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE 'GRETA ORTEGA' IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
)
INSERT INTO contacts(account_id, person_id, is_primary, status_id)
SELECT (SELECT id FROM target_account), tp.id, true, atlas.catalog('ACCOUNT_STATUS', 'ACTIVE')
FROM target_person tp
WHERE NOT EXISTS (
    SELECT 1 FROM contacts c
    WHERE c.account_id = (SELECT id FROM target_account) AND c.person_id = tp.id
);




--------------------------------------------------------
-- 2) CLIENTES INDIVIDUALES (15) -- persona + cuenta directa
--
-- CORRECCIÓN v3: el segundo intento falló en "SUZANNE LAPIN" con
-- "duplicate key value violates unique constraint uq_people_email" --
-- ya existía una persona con ese correo en la base (no viene de este
-- mismo archivo, así que debe ser de otro proceso -- probablemente ya
-- llegó una reservación real de ella). Igual que en la sección de
-- organizaciones, ahora primero busca si ya existe una persona con
-- ese teléfono O correo antes de crear una nueva, y si existe,
-- reutiliza esa persona para la cuenta en vez de intentar duplicarla.
-- Sigue siendo seguro correr el archivo completo desde el principio.
--------------------------------------------------------

-- LEANDRO DELGADO
WITH existing_person AS (
    SELECT id FROM people
    WHERE (NULL IS NOT NULL AND phone = NULL)
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'LEANDRO DELGADO', NULL, NULL, 'Dirección: SAN RAFAEL 8A COL PROVIDENCIA SAN MIGUEL DE ALLENDE, GTO C.P. 37737 | Correo compartido con el contacto de Viajes San Miguel (g7sanmigueltours@gmail.com) -- no se guardó aquí porque el correo ya es único de otra persona; preguntar si tiene uno propio.', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'LEANDRO DELGADO' AND p.phone IS NOT DISTINCT FROM NULL
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'LEANDRO DELGADO' AND phone IS NOT DISTINCT FROM NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- MARCELO VALENZUELA
WITH existing_person AS (
    SELECT id FROM people
    WHERE (NULL IS NOT NULL AND phone = NULL)
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'MARCELO VALENZUELA', NULL, NULL, NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'MARCELO VALENZUELA' AND p.phone IS NOT DISTINCT FROM NULL
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'MARCELO VALENZUELA' AND phone IS NOT DISTINCT FROM NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- MARTIN JUAREZ
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('415 100 7528' IS NOT NULL AND phone = '415 100 7528')
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'MARTIN JUAREZ', '415 100 7528', NULL, NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'MARTIN JUAREZ' AND p.phone IS NOT DISTINCT FROM '415 100 7528'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'MARTIN JUAREZ' AND phone IS NOT DISTINCT FROM '415 100 7528'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- ANTONIO GOMEZ
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('415 151 3611' IS NOT NULL AND phone = '415 151 3611')
       OR ('antoniogomezh@yahoo.com.mx' IS NOT NULL AND email = 'antoniogomezh@yahoo.com.mx')
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'ANTONIO GOMEZ', '415 151 3611', 'antoniogomezh@yahoo.com.mx', NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'ANTONIO GOMEZ' AND p.phone IS NOT DISTINCT FROM '415 151 3611'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'ANTONIO GOMEZ' AND phone IS NOT DISTINCT FROM '415 151 3611'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- GREGORIO SIERRA
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('415 100 6023' IS NOT NULL AND phone = '415 100 6023')
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'GREGORIO SIERRA', '415 100 6023', NULL, NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'GREGORIO SIERRA' AND p.phone IS NOT DISTINCT FROM '415 100 6023'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'GREGORIO SIERRA' AND phone IS NOT DISTINCT FROM '415 100 6023'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- FRANCISCO CORREA
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('415 107 0697' IS NOT NULL AND phone = '415 107 0697')
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'FRANCISCO CORREA', '415 107 0697', NULL, NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'FRANCISCO CORREA' AND p.phone IS NOT DISTINCT FROM '415 107 0697'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'FRANCISCO CORREA' AND phone IS NOT DISTINCT FROM '415 107 0697'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- ELAINE GRENIER
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('1 (415) 548-0368' IS NOT NULL AND phone = '1 (415) 548-0368')
       OR ('egrenier@mindspring.com' IS NOT NULL AND email = 'egrenier@mindspring.com')
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'ELAINE GRENIER', '1 (415) 548-0368', 'egrenier@mindspring.com', NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'ELAINE GRENIER' AND p.phone IS NOT DISTINCT FROM '1 (415) 548-0368'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'ELAINE GRENIER' AND phone IS NOT DISTINCT FROM '1 (415) 548-0368'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- SUZANNE LAPIN
WITH existing_person AS (
    SELECT id FROM people
    WHERE (NULL IS NOT NULL AND phone = NULL)
       OR ('suzlapin@gmail.com' IS NOT NULL AND email = 'suzlapin@gmail.com')
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'SUZANNE LAPIN', NULL, 'suzlapin@gmail.com', NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'SUZANNE LAPIN' AND p.phone IS NOT DISTINCT FROM NULL
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'SUZANNE LAPIN' AND phone IS NOT DISTINCT FROM NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- ANDY PENN
WITH existing_person AS (
    SELECT id FROM people
    WHERE (NULL IS NOT NULL AND phone = NULL)
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'ANDY PENN', NULL, NULL, 'Dirección: ALDAMA 22, ZONA CENTRO, SAN MIGUEL DE ALLENDE, GUANAJUATO MEXICO C.P. 37700', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'ANDY PENN' AND p.phone IS NOT DISTINCT FROM NULL
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'ANDY PENN' AND phone IS NOT DISTINCT FROM NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- CHARLES REARD
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('1 314 412 7161' IS NOT NULL AND phone = '1 314 412 7161')
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'CHARLES REARD', '1 314 412 7161', NULL, 'Dirección: ORIZABA 17B, SAN ANTONIO, SAN MIGUEL DE ALLENDE , GUANAJUATO C.P. 37735', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'CHARLES REARD' AND p.phone IS NOT DISTINCT FROM '1 314 412 7161'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'CHARLES REARD' AND phone IS NOT DISTINCT FROM '1 314 412 7161'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- MARK BOUNDIN
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('1 469 388 3985' IS NOT NULL AND phone = '1 469 388 3985')
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'MARK BOUNDIN', '1 469 388 3985', NULL, 'Dirección: CALLE LAS MORAS 1 , ZONA CENTRO, SAN MIGUEL DE ALLENDE, GUANAJUATO MEXICO C.P. 37700', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'MARK BOUNDIN' AND p.phone IS NOT DISTINCT FROM '1 469 388 3985'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'MARK BOUNDIN' AND phone IS NOT DISTINCT FROM '1 469 388 3985'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- DR. BARRERA
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('1 972 741 6219' IS NOT NULL AND phone = '1 972 741 6219')
       OR ('carlosbarreramd@gmail.com' IS NOT NULL AND email = 'carlosbarreramd@gmail.com')
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'DR. BARRERA', '1 972 741 6219', 'carlosbarreramd@gmail.com', 'Dirección: BLVRD ADOLFO LOPEZ MATEOS 1000-7, COL CENTRO, CELAYA, GUANAJUATO MEXICO C.P. 38050', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'DR. BARRERA' AND p.phone IS NOT DISTINCT FROM '1 972 741 6219'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'DR. BARRERA' AND phone IS NOT DISTINCT FROM '1 972 741 6219'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- ARTEMISA SHAWN
WITH existing_person AS (
    SELECT id FROM people
    WHERE (NULL IS NOT NULL AND phone = NULL)
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'ARTEMISA SHAWN', NULL, NULL, NULL, atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'ARTEMISA SHAWN' AND p.phone IS NOT DISTINCT FROM NULL
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'ARTEMISA SHAWN' AND phone IS NOT DISTINCT FROM NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- JHON WIMBERLY
WITH existing_person AS (
    SELECT id FROM people
    WHERE ('1 202 746 0951' IS NOT NULL AND phone = '1 202 746 0951')
       OR ('jwimberly6243@gmail.com' IS NOT NULL AND email = 'jwimberly6243@gmail.com')
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'JHON WIMBERLY', '1 202 746 0951', 'jwimberly6243@gmail.com', 'Dirección: LA LUZ 103, SAN MIGUEL TRES CRUCES,  SAN MIGUEL DE ALLENDE, GTO. C.P. 37776', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'JHON WIMBERLY' AND p.phone IS NOT DISTINCT FROM '1 202 746 0951'
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'JHON WIMBERLY' AND phone IS NOT DISTINCT FROM '1 202 746 0951'
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);

-- SELENGI RAFTER
WITH existing_person AS (
    SELECT id FROM people
    WHERE (NULL IS NOT NULL AND phone = NULL)
       OR (NULL IS NOT NULL AND email = NULL)
    LIMIT 1
),
new_person AS (
    INSERT INTO people(given_names, phone, email, notes, status_id)
    SELECT 'SELENGI RAFTER', NULL, NULL, 'Dirección: CAMINO A LA CIENEGUITA 100, SAN MIGUEL DE ALLENDE, GTO. C.P. 37897', atlas.catalog('PERSON_STATUS', 'ACTIVE')
    WHERE NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (
          SELECT 1 FROM people p WHERE p.given_names = 'SELENGI RAFTER' AND p.phone IS NOT DISTINCT FROM NULL
      )
    RETURNING id
),
target_person AS (
    SELECT id FROM existing_person
    UNION ALL
    SELECT id FROM new_person
    UNION ALL
    SELECT id FROM people WHERE given_names = 'SELENGI RAFTER' AND phone IS NOT DISTINCT FROM NULL
      AND NOT EXISTS (SELECT 1 FROM existing_person)
      AND NOT EXISTS (SELECT 1 FROM new_person)
)
INSERT INTO accounts(person_id, account_type_id, preferred_currency_id, payment_term_id, status_id, pricing_client_tier_id)
SELECT t.id,
       atlas.catalog('ACCOUNT_TYPE', 'INDIVIDUAL'),
       atlas.catalog('CURRENCY', 'MXN'),
       atlas.catalog('PAYMENT_TERM', 'IMMEDIATE'),
       atlas.catalog('ACCOUNT_STATUS', 'ACTIVE'),
       atlas.catalog('PRICING_CLIENT_TIER', 'PUBLICO_GENERAL')
FROM target_person t
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.person_id = t.id);
--------------------------------------------------------
-- 3) Pendiente manual (NO se corre solo, revisar contigo primero):
-- una vez confirmado que no hay cuentas duplicadas de antes para
-- Villa Santa Mónica / La Valise, marcar su nivel especial así:
--
-- UPDATE accounts SET pricing_client_tier_id = atlas.catalog('PRICING_CLIENT_TIER', 'VILLA_SANTA_MONICA')
--  WHERE organization_id = (SELECT id FROM organizations WHERE commercial_name = 'HOTEL VILLA SANTA MONICA');
--
-- UPDATE accounts SET pricing_client_tier_id = atlas.catalog('PRICING_CLIENT_TIER', 'LA_VALISE')
--  WHERE organization_id = (SELECT id FROM organizations WHERE commercial_name = 'LA VALISE');
--------------------------------------------------------
