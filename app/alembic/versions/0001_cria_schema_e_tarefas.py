"""Cria o schema tarefas e as tabelas tarefa e trava.

Escrita a mao de proposito: o Alembic sabe gerar isto sozinho, mas a primeira
vale ler linha a linha para entender o que uma migracao e'.

ID desta migracao: 0001
Vem depois de: nenhuma (e' a primeira)
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

SCHEMA = "tarefas"


def upgrade() -> None:
    """O caminho de ida: o que fazer para chegar neste estado."""

    op.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")

    op.create_table(
        "tarefa",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("pai_id", sa.BigInteger(), nullable=True),
        sa.Column("titulo", sa.Text(), nullable=False),
        sa.Column("resultado", sa.Text(), nullable=True),
        sa.Column("proxima_acao", sa.Text(), nullable=True),
        sa.Column("area", sa.Text(), nullable=True),
        sa.Column("contexto", sa.Text(), nullable=True),
        sa.Column("energia", sa.Text(), nullable=True),
        sa.Column("tamanho", sa.Text(), nullable=True),
        sa.Column("estado", sa.Text(), server_default="ativa", nullable=False),
        sa.Column("prazo", sa.Date(), nullable=True),
        sa.Column("motivo", sa.Text(), nullable=True),
        sa.Column("nota", sa.Text(), nullable=True),
        sa.Column(
            "criada_em",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("encerrada_em", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_tarefa"),
        sa.ForeignKeyConstraint(
            ["pai_id"],
            [f"{SCHEMA}.tarefa.id"],
            name="fk_tarefa_pai",
            ondelete="SET NULL",
        ),
        sa.CheckConstraint(
            "estado IN ('ativa', 'algum_dia', 'concluida', 'cancelada')",
            name="ck_tarefa_estado",
        ),
        sa.CheckConstraint(
            "(estado IN ('concluida', 'cancelada')) = (encerrada_em IS NOT NULL)",
            name="ck_tarefa_encerrada_coerente",
        ),
        schema=SCHEMA,
    )

    op.create_index("ix_tarefa_pai_id", "tarefa", ["pai_id"], schema=SCHEMA)
    op.create_index("ix_tarefa_area", "tarefa", ["area"], schema=SCHEMA)
    op.create_index("ix_tarefa_estado", "tarefa", ["estado"], schema=SCHEMA)

    op.create_table(
        "trava",
        sa.Column("tarefa_id", sa.BigInteger(), nullable=False),
        sa.Column("travada_por_id", sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint("tarefa_id", "travada_por_id", name="pk_trava"),
        sa.ForeignKeyConstraint(
            ["tarefa_id"],
            [f"{SCHEMA}.tarefa.id"],
            name="fk_trava_tarefa",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["travada_por_id"],
            [f"{SCHEMA}.tarefa.id"],
            name="fk_trava_travada_por",
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "tarefa_id <> travada_por_id", name="ck_trava_sem_autorreferencia"
        ),
        schema=SCHEMA,
    )


def downgrade() -> None:
    """O caminho de volta: desfaz exatamente o que o upgrade fez, na ordem inversa."""

    op.drop_table("trava", schema=SCHEMA)
    op.drop_index("ix_tarefa_estado", table_name="tarefa", schema=SCHEMA)
    op.drop_index("ix_tarefa_area", table_name="tarefa", schema=SCHEMA)
    op.drop_index("ix_tarefa_pai_id", table_name="tarefa", schema=SCHEMA)
    op.drop_table("tarefa", schema=SCHEMA)
    op.execute(f"DROP SCHEMA IF EXISTS {SCHEMA}")
