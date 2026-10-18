# ════════════════════════════════════════════════════════════════════
# Servidor de sincronizacao do Anki -- o oficial, nao o ankisyncd da
# comunidade (aquele fala um protocolo antigo que o AnkiDroid atual
# recusa).
#
# Desde a versao 2.1.57 o servidor vem DENTRO do pacote `anki` do PyPI,
# escrito em Rust. Nao precisa de Qt, nao precisa de tela: e' so
# `python -m anki.syncserver`. Imagem final ~250MB.
#
# A versao esta travada de proposito. Sincronizacao e' protocolo entre
# duas pontas; subir o servidor sem querer para uma versao que o
# AnkiDroid do celular nao fala quebraria o sync inteiro, e o conserto
# e' adivinhar qual versao era. Para atualizar: trocar aqui, de olho
# aberto, e testar.
# ════════════════════════════════════════════════════════════════════
FROM python:3.12-slim

ARG ANKI_VERSION=26.9.3
RUN pip install --no-cache-dir "anki==${ANKI_VERSION}"

# SYNC_BASE e' onde o servidor guarda as colecoes. Tem que ser volume:
# e' a copia autoritativa do que o celular manda.
ENV SYNC_BASE=/data \
    SYNC_HOST=0.0.0.0 \
    SYNC_PORT=8080

# -u desliga o buffer do stdout; sem isso o log do container so aparece
# em blocos e depurar sync fica as cegas.
CMD ["python", "-u", "-m", "anki.syncserver"]
