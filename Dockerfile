


FROM debian:buster as base

USER root

# Install non-OCaml dependencies + opam
RUN apt-get update && apt-get install -y \
    cvc4 \
    opam \
    z3 \
    && rm -rf /var/lib/apt/lists/*

RUN opam init --disable-sandboxing --compiler=ocaml-base-compiler.4.08.1 -y

# "RUN eval $(opam env)" does not work, so we manually set its variables
ENV OPAM_SWITCH_PREFIX "/root/.opam/ocaml-base-compiler.4.08.1"
ENV CAML_LD_LIBRARY_PATH "/root/.opam/ocaml-base-compiler.4.08.1/lib/stublibs:/root/.opam/ocaml-base-compiler.4.08.1/lib/ocaml/stublibs:/root/.opam/ocaml-base-compiler.4.08.1/lib/ocaml"
ENV OCAML_TOPLEVEL_PATH "/root/.opam/ocaml-base-compiler.4.08.1/lib/toplevel"
ENV MANPATH "$MANPATH:/root/.opam/ocaml-base-compiler.4.08.1/man"
ENV PATH "/root/.opam/ocaml-base-compiler.4.08.1/bin:$PATH"

RUN opam update -y && opam install depext -y

# Install packages from reference configuration
# Note: Python and time packages are only required for tests, but if so,
# they need to be present before running './configure'
RUN apt-get update && opam update -y && opam depext --install -y --verbose \
    alt-ergo.2.2.0 \
    apron.v0.9.12 \
    conf-graphviz.0.1 \
    mlgmpidl.1.2.12 \
    ocamlfind.1.8.1 \
    ocamlgraph.1.8.8 \
    ppx_deriving_yojson.3.5.2 \
    why3.1.3.3 \
    yojson.1.7.0 \
    zarith.1.9.1 \
    zmq.5.1.3 \
    conf-python-3.1.0.0 \
    conf-time.1 \
    && rm -rf /var/lib/apt/lists/*

RUN why3 config --detect

# with_source: keep Frama-C sources
ARG with_source=no

RUN cd /root && \
    wget http://frama-c.com/download/frama-c-22.0-Titanium.tar.gz && \
    tar xvf frama-c-*.tar.gz && \
    (cd frama-c-* && \
        ./configure --disable-gui && \
        make -j && \
        make install \
    ) && \
    rm -f frama-c-*.tar.gz && \
    ([ "${with_source}" != "no" ] || rm -rf frama-c-*)

# with_test: run Frama-C tests; requires "with_source=yes"
ARG with_test=no

# run general tests, then test that WP can see external provers
RUN if [ "${with_test}" != "no" ]; then \
        cd /root/frama-c-* && \
        make tests PTESTS_OPTS=-error-code && \
        (cd src/plugins/wp/tests/ && \
         frama-c -wp wp_gallery/binary-multiplication-without-overflow.c \
         -wp-prover alt-ergo,cvc4); \
    fi

