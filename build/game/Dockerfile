FROM debian:bookworm-slim

# nasm monta o assembly; o wlink do Open Watcom liga os .obj num executavel DOS.
# Nao existe ligador para OMF de 16 bits nos repositorios do Debian, por isso o
# Open Watcom vem da release oficial.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        nasm curl ca-certificates xz-utils zip git && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSL -o /tmp/ow.tar.xz \
      https://github.com/open-watcom/open-watcom-v2/releases/download/Current-build/ow-snapshot.tar.xz && \
    mkdir -p /opt/ow && \
    tar xJf /tmp/ow.tar.xz -C /opt/ow ./binl64/wlink && \
    rm /tmp/ow.tar.xz && \
    chmod +x /opt/ow/binl64/wlink

COPY build.sh /usr/local/bin/build-game
RUN chmod +x /usr/local/bin/build-game

ENTRYPOINT ["/usr/local/bin/build-game"]
