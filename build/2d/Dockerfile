# Fixada de proposito: `latest` faria a saida mudar sem ninguem pedir, e o
# teste de integridade dos artefatos passaria a acusar deriva do toolchain
# como se fosse mudanca no jogo.
FROM emscripten/emsdk:6.0.8

# git para aplicar os patches sobre o clone.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/build-2d
RUN chmod +x /usr/local/bin/build-2d

ENTRYPOINT ["/usr/local/bin/build-2d"]
