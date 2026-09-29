-- ════════════════════════════════════════════════════════════════════
-- Ardax — esquema do MVP
--
-- Aplicar:  docker compose exec -T postgres psql -U ardax -d ardax < db/001_esquema_mvp.sql
--
-- REGRA: arquivo de migração já aplicado NUNCA se edita. Mudança nova =
-- arquivo novo numerado (002_, 003_), para o banco ser reconstruível do
-- zero, em ordem.
--
-- Tudo dentro de uma transação: ou o esquema inteiro nasce, ou nada nasce.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- ═══ EXTENSÕES ═══════════════════════════════════════════════════════
-- Fica em public para que o tipo "vector" seja visível de qualquer schema.
-- Instalada agora mesmo sem uso: a tabela chunks nasce vazia no MVP.
CREATE EXTENSION IF NOT EXISTS vector SCHEMA public;

-- ═══ SCHEMA ══════════════════════════════════════════════════════════
-- Um schema só para o Ardax inteiro. O modelo unifica tudo em "itens",
-- então não há domínios a separar — o schema aqui é nome, não divisão.
CREATE SCHEMA IF NOT EXISTS ardax;

-- ═══ 1. TIPOS — vocabulário dos itens ════════════════════════════════
CREATE TABLE ardax.tipos (
  nome   text PRIMARY KEY,
  rotulo text NOT NULL,
  campos jsonb NOT NULL DEFAULT '{}'   -- chaves esperadas no extra + valores válidos
);

INSERT INTO ardax.tipos (nome, rotulo, campos) VALUES
('nota',  'Nota',         '{"veracidade":  ["vigora","conjectura","falsa"],
                            "procedencia": ["propria","externa","conversa"],
                            "memorizar":   ["sim","nao"]}'),
('ideia', 'Ideia',        '{"veracidade":  ["vigora","conjectura","falsa"],
                            "necessidade": ["obrigatoria","opcional"],
                            "viabilidade": ["viavel","incerta","inviavel"]}'),
('tarefa','Tarefa',       '{"necessidade": ["obrigatoria","opcional"],
                            "viabilidade": ["viavel","incerta","inviavel"]}'),
('area',  'Área da vida', '{}'),
('tema',  'Tema',         '{}');

-- ═══ 2. VERBOS — vocabulário das ligações ════════════════════════════
CREATE TABLE ardax.verbos (
  nome   text PRIMARY KEY,
  rotulo text NOT NULL
);

INSERT INTO ardax.verbos VALUES
('contem',      'contém'),
('sobre',       'é sobre'),
('depende_de',  'depende de'),
('apoia',       'apoia'),
('supera',      'supera'),
('extraida_de', 'foi extraída de');

-- ═══ 3. ITENS — o núcleo. todo item vive aqui e só aqui ══════════════
-- "Projeto" e "etapa" NÃO são tipos: são posições no grafo.
-- Projeto = item com "contem" saindo dele. Etapa = tarefa com "contem" chegando.
CREATE TABLE ardax.itens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo          text NOT NULL REFERENCES ardax.tipos(nome),
  titulo        text NOT NULL,
  corpo         text NOT NULL DEFAULT '',
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  arquivado_em  timestamptz,          -- lixo com tampa: NUNCA use DELETE
  origem        text,                 -- telegram | discord | pc | obsidian
  caminho_vault text,                 -- vazio = vive só no banco
  hash_corpo    text,                 -- mudou? reindexa. não mudou? pula.
  extra         jsonb NOT NULL DEFAULT '{}',

  -- derivados: o banco calcula, ninguém escreve
  tamanho integer GENERATED ALWAYS AS (length(corpo)) STORED,
  busca   tsvector GENERATED ALWAYS AS
            (to_tsvector('portuguese', titulo || ' ' || corpo)) STORED
);

