-- ════════════════════════════════════════════════════════════════════
-- Ardax — limpeza do esquema abandonado  [CAMINHO ALTERNATIVO]
--
-- ⚠️  NÃO É O CAMINHO PADRÃO.
--
-- O caminho escolhido em 2026-09-28 foi apagar o VOLUME inteiro e deixar o
-- Postgres nascer do zero com a imagem pgvector. Motivo: o banco só tinha o
-- teste de fumaça, e trocar de imagem alpine (musl) para Debian (glibc)
-- carregando o mesmo diretório de dados pode gerar divergência de
-- ordenação de texto — barato de evitar com o banco vazio, chato de
-- descobrir depois.
--
-- Este arquivo serve se um dia você QUISER preservar o volume e só remover
-- o esquema velho. Não roda no fluxo normal.
--
-- O que apagaria:
--   • schema "tarefas" (tabelas tarefa e trava) — modelo superado pelo
--     desenho de itens/ligacoes. Continha 1 linha: o teste de fumaça.
--   • public.alembic_version — o Alembic saiu junto com a API Python.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

DROP SCHEMA IF EXISTS tarefas CASCADE;
DROP TABLE IF EXISTS public.alembic_version;

COMMIT;
