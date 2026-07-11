-- Estado de un conteo físico de inventario (inventariado). El conteo es un
-- proceso: se abre, se registran cantidades contadas por producto y al
-- aplicarse genera los movimientos AJUSTE que corrigen el kardex. El stock
-- NUNCA se edita directo: siempre vía movimientos.
CREATE TYPE inventory.inventory_count_status AS ENUM (
    'EN_CURSO',     -- conteo abierto: se están registrando cantidades
    'APLICADO',     -- conteo cerrado: los AJUSTE ya corrigieron el stock
    'CANCELADO'     -- conteo descartado sin tocar stock
);

COMMENT ON TYPE inventory.inventory_count_status IS
    'Ciclo de vida de un conteo físico de inventario (inventory_counts): EN_CURSO → APLICADO (genera AJUSTEs) | CANCELADO (no toca stock).';
