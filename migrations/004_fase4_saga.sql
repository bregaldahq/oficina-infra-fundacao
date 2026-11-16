-- ============================================================
-- 004_fase4_saga.sql
-- O serviço de OS vira o orquestrador da saga (docs/fase-4/CONTRATOS.md §6 e §7, no oficina-api;
-- ADR-012 e ADR-017).
--
-- Idempotente, como o 002: MODIFY e CREATE TABLE IF NOT EXISTS são naturalmente idempotentes;
-- ADD COLUMN passa pelo information_schema com PREPARE/EXECUTE. Sem DELIMITER.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Status novos da OS: AWAITING_PAYMENT (aprovada, esperando o pagamento) e CANCELLED
--    (compensada pela saga ou cancelada pelo admin). O histórico é VARCHAR e não muda.
-- ------------------------------------------------------------
ALTER TABLE service_orders
    MODIFY COLUMN status ENUM('RECEIVED','DIAGNOSIS','AWAITING_APPROVAL','AWAITING_PAYMENT','EXECUTING','REJECTED','FINISHED','DELIVERED','CANCELLED')
    NOT NULL DEFAULT 'RECEIVED';

-- ------------------------------------------------------------
-- 2. O orçamento e o link de pagamento chegam por evento do Faturamento.
-- ------------------------------------------------------------
SET @stmt = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE service_orders ADD COLUMN budget_id CHAR(36) NULL AFTER total_amount',
    'SELECT 1')
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'service_orders' AND column_name = 'budget_id');
PREPARE s FROM @stmt;
EXECUTE s;
DEALLOCATE PREPARE s;

SET @stmt = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE service_orders ADD COLUMN payment_url VARCHAR(512) NULL AFTER budget_id',
    'SELECT 1')
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'service_orders' AND column_name = 'payment_url');
PREPARE s FROM @stmt;
EXECUTE s;
DEALLOCATE PREPARE s;

-- ------------------------------------------------------------
-- 3. O estado de cada saga: uma por OS. `pending` são as compensações que ainda esperam
--    confirmação; `history` é a linha do tempo da saga. Os dois são JSON.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sagas (
    id             CHAR(36)     NOT NULL,
    os_id          CHAR(36)     NOT NULL,
    correlation_id VARCHAR(64)  NOT NULL DEFAULT '',
    state          VARCHAR(20)  NOT NULL,
    step           VARCHAR(20)  NOT NULL,
    failed_step    VARCHAR(20)  NULL,
    reason         VARCHAR(255) NULL,
    data           JSON         NOT NULL,
    pending        JSON         NOT NULL,
    history        JSON         NOT NULL,
    deadline_at    DATETIME(3)  NULL,
    attempts       INT          NOT NULL DEFAULT 0,
    alerted        TINYINT(1)   NOT NULL DEFAULT 0,
    version        INT          NOT NULL DEFAULT 1,
    created_at     DATETIME(3)  NOT NULL,
    updated_at     DATETIME(3)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sagas_os (os_id),
    KEY idx_sagas_deadline (state, deadline_at),
    CONSTRAINT fk_sagas_order FOREIGN KEY (os_id) REFERENCES service_orders (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. Outbox e inbox (ADR-017), como nos outros dois serviços.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS outbox (
    id           CHAR(36)    NOT NULL,
    type         VARCHAR(64) NOT NULL,
    body         TEXT        NOT NULL,
    occurred_at  VARCHAR(32) NOT NULL,
    published_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    KEY idx_outbox_pending (published_at, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS inbox (
    message_id   VARCHAR(128) NOT NULL,
    processed_at DATETIME(3)  NOT NULL,
    PRIMARY KEY (message_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
