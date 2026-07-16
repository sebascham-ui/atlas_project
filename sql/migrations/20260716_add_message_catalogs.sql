-- =====================================================
-- MESSAGE CATALOGS
-- Atlas Project
-- =====================================================

-- CHANNEL
INSERT INTO catalog_groups(code, name)
SELECT 'CHANNEL', 'Communication Channel'
WHERE NOT EXISTS (
    SELECT 1
    FROM catalog_groups
    WHERE code = 'CHANNEL'
);

-- MESSAGE_TYPE
INSERT INTO catalog_groups(code, name)
SELECT 'MESSAGE_TYPE', 'Message Type'
WHERE NOT EXISTS (
    SELECT 1
    FROM catalog_groups
    WHERE code = 'MESSAGE_TYPE'
);

-- MESSAGE_DIRECTION
INSERT INTO catalog_groups(code, name)
SELECT 'MESSAGE_DIRECTION', 'Message Direction'
WHERE NOT EXISTS (
    SELECT 1
    FROM catalog_groups
    WHERE code = 'MESSAGE_DIRECTION'
);

--------------------------------------------------------
-- CHANNEL ITEMS
--------------------------------------------------------

INSERT INTO catalog_items(group_id,code,label,sort_order)

SELECT
    g.id,
    v.code,
    v.label,
    v.sort_order

FROM catalog_groups g

CROSS JOIN (

VALUES

('EMAIL','Email',1),
('WHATSAPP','WhatsApp',2),
('PHONE','Phone',3),
('WEB', 'Web',4)

) v(code,label,sort_order)

WHERE g.code='CHANNEL'

AND NOT EXISTS(

SELECT 1

FROM catalog_items i

WHERE i.group_id=g.id

AND i.code=v.code

);

--------------------------------------------------------
-- MESSAGE TYPE
--------------------------------------------------------

INSERT INTO catalog_items(group_id,code,label,sort_order)

SELECT
g.id,
v.code,
v.label,
v.sort_order

FROM catalog_groups g

CROSS JOIN(

VALUES

('EMAIL','Email',1),
('NOTE','Internal Note',2),
('SYSTEM','System',3)

)v(code,label,sort_order)

WHERE g.code='MESSAGE_TYPE'

AND NOT EXISTS(

SELECT 1

FROM catalog_items i

WHERE i.group_id=g.id

AND i.code=v.code

);

--------------------------------------------------------
-- MESSAGE DIRECTION
--------------------------------------------------------

INSERT INTO catalog_items(group_id,code,label,sort_order)

SELECT
g.id,
v.code,
v.label,
v.sort_order

FROM catalog_groups g

CROSS JOIN(

VALUES

('INBOUND','Inbound',1),
('OUTBOUND','Outbound',2)

)v(code,label,sort_order)

WHERE g.code='MESSAGE_DIRECTION'

AND NOT EXISTS(

SELECT 1

FROM catalog_items i

WHERE i.group_id=g.id

AND i.code=v.code

);
