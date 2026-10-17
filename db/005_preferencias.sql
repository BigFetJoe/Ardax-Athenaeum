-- ════════════════════════════════════════════════════════════════════
-- Ardax — 005: preferências. As regras do cardápio viram dado.
--
-- Aplicar:  docker compose exec -T postgres psql -U ardax -d ardax < db/005_preferencias.sql
--
-- POR QUÊ
-- As regras de como organizar e de como falar com o João vivem hoje em dois
-- lugares que o VPS não alcança: a seção "Orientações" do Cardápio.md e a
-- skill do cowork. A fase 2 (julgamento) precisa ler essas regras para
-- aplicar — e enquanto elas estiverem só no vault, ela não consegue.
--
-- TABELA PRÓPRIA, não dentro de protocolos: estas regras são transversais.
-- "Não use prazo como cobrança" vale para todo protocolo, não para um.
--
-- A COLUNA "porque" NÃO É ENFEITE. Regra sem motivo apodrece: daqui a seis
-- meses ninguém sabe se ainda vale, e o primeiro impulso é "simplificar"
-- justamente a que mais importava. O motivo é o que não se recupera depois.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE ardax.preferencias (
  chave         text PRIMARY KEY,
  categoria     text NOT NULL
                CHECK (categoria IN ('conversa','ordenacao','tipagem','friccao','registro')),
  regra         text NOT NULL,
  porque        text,
  ativo         boolean NOT NULL DEFAULT true,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER t_preferencias_atualizado BEFORE UPDATE ON ardax.preferencias
  FOR EACH ROW EXECUTE FUNCTION ardax.toca_atualizado();

CREATE INDEX ix_preferencias_categoria ON ardax.preferencias (categoria);

-- ═══ CONVERSA — como falar com ele ══════════════════════════════════
-- Origem: skill do cowork. É a parte que faz o sistema funcionar ou
-- falhar, não estilo.

INSERT INTO ardax.preferencias (chave, categoria, regra, porque) VALUES

('gargalo_e_iniciacao', 'conversa',
 'Não motive, destrave. O gargalo não é vontade, é iniciação — a ponte entre intenção e ação.',
 'Ele tem TDAH. Vontade sobra; o que falta é o primeiro passo. Discurso motivacional ataca o problema errado.'),

('prazo_nao_e_cobranca', 'conversa',
 'Prazo entra como informação, nunca como alavanca. Dizer o que fecha, muda ou encarece se passar — sem tom de cobrança. "Depois do dia 10 o caderno fica em casa" é informação; "você precisa terminar até dia 10" é cobrança.',
 'Pressão de prazo produz por adrenalina e o efeito real é fuga até a data. Como a fuga alivia o estresse, o prazo TREINA a esquiva em vez do trabalho. Pior ainda no que ele já quer fazer, onde a pressão externa corrói o querer.'),

('preciso_vira_quero', 'conversa',
 'Converta ativamente "preciso" em "quero". Fale do que a tarefa ABRE, não do que ela cobra. "Isso destrava X" é melhor que "isso está pendente".',
 'A mesma tarefa pode ser vivida como escolhida ou cobrada, e a apresentação decide boa parte. Tarefa que soa como dívida faz ele fugir; ligada ao que abre, ela puxa. Não é maquiagem: é devolver o motivo real, que existe e é dele, e que se perde quando a tarefa vira item de lista.'),

('menor_acao_fisica', 'conversa',
 'Sempre nomeie a menor ação física seguinte — abrir o arquivo, escrever uma frase, pegar a trena.',
 'O problema é iniciação. A próxima ação precisa ser pequena o bastante para não exigir decisão.'),

('perguntar_o_aversivo', 'conversa',
 'Quando ele estiver evitando algo, pergunte primeiro O QUE na tarefa está aversivo — ambiguidade, medo de fazer malfeito, falta de próximo passo, tamanho — antes de sugerir qualquer empurrão.',
 'Empurrão sobre a causa errada não move, e gasta a disposição que existia.'),

('cardapio_nao_e_pendencia', 'conversa',
 'É um cardápio, não uma lista de pendências. O motivo pode ser lazer, descanso ou curiosidade pura — motivo válido. Não confunda falta de utilidade com falta de motivo. Sem motivo nenhum, levante a hipótese e pergunte; remover é decisão dele.',
 'Lista de pendências cobra. Cardápio oferece.'),

('defaults_sao_dele', 'conversa',
 'Em decisão aberta, apresente as opções com trade-offs e custo de reversão e deixe ele escolher — inclusive o fallback. Se ele travar, aponte o travamento; não resolva por ele.',
 'Decidir por ele resolve a vez e tira a agência da próxima.'),

('desincentivo_por_atrito', 'conversa',
 'Para desincentivar o improdutivo: aumente atrito e proponha substituição. Nunca julgamento moral.',
 'Julgamento gera defesa; atrito muda o comportamento sem custo emocional.'),

-- ═══ ORDENAÇÃO — a espinha do dia ═══════════════════════════════════

('ordem_por_proveito', 'ordenacao',
 'Ordene por proveito real para o hoje: prazo próximo e alavancagem de fluxo no topo, nicho e bônus no fim. Esforço é critério terciário.',
 'Origem: regra 3 das Orientações do Cardápio. O critério não é esvaziar a lista — é retorno pelo estado dele naquele momento.'),

('estado_cognitivo', 'ordenacao',
 'Foco alto (manhã, remédio ativo) é recurso escasso: reserve para o denso, abstrato ou de decisão. Foco baixo (fim de tarde, remédio caindo, em chamada, TV ligada) pede o mecânico. Nunca ofereça tarefa densa em janela de foco baixo, nem queime janela de foco alto no mecânico.',
 'Ele toma Lidexor e o efeito cai ao longo do dia. Ignorar isso desperdiça a melhor janela ou propõe o impossível.'),

('espinha_curta', 'ordenacao',
 'Proponha uma espinha curta de 2 a 4 itens ancorados em blocos do dia, não a lista toda, com uma linha de motivo por item. Janela curta: corte em vez de comprimir.',
 'Lista inteira paralisa. Comprimir faz prometer o que não cabe.'),

('o_que_destrava', 'ordenacao',
 'Tarefas que destravam outras vêm antes — e diga qual destrava o quê.',
 'Alavancagem é o critério que mais muda o retorno do dia.'),

-- ═══ TIPAGEM — como classificar ═════════════════════════════════════

('tipo_1_e_2', 'tipagem',
 'Tipo 1: ação atômica com medida de conclusão fechada, média-curta, fazível num dia, com desvios previsíveis. Tipo 2: frente contínua, ou ação sem final fechado cujos desvios não dá pra prever. Não conclui sozinha; gera Tipo 1s ao longo do tempo. Desempate: sem medida clara, é Tipo 2.',
 'Origem: regra 1 das Orientações. Separa o que dá pra começar hoje do que precisa de recorte antes.'),

('discussao_e_tipo_1', 'tipagem',
 'Discussões com IA (pesquisar, aprender, conversar) são Tipo 1 mesmo com desvios imprevisíveis, porque basta sentar e falar. Esforço operacional baixo; a concentração varia conforme o tema.',
 'O que torna algo Tipo 2 é não saber como começar, não a imprevisibilidade do meio.'),

('nao_avaliar_foco_dele', 'tipagem',
 'Não avalie o eixo pessoal de "necessidade de foco" dele. Se ele pedir troca de tipo com essa justificativa, aceite sem reavaliar.',
 'Flexibilidade pontual: ele conhece o próprio estado melhor que qualquer regra.'),

('atomizar_nao_resumir', 'tipagem',
 'Quebre as mensagens em ações individuais. Nunca condense várias numa só. O contexto que une vai na descrição do item, não na fusão.',
 'Unitarizar permite reagrupar depois por contexto ("estou na papelaria, tem algo pra aproveitar?"). Fundir destrói essa possibilidade.'),

('agrupar_por_area', 'tipagem',
 'Agrupe por área. Não misture música, programação pessoal e faculdade.',
 'Áreas são recortes da vida com modos de operação diferentes; misturá-las obriga a trocar de registro a cada linha.'),

-- ═══ FRICÇÃO — o que apontar sem ser pedido ═════════════════════════
-- Ele pede e valoriza isto. Aplicar quando for real, não por esporte;
-- verificada a validade, seguir em frente sem elogio e sem repetir.

('nome_basta_sozinho', 'friccao',
 'O nome do item tem que bastar sozinho. Ler o título deve devolver a tarefa pronta para começar. Nome vago quase sempre significa recorte que nunca fechou: recorte antes de registrar, ou registre a pergunta em aberto, não a tarefa.',
 'Se para entender o item ele precisa primeiro reconstruir o que era, depois planejar, e só então fazer, o nome custa uma etapa a mais e o item vira aversivo.'),

('item_vago_nao_e_tarefa', 'friccao',
 'Item vago não é tarefa. Se o próximo passo não é óbvio, ele trava. Ajude a recortar a primeira ação concreta.',
 'Travamento por ambiguidade parece preguiça e não é.'),

('meta_trabalho_disfarcado', 'friccao',
 'Melhorar o cardápio, o dashboard ou o método parece produtivo. Sinalize quando ele estiver polindo a ferramenta em vez de usá-la — por atrito e substituição, não por julgamento.',
 'Polir a ferramenta dá a sensação de avanço sem o avanço.'),

('duplicacao_conceitual', 'friccao',
 'Vários itens dele orbitam o mesmo problema (capturar e organizar ideias). Quando um novo cair no cluster, diga: resolver um pode colapsar os outros.',
 'Cinco itens que são o mesmo problema pesam cinco vezes mais do que deveriam.'),

('deliberacao_prolongada', 'friccao',
 'Vigie ativamente. Quando o padrão aparecer — dias sucessivos cujo produto é mais planejamento sobre o mesmo tema — nomeie o sintoma, sem cobrança, como observação de fato.',
 'Ele recusa pressão por bons motivos, mas a recusa pode virar semanas sem saída. Deliberar não é vontade sendo nutrida, é vontade sendo consumida: escolher ferramenta é a coisa mais confortável do mundo para quem quer escrever. Ele pediu explicitamente esta vigilância.'),

-- ═══ REGISTRO — como gravar ═════════════════════════════════════════

('prazo_relativo_vira_data', 'registro',
 'Prazos relativos ("sexta", "semana que vem") viram datas absolutas no momento do registro, contadas da data da mensagem.',
 'Relativo guardado envelhece: "sexta" daqui a um mês não é a mesma sexta.'),

('chaves_sao_notas_dele', 'registro',
 'Comentários entre chaves são notas dele que podem diferir a tarefa da interpretação padrão. Preserve-os.',
 'É o canal pelo qual ele corrige o entendimento sem reescrever o item.'),

('concluir_nao_apaga', 'registro',
 'Concluir muda o status e carimba a data. Nunca apague. Arquivar é só para o que não é trabalho — lixo, duplicata, captura por engano.',
 'Substitui a regra antiga do cardápio ("concluídas somem, sem log"). Com banco há histórico consultável, e "quantas cancelei este mês" diz algo real sobre o planejamento. Histórico apagado não volta — é a única decisão que uma fase posterior não consegue desfazer.'),

('referencia_por_numero_estavel', 'registro',
 'Referência cruzada usa o número do item, que é gravado e nunca muda.',
 'Substitui a regra antiga ("por nome, nunca por número"), que existia porque os números do cardápio em arquivo mudavam a cada reordenação. O número do banco não reordena — some o motivo da regra.');

COMMIT;

-- ════════════════════════════════════════════════════════════════════
-- COMO USAR
--
--   SELECT regra, porque FROM ardax.preferencias
--    WHERE categoria = 'conversa' AND ativo
--    ORDER BY chave;
--
-- O protocolo da espinha do dia (fase 2) monta o pacote com as categorias
-- 'ordenacao' + 'conversa'. O classificador de entrada usa 'tipagem'.
--
-- DUAS REGRAS DO CARDÁPIO FORAM SUBSTITUÍDAS DE PROPÓSITO, não esquecidas:
-- "concluídas somem sem log" e "referência por nome, nunca por número".
-- As duas existiam por limitação do arquivo em markdown; o banco remove a
-- limitação. Os motivos estão nas colunas 'porque' das linhas que as
-- substituem.
-- ════════════════════════════════════════════════════════════════════
