FROM emscripten/emsdk:6.0.8

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/build-routes
RUN chmod +x /usr/local/bin/build-routes

ENTRYPOINT ["/usr/local/bin/build-routes"]
