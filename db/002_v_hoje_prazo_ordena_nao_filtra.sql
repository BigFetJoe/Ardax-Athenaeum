-- ════════════════════════════════════════════════════════════════════
-- Ardax — 002: na v_hoje, o prazo passa a ORDENAR em vez de FILTRAR
--
-- Aplicar:  docker compose exec -T postgres psql -U ardax -d ardax < db/002_v_hoje_prazo_ordena_nao_filtra.sql
--
-- POR QUÊ
-- A versão do 001 tinha  "AND (t.prazo IS NULL OR t.prazo <= current_date)".
-- Efeito: tarefa com prazo futuro sumia da lista até o dia chegar. Capturar
-- "estudar pra prova do dia 15" no dia 1º fazia a tarefa ficar invisível
-- justamente durante os 14 dias em que dava pra estudar.
--
-- Isso contraria a regra do cardápio: prazo é INFORMAÇÃO, não cobrança.
-- Informação que só aparece no último dia não é informação, é susto.
--
-- A pergunta que a visão responde é "o que posso fazer agora". Uma tarefa
-- que vence em seis dias pode ser feita agora — o prazo diz onde ela entra
-- na fila, não se ela existe.
--
-- ESCOPO: esta ordenação é PROVISÓRIA e de propósito burra. Ordenar por
-- proveito real é a fase 2 (julgamento por IA). Aqui só vale ser previsível.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE VIEW ardax.v_hoje AS
SELECT
  i.id,
  i.titulo,
  t.status,
  t.prazo,
  -- Negativo = atrasada. Zero = vence hoje. Nulo = sem prazo.
  -- O prazo vira número visível, que é o ponto: informação, não filtro.
  (t.prazo - current_date) AS dias_ate_prazo,
  i.extra->>'necessidade'  AS necessidade
FROM ardax.itens i
JOIN ardax.tarefas t ON t.item_id = i.id
WHERE i.arquivado_em IS NULL
  AND t.status IN ('aberta','fazendo')
ORDER BY
  -- 1º) atrasadas e as de hoje no topo
  (t.prazo IS NOT NULL AND t.prazo <= current_date) DESC,
  -- 2º) depois, prazo mais próximo primeiro; sem prazo vai pro fim
  t.prazo ASC NULLS LAST,
  -- 3º) empate desfeito pela necessidade.
  --     NULLS LAST porque "sem necessidade definida" não é o mesmo que
  --     obrigatória -- sem isto o Postgres poria os indefinidos no topo,
  --     que era um erro silencioso da versão anterior.
  (i.extra->>'necessidade' = 'obrigatoria') DESC NULLS LAST;

COMMIT;