-- ═══ 4. TAREFAS — extensão: a capacidade "agendável" ═════════════════
-- Extensão por CAPACIDADE, não por tipo. Tipos novos reaproveitam esta.
CREATE TABLE ardax.tarefas (
  item_id            uuid PRIMARY KEY REFERENCES ardax.itens(id) ON DELETE CASCADE,
  status             text NOT NULL DEFAULT 'aberta'
                     CHECK (status IN ('aberta','fazendo','pausada','feita','cancelada')),
  prazo              date,
  criterio_conclusao text,
  -- encerrada_em cobre as DUAS saídas: 'feita' e 'cancelada'.
  -- (era concluida_em; cancelada também termina e ficaria sem data)
  encerrada_em       timestamptz
);

-- ═══ 5. LIGAÇÕES — o grafo inteiro ═══════════════════════════════════
-- Hierarquia, dependência e assunto, todos aqui. O verbo diz qual é qual.
CREATE TABLE ardax.ligacoes (
  origem_id  uuid NOT NULL REFERENCES ardax.itens(id) ON DELETE CASCADE,
  destino_id uuid NOT NULL REFERENCES ardax.itens(id) ON DELETE CASCADE,
  tipo       text NOT NULL REFERENCES ardax.verbos(nome),
  criado_em  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (origem_id, destino_id, tipo),
  CHECK (origem_id <> destino_id)
);

-- ═══ 6. CHUNKS — o RAG. derivado, descartável, VAZIO no MVP ══════════
CREATE TABLE ardax.chunks (
  id      bigserial PRIMARY KEY,
  item_id uuid NOT NULL REFERENCES ardax.itens(id) ON DELETE CASCADE,
  ordem   integer NOT NULL,
  texto   text NOT NULL,
  modelo  text NOT NULL,
  vetor   public.vector(1024) NOT NULL,   -- 1024 = bge-m3
  UNIQUE (item_id, ordem, modelo)
);

-- ═══ CARIMBO AUTOMÁTICO DE atualizado_em ═════════════════════════════
CREATE FUNCTION ardax.toca_atualizado() RETURNS trigger AS $$
BEGIN NEW.atualizado_em = now(); RETURN NEW; END $$ LANGUAGE plpgsql;

CREATE TRIGGER t_itens_atualizado BEFORE UPDATE ON ardax.itens
  FOR EACH ROW EXECUTE FUNCTION ardax.toca_atualizado();

-- ═══ ÍNDICES ═════════════════════════════════════════════════════════
CREATE INDEX ON ardax.itens USING gin (busca);
CREATE INDEX ON ardax.itens (tipo);
CREATE INDEX ON ardax.itens (arquivado_em);
CREATE INDEX ON ardax.ligacoes (destino_id, tipo);
CREATE INDEX ON ardax.tarefas (status, prazo);
-- SEM índice em chunks.vetor por enquanto: com poucos pedaços a busca exata
-- é instantânea e 100% precisa. HNSW é aproximado — só quando doer.

-- ═══ CONSULTAS SALVAS ════════════════════════════════════════════════
CREATE VIEW ardax.v_hoje AS
SELECT i.id, i.titulo, t.status, t.prazo, i.extra->>'necessidade' AS necessidade
FROM ardax.itens i
JOIN ardax.tarefas t ON t.item_id = i.id
WHERE i.arquivado_em IS NULL
  AND t.status IN ('aberta','fazendo')
  AND (t.prazo IS NULL OR t.prazo <= current_date)
ORDER BY (i.extra->>'necessidade' = 'obrigatoria') DESC, t.prazo NULLS LAST;

-- Painel de risco: o que o objetivo exige e não se sabe se é possível.
CREATE VIEW ardax.v_risco AS
SELECT i.id, i.tipo, i.titulo
FROM ardax.itens i
WHERE i.arquivado_em IS NULL
  AND i.extra->>'necessidade' = 'obrigatoria'
  AND i.extra->>'viabilidade' = 'incerta';

COMMIT;
