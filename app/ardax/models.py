"""Contrato de dados da Fase 1 (A1), descrito em Python.

Uma classe = uma tabela. Um atributo = uma coluna.
O Alembic le este arquivo para saber o que o banco deveria ter.
"""

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    MetaData,
    Text,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# Tudo vive no schema "tarefas", nao na pasta padrao do banco.
# Permite "notas" e "diario" depois, com consultas cruzando os tres.
SCHEMA = "tarefas"


class Base(DeclarativeBase):
    metadata = MetaData(schema=SCHEMA)


class Tarefa(Base):
    __tablename__ = "tarefa"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)

    # Hierarquia: de quem esta tarefa e' pedaco. Aponta para esta mesma tabela.
    # SET NULL: apagar o pai nao apaga os filhos, so os solta.
    pai_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("tarefas.tarefa.id", ondelete="SET NULL"), index=True
    )

    # O UNICO campo obrigatorio. Pilar 1: a captura tem que ser instantanea.
    titulo: Mapped[str] = mapped_column(Text, nullable=False)

    resultado: Mapped[str | None] = mapped_column(Text)
    proxima_acao: Mapped[str | None] = mapped_column(Text)

    # Texto livre de proposito: os valores nascem e morrem com o tempo.
    # Travar no banco faria cada valor novo virar migracao.
    area: Mapped[str | None] = mapped_column(Text, index=True)
    contexto: Mapped[str | None] = mapped_column(Text)
    energia: Mapped[str | None] = mapped_column(Text)
    tamanho: Mapped[str | None] = mapped_column(Text)

    # Unico com conjunto fechado -> vale a restricao, pega erro de digitacao.
    # "travada" NAO e' estado: e' calculado a partir da tabela trava.
    estado: Mapped[str] = mapped_column(
        Text, nullable=False, server_default="ativa", index=True
    )

    prazo: Mapped[date | None] = mapped_column(Date)
    motivo: Mapped[str | None] = mapped_column(Text)
    nota: Mapped[str | None] = mapped_column(Text)

    criada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    # Preenchida ao concluir OU cancelar. O estado diz qual dos dois foi.
    encerrada_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        CheckConstraint(
            "estado IN ('ativa', 'algum_dia', 'concluida', 'cancelada')",
            name="ck_tarefa_estado",
        ),
        # Encerrada tem data; ativa nao tem. Impede linha incoerente.
        CheckConstraint(
            "(estado IN ('concluida', 'cancelada')) = (encerrada_em IS NOT NULL)",
            name="ck_tarefa_encerrada_coerente",
        ),
    )


class Trava(Base):
    """Dependencia: quem precisa terminar antes de quem.

    Tabela propria porque uma tarefa pode ser travada por varias.
    Nao confundir com pai_id: pai e' "faz parte de", trava e' "vem depois de".
    """

    __tablename__ = "trava"

    tarefa_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("tarefas.tarefa.id", ondelete="CASCADE"), primary_key=True
    )
    travada_por_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("tarefas.tarefa.id", ondelete="CASCADE"), primary_key=True
    )

    __table_args__ = (
        CheckConstraint(
            "tarefa_id <> travada_por_id", name="ck_trava_sem_autorreferencia"
        ),
    )
