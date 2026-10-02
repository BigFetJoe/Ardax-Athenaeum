-- ════════════════════════════════════════════════════════════════════
-- Ardax — 003: número curto para cada item
--
-- Aplicar:  docker compose exec -T postgres psql -U ardax -d ardax < db/003_numero_curto_do_item.sql
--
-- POR QUÊ
-- O identificador do item é um UUID de 36 caracteres. Ninguém digita isso
-- no celular. Para "feito 7" funcionar, cada item precisa de um número
-- curto, e ele precisa ser ESTÁVEL.
--
-- Por que não usar a posição na lista ("o terceiro que apareceu"): a lista
-- muda entre uma consulta e outra. Você veria a lista, se distrairia, e ao
-- voltar "feito 3" concluiria uma tarefa diferente da que você viu. Número
-- gravado nunca muda.
--
-- O número é global e sequencial, não reinicia. Depois de um ano você vai
-- estar digitando "feito 1847" -- feio, mas inequívoco. Trocar feiura por
-- ambiguidade seria mau negócio num sistema onde concluir é irreversível.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- GENERATED ALWAYS: o banco preenche, ninguém escreve à mão.
-- Mesma família de tamanho e busca, que já são calculados.
-- As linhas que já existem recebem número na hora.
ALTER TABLE ardax.itens
  ADD COLUMN numero bigint GENERATED ALWAYS AS IDENTITY;

CREATE UNIQUE INDEX ix_itens_numero ON ardax.itens (numero);

-- ═══ VISÕES: recriadas para expor o número ═══════════════════════════
-- DROP + CREATE, não CREATE OR REPLACE -- a lista de colunas muda de forma
-- (lição do 002: "OR REPLACE" só troca o corpo, não o formato).

DROP VIEW IF EXISTS ardax.v_hoje;

CREATE VIEW ardax.v_hoje AS
SELECT
  i.numero,
  i.id,
  i.titulo,
  t.status,
  t.prazo,
  (t.prazo - current_date) AS dias_ate_prazo,
  i.extra->>'necessidade' AS necessidade
FROM ardax.itens i
JOIN ardax.tarefas t ON t.item_id = i.id
WHERE i.arquivado_em IS NULL
  AND t.status IN ('aberta','fazendo')
ORDER BY
  (t.prazo IS NOT NULL AND t.prazo <= current_date) DESC,
  t.prazo ASC NULLS LAST,
  (i.extra->>'necessidade' = 'obrigatoria') DESC NULLS LAST;

DROP VIEW IF EXISTS ardax.v_risco;

CREATE VIEW ardax.v_risco AS
SELECT i.numero, i.id, i.tipo, i.titulo
FROM ardax.itens i
WHERE i.arquivado_em IS NULL
  AND i.extra->>'necessidade' = 'obrigatoria'
  AND i.extra->>'viabilidade' = 'incerta';

COMMIT;

-- ════════════════════════════════════════════════════════════════════
-- CONSULTA DE REFERÊNCIA — concluir pelo número (fluxo C do MVP)
--
-- Nunca DELETE. Concluir é mudar o status e carimbar a data.
-- O RETURNING devolve o título, para a resposta no Telegram poder dizer
-- O QUE foi concluído -- e não só "ok".
--
-- UPDATE ardax.tarefas t
--    SET status = 'feita',
--        encerrada_em = now()
--   FROM ardax.itens i
--  WHERE i.id = t.item_id
--    AND i.numero = $1
--    AND t.status IN ('aberta','fazendo')
--  RETURNING i.numero, i.titulo;
--
-- Se não voltar linha nenhuma: ou o número não existe, ou a tarefa já
-- estava encerrada. A resposta deve distinguir isso de sucesso.
-- ════════════════════════════════════════════════════════════════════
