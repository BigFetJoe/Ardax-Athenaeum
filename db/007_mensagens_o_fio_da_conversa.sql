-- ════════════════════════════════════════════════════════════════════
-- Ardax — 007: mensagens. O Ardax passa a ter fio.
--
-- Aplicar:  docker compose exec -T postgres psql -U ardax -d ardax < db/007_mensagens_o_fio_da_conversa.sql
-- Reverter: DROP TABLE ardax.mensagens;   (nada mais depende dela)
--
-- POR QUÊ
-- Até aqui cada mensagem era um universo fechado: chegava, era
-- classificada, virava item, e o Ardax esquecia. Não havia como dizer
-- "não era isso", nem complementar algo já dito sem reescrever tudo.
--
-- A PEÇA QUE O TELEGRAM DÁ DE GRAÇA
-- Quando o João responde uma mensagem, o Telegram manda no webhook o
-- campo "reply_to_message", com o id da mensagem respondida. Isto é
-- enorme: apontar deixa de ser adivinhação. Não precisamos inferir de
-- qual item ele está falando -- ele apontou, e o apontamento é exato.
--
-- Guardamos esse ponteiro em "responde_a". De posse dele, uma correção
-- deixa de ser um palpite e passa a ser um UPDATE num item conhecido.
--
-- REGRA: esta tabela é um LOG. Append-only. Nunca UPDATE, nunca DELETE.
-- O valor dela é justamente ser o registro de tudo que foi dito e do
-- que o modelo entendeu na hora -- inclusive quando entendeu errado.
-- Cada "não era isso" é um exemplo rotulado do erro do classificador.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE ardax.mensagens (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  canal      text NOT NULL DEFAULT 'telegram',
  chat_id    bigint NOT NULL,

  -- O id que o Telegram deu à mensagem. É por ele que "responde_a"
  -- aponta, não pelo "id" desta tabela: o ponteiro vem de fora.
  message_id bigint NOT NULL,

  papel      text NOT NULL CHECK (papel IN ('joao', 'ardax')),
  texto      text NOT NULL DEFAULT '',

  -- message_id da mensagem respondida. SEM chave estrangeira de
  -- propósito: ele pode responder uma mensagem anterior a esta
  -- migração, que não existe aqui. A chave rejeitaria e a captura
  -- morreria por causa de histórico que nunca tivemos.
  responde_a bigint,

  -- A que item esta mensagem deu origem, ou em qual ela mexeu.
  -- Nulo em consulta, em conversa solta e em erro.
  --
  -- uuid, nao bigint: a chave de ardax.itens e' uuid. O "numero" curto
  -- (bigint, da migracao 003) e' so' para ele digitar no Telegram --
  -- apontar por ele aqui seria apontar para um apelido.
  item_id    uuid REFERENCES ardax.itens(id),

  -- O que o classificador decidiu. Guardado para que a correção possa
  -- ver o que deu errado, e para auditar o prompt em lote depois.
  intencao   text,
  extracao   jsonb NOT NULL DEFAULT '{}',

  criado_em  timestamptz NOT NULL DEFAULT now()
);

-- Idempotência: se o webhook for entregue duas vezes (acontece), a
-- segunda gravação bate aqui em vez de duplicar o fio.
-- Serve de caminho de busca para "qual mensagem tem este message_id".
CREATE UNIQUE INDEX ux_mensagens_telegram
  ON ardax.mensagens (canal, chat_id, message_id);

-- Janela recente: "as últimas N mensagens desta conversa".
CREATE INDEX ix_mensagens_recentes
  ON ardax.mensagens (chat_id, criado_em DESC);

-- "O que já foi dito sobre o item 7" -- parcial porque a maioria das
-- linhas tem item_id nulo, e índice parcial não paga por elas.
CREATE INDEX ix_mensagens_item
  ON ardax.mensagens (item_id) WHERE item_id IS NOT NULL;

COMMIT;

-- ════════════════════════════════════════════════════════════════════
-- AS DUAS CONSULTAS DO CATÁLOGO QUE ISTO HABILITA
--
-- 1) RESOLVER UM APONTAMENTO -- o que ele respondeu, e que item era
--
--      SELECT m.papel, m.texto, m.intencao, m.extracao,
--             i.id AS item_id, i.numero, i.titulo, i.tipo
--        FROM ardax.mensagens m
--        LEFT JOIN ardax.itens i ON i.id = m.item_id
--       WHERE m.chat_id = $1 AND m.message_id = $2;
--
--    Se a mensagem respondida foi do Ardax, o item_id dela diz do que
--    ele estava falando. Se foi do João, diz o que aquela mensagem
--    criou. Nos dois casos o alvo sai exato.
--
-- 2) JANELA RECENTE -- para quando ele NÃO respondeu e disse "isso"
--
--      SELECT papel, texto FROM ardax.mensagens
--       WHERE chat_id = $1 ORDER BY criado_em DESC LIMIT 6;
--
--    Esta é a metade cara: entra no prompt toda vez. A metade
--    barata é a (1), que só roda quando há apontamento.
-- ════════════════════════════════════════════════════════════════════
