# FROM alpine:3 as builder
# # FROM nixos/nix:2.3.12 as builder

# # RUN nix-env -iA nixpkgs.nixUnstable
# # RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
# # RUN nix-channel --update

# RUN apk add -u rustup git gcc autoconf automake libtool binutils
# # RUN nix-env -i rustc cargo git gcc autoconf automake libtool binutils
# # RUN nix-env -i rustup git gcc autoconf automake libtool binutils
# RUN rustup-init -y
# RUN git clone https://github.com/spruceid/didkit.git
# RUN git clone --recurse-submodules https://github.com/identinet/ssi.git
# RUN source $HOME/.cargo/env && cd didkit && cargo build --release
# RUN find target

# FROM nixos/nix:2.3.12 as runtime

# COPY --from=builder

# RUN nix-env -i neovim curl


FROM clux/muslrust as builder

# RUN git clone https://github.com/spruceid/didkit.git /didkit
# RUN git clone --recurse-submodules https://github.com/identinet/ssi.git /ssi

COPY didkit /usr/src/didkit
COPY ssi /usr/src/ssi
WORKDIR /usr/src/didkit/cli

RUN cargo build --release

FROM alpine:3 as runtime
COPY --from=builder /usr/src/didkit/target/x86_64-unknown-linux-musl/release/didkit /usr/local/bin/didkit
ENTRYPOINT ["/usr/local/bin/didkit"]
