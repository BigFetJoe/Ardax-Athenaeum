"""Ponte entre o Alembic e o projeto.

Faz duas coisas: pega a URL do banco da variavel de ambiente (nunca do arquivo
.ini, que vai para o git) e entrega os modelos ao Alembic para comparacao.
"""

import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from ardax.models import SCHEMA, Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# A URL vem do ambiente. Se faltar, falha alto -- mesma licao do bot.js.
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    raise RuntimeError("DATABASE_URL ausente. Abortando.")
config.set_main_option("sqlalchemy.url", database_url)

# O que o banco DEVERIA ter, segundo models.py.
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Gera o SQL sem conectar. Util para revisar antes de aplicar."""
    context.configure(
        url=database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        include_schemas=True,
        version_table_schema=SCHEMA,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Conecta no banco e aplica de verdade."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_schemas=True,
            # A tabela de controle do Alembic tambem mora no schema tarefas.
            version_table_schema=SCHEMA,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
