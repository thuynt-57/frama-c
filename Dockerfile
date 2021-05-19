FROM debian:sid as base

# Install non-OCaml dependencies + opam
RUN apt-get update && apt-get install -y \
    opam \
    z3 \
    && rm -rf /var/lib/apt/lists/*

RUN opam init --disable-sandboxing --compiler=ocaml-base-compiler.4.08.1 -y

# "RUN eval $(opam env)" does not work, so we manually set its variables
ENV OPAM_SWITCH_PREFIX "~/.opam/ocaml-base-compiler.4.08.1"
ENV CAML_LD_LIBRARY_PATH "~/.opam/ocaml-base-compiler.4.08.1/lib/stublibs:~/.opam/ocaml-base-compiler.4.08.1/lib/ocaml/stublibs:~/.opam/ocaml-base-compiler.4.08.1/lib/ocaml"
ENV OCAML_TOPLEVEL_PATH "~/.opam/ocaml-base-compiler.4.08.1/lib/toplevel"
ENV MANPATH "$MANPATH:~/.opam/ocaml-base-compiler.4.08.1/man"
ENV PATH "~/.opam/ocaml-base-compiler.4.08.1/bin:$PATH"

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
    why3.1.4.0 \
    yojson.1.7.0 \
    zarith.1.9.1 \
    zmq.5.1.3 \
    conf-python-3.1.0.0 \
    conf-time.1 \
    && rm -rf /var/lib/apt/lists/*

# Note: Debian's CVC is too recent for Why3, so we do not install the Debian
# package; instead, we download its binary and add it to a directory in PATH.
RUN wget https://github.com/CVC4/CVC4/releases/download/1.7/cvc4-1.7-x86_64-linux-opt -O /usr/local/bin/cvc4
RUN chmod a+x /usr/local/bin/cvc4

RUN why3 config detect

# with_source: keep Frama-C sources
ARG with_source=no

RUN cd /root && \
    git clone https://git.frama-c.com/pub/frama-c.git && \
    (cd frama-c && \
        autoconf && ./configure --disable-gui && \
        make -j && \
        make install \
    ) && \
    ([ "${with_source}" != "no" ] || rm -rf frama-c)

# with_test: run Frama-C tests; requires "with_source=yes"
ARG with_test=no

# run general tests, then test that WP can see external provers
RUN if [ "${with_test}" != "no" ]; then \
        cd /root/frama-c && \
        make tests PTESTS_OPTS=-error-code && \
        (cd src/plugins/wp/tests/ && \
         frama-c -wp wp_gallery/binary-multiplication-without-overflow.c \
         -wp-prover alt-ergo,cvc4); \
    fi
