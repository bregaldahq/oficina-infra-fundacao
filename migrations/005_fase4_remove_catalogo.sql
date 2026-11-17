-- ============================================================
-- 005_fase4_remove_catalogo.sql
-- Catálogo de serviços, estoque de peças e itens da OS passaram para o serviço de Faturamento,
-- com banco próprio (docs/fase-4/CONTRATOS.md §7, no oficina-api; ADR-014). O OS deixou de ler
-- estas tabelas na Etapa 5: esta migration só entra depois de esse OS estar em produção
-- (remoção: primeiro o consumidor, depois o produtor).
--
-- Não há migração de dados: catálogo e estoque são dados de demonstração e nascem do seed do
-- Faturamento. O total da OS fica em service_orders.total_amount, que não muda.
--
-- Idempotente: DROP TABLE IF EXISTS. As tabelas de junção saem antes, por causa das FKs.
-- ============================================================

DROP TABLE IF EXISTS service_order_services;
DROP TABLE IF EXISTS service_order_parts;
DROP TABLE IF EXISTS service_catalog;
DROP TABLE IF EXISTS parts_inventory;
