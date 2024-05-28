# docker-didkit

Provides a [docker image](https://hub.docker.com/repository/docker/identinet/didkit-cli) for the excellent Self-Sovereign Identity toolkit [didkit](https://github.com/spruceid/didkit).

## Usage

Run the docker container with the following command and pass parameters to `didkit`:

```bash
docker run -it --rm identinet/didkit-cli:0.3.2.0 help
```

Make files from the local file system available to didkit by mounting them:

```bash
docker run -it --rm -u "$(id -u):$(id -g)" -v "$PWD:/run/didkit" identinet/didkit-cli:0.3.2.0 key to did --key-path key.jwk
```

## Development

### Clone Repository

```bash
git clone git@github.com:identinet/docker-didkit.git

# then, update submodules via

git submoule update --init --recursive

# or

just update
```

### Build Container Image

[Nix](https://nixos.org) is required to build the image:

```bash
just build
```
