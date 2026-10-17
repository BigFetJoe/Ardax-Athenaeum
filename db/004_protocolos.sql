-- ════════════════════════════════════════════════════════════════════
-- Ardax — 004: protocolos. Prompts e regras deixam de morar no n8n.
--
-- Aplicar:  docker compose exec -T postgres psql -U ardax -d ardax < db/004_protocolos.sql
--
-- POR QUÊ
-- Quando a API Python saiu do MVP, ficou uma dívida declarada: "a lógica
-- vive numa interface, não em arquivos -- diff de workflow do n8n é
-- ilegível". Prompt como linha de tabela devolve isso: versionável,
-- comparável, e BUSCÁVEL.
--
-- Tabela própria, não um tipo dentro de "itens": protocolo é configuração
-- do sistema, não conteúdo da vida do João. Misturar envelhece mal. O custo
-- de mudar de ideia é baixo nos dois sentidos -- são poucas linhas, e mover
-- depois é um INSERT ... SELECT.
--
-- REGRA DURA: aqui mora PROMPT, nunca QUERY.
-- Prompt é texto entregue a um modelo: veio errado, ele responde bobagem e
-- se corrige. Query é comando entregue ao banco -- se o SQL viesse de uma
-- linha, escrever uma linha passaria a ser escrever SQL, e quem escreve
-- linhas aqui é uma IA lendo Telegram. A coluna "ferramentas" guarda NOMES
-- de consultas de um catálogo fixo; o modelo escolhe entre o que existe,
-- nunca compõe.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE ardax.protocolos (
  nome          text PRIMARY KEY,
  rotulo        text NOT NULL,

  -- Palavras que ativam este protocolo. Chamada explícita ("k1n") é mais
  -- barata e mais confiável que fazer o modelo adivinhar toda vez.
  gatilhos      text[] NOT NULL DEFAULT '{}',

  -- O prompt INTEIRO, com marcadores [[DATA]] e [[MENSAGEM]].
  -- Marcador em colchetes, não em chaves: chave colidiria com a sintaxe de
  -- expressão do n8n e quebraria a leitura.
  prompt        text,

  -- Nomes de consultas do catálogo fixo. Nunca SQL.
  ferramentas   text[] NOT NULL DEFAULT '{}',

  -- Regras e preferências de como o João faz esta coisa.
  preferencias  jsonb NOT NULL DEFAULT '{}',

  ativo         boolean NOT NULL DEFAULT true,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER t_protocolos_atualizado BEFORE UPDATE ON ardax.protocolos
  FOR EACH ROW EXECUTE FUNCTION ardax.toca_atualizado();

-- GIN serve para perguntar "quais protocolos têm este gatilho".
CREATE INDEX ix_protocolos_gatilhos ON ardax.protocolos USING gin (gatilhos);

-- ═══ O protocolo de entrada — o classificador que hoje vive no nó ═══
-- Texto migrado do nó "Basic LLM Chain" do workflow Main, sem alteração
-- de conteúdo: só as expressões do n8n viraram marcadores.
INSERT INTO ardax.protocolos (nome, rotulo, gatilhos, prompt) VALUES (
  'entrada',
  'Classificador de entrada',
  '{}',
$prompt$Hoje é [[DATA]].

Você é o classificador de entrada de um sistema pessoal de captura.
Leia a mensagem e devolva um JSON.

MENSAGEM: [[MENSAGEM]]

Primeiro decida a INTENÇÃO:
- "capturar"  — está registrando algo novo
- "consultar" — está pedindo para ver o que há pra hoje
- "concluir"  — está dizendo que terminou algo ("feito 7", "terminei o 3")

Se for "concluir", devolva em "referencia" a LISTA de números citados.
Um número só vira lista de um: [7].
Intervalos viram a lista cheia: "de 3 a 6" vira [3,4,5,6].

Se for "consultar": devolva tudo nulo exceto a intenção.

Se for "capturar", classifique o TIPO entre os cinco que o sistema conhece:
- "tarefa" — uma ação com medida de conclusão
- "ideia"  — uma proposta que pede decisão, não uma ação já decidida
- "nota"   — uma informação afirmada, que não pede decisão
- "area"   — um recorte da vida (faculdade, saúde, casa)
- "tema"   — um assunto (termodinâmica, banco de dados)

E preencha:
- titulo: curto. Se for tarefa, comece por um verbo no infinitivo.
- prazo: AAAA-MM-DD. Converta referências relativas usando a data de hoje.
         Nulo se a mensagem não trouxer prazo. NUNCA invente prazo.
- necessidade: "obrigatoria" ou "opcional". Nulo se não der para saber.
- viabilidade: "viavel", "incerta" ou "inviavel". Nulo se não der para saber.

REGRA GERAL: na dúvida, devolva null. Campo vazio é informação honesta;
chute vira lixo que parece dado.

EXCEÇÃO — quando a intenção for "capturar", dois campos NUNCA podem ser nulos:
- titulo: se não der para extrair algo melhor, use a mensagem como ela veio.
- tipo: se não der para decidir, use "nota".

Capturar e não guardar nada é pior que guardar bruto.$prompt$
);

COMMIT;

-- ════════════════════════════════════════════════════════════════════
-- COMO O FLUXO USA ISTO
--
-- 1) Um nó de Postgres antes do LLM:
--      SELECT prompt FROM ardax.protocolos
--       WHERE nome = 'entrada' AND ativo;
--
-- 2) O nó de LLM troca o texto fixo por esta expressão, que substitui os
--    marcadores. Nota: o n8n NÃO avalia expressão vinda de dado, por isso
--    a substituição é explícita aqui:
--
--      {{ $json.prompt
--           .replaceAll('[[DATA]]', $now.setLocale('pt-BR').toFormat('yyyy-MM-dd, cccc'))
--           .replaceAll('[[MENSAGEM]]', $('Webhook').item.json.body.texto) }}
--
-- A partir daqui, mudar o comportamento do classificador é um UPDATE --
-- não abrir o n8n.
-- ════════════════════════════════════════════════════════════════════
