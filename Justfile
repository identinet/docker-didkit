#!/usr/bin/env just --justfile
# Documentation: https://just.systems/man/en/
# Documentation: https://www.nushell.sh/book/
#
# Shell decativated so that bash is used by default. This simplifies CI integration
# set shell := ['nu', '-c']
# See https://hub.docker.com/r/nixos/nix/tags

NIXOS_VERSION := '2.25.1'

# Print this help
default:
    @just -l

# Format Justfile
format:
    @just --fmt --unstable

# Install git commit hooks
githooks:
    #!/usr/bin/env nu
    $env.config = { use_ansi_coloring: false, error_style: "plain" }
    let hooks_folder = '.githooks'
    if (do -i {git config core.hooksPath; or ""}) != $hooks_folder {
      print -e 'Installing git commit hooks'
      git config core.hooksPath $hooks_folder
      # npm install -g @commitlint/config-conventional
    }
    if not ($hooks_folder | path exists) {
      mkdir $hooks_folder
      "#!/usr/bin/env -S sh
    set -eu
    just test" | save $"($hooks_folder)/pre-commit"
      chmod 755 $"($hooks_folder)/pre-commit"
      "#!/usr/bin/env -S sh
    set -eu
    MSG_FILE=\"$1\"
    PATTERN='^(fix|feat|docs|style|chore|test|refactor|ci|build)(\\([a-z0-9/-]+\\))?!?: [a-z].+$'
    if ! head -n 1 \"${MSG_FILE}\" | grep -qE \"${PATTERN}\"; then
            echo \"Your commit message:\" 1>&2
            cat \"${MSG_FILE}\" 1>&2
            echo 1>&2
            echo \"The commit message must conform to this pattern: ${PATTERN}\" 1>&2
            echo \"Contents:\" 1>&2
            echo \"- follow the conventional commits style (https://www.conventionalcommits.org/)\" 1>&2
            echo 1>&2
            echo \"Example:\" 1>&2
            echo \"feat: add super awesome feature\" 1>&2
            exit 1
    fi" | save $"($hooks_folder)/commit-msg"
      chmod 755 $"($hooks_folder)/commit-msg"
      # if not (".commitlintrc.yaml" | path exists) {
      # "extends:\n  - '@commitlint/config-conventional'" | save ".commitlintrc.yaml"
      # }
      # git add $hooks_folder ".commitlintrc.yaml"
      git add $hooks_folder
    }

# Update repository
update:
    git pull --rebase
    git submoule update --init --recursive

# Build image
build: githooks
    #!/usr/bin/env nu
    let manifest = (open manifest.json)
    let image = $"($manifest.registry.name)/($manifest.name):($manifest.version)"
    print -e $"Building image ($image)"
    # If the Cargo.lock file doesn't exist, create it. It's required for the Nix build to work
    if not ("./didkit/didkit/Cargo.lock" | path exists) {
        cd didkit/didkit
        cargo update
    }
    # INFO: ?submodules=1 is required, see https://discourse.nixos.org/t/get-nix-flake-to-include-git-submodule/30324/3
    nix build '.?submodules=1'

# Load image locally
load: build
    #!/usr/bin/env nu
    ./result | docker image load

# Run image locally
run: load
    #!/usr/bin/env nu
    let manifest = (open manifest.json)
    let image = $"($manifest.registry.name)/($manifest.name):($manifest.version)"
    docker run --name $manifest.name -it --rm $image

# Run shell image locally
run-sh: load
    #!/usr/bin/env nu
    let manifest = (open manifest.json)
    let image = $"($manifest.registry.name)/($manifest.name):($manifest.version)"
    docker run --name $manifest.name -it --rm --entrypoint /bin/sh $image --

# Inspect image
inspect: build
    #!/usr/bin/env nu
    let manifest = (open manifest.json)
    let image = {
      RepoTags: [$manifest.version],
      Name: $"($manifest.registry.name)/($manifest.name)",
      Digest: $"Refer to just inspect-registry after pushing the image",
    }
    ./result | skopeo inspect --config docker-archive:/dev/stdin  | from json | merge $image

# Push image
push:
    #!/usr/bin/env nu
    let manifest = (open manifest.json)
    let image = $"($manifest.registry.name)/($manifest.name)"
    ./result | skopeo copy docker-archive:/dev/stdin $"docker://($image):($manifest.version)"
    just inspect-registry

# Bump version. LEVEL can be one of: major, minor, patch, premajor, preminor, prepatch, or prerelease.
bump LEVEL="patch" NEW_VERSION="":
    #!/usr/bin/env nu
    if (git rev-parse --abbrev-ref HEAD) != "main" {
      print -e "ERROR: A new release can only be created on the main branch."
      exit 1
    }
    if (git status --porcelain | wc -l) != "0" {
      print -e "ERROR: Repository contains uncommited changes."
      exit 1
    }
    # str replace -r "-.*" "" - strips git's automatic prerelease version
    let manifest = (open manifest.json)
    # let current_version = (git describe | str replace -r "-.*" "" | deno run npm:semver $in)
    let current_version = ($manifest.version |  deno run npm:semver $in)
    let new_version = if "{{ NEW_VERSION }}" == "" {$current_version | deno run npm:semver -i "{{ LEVEL }}" $in | lines | get 0} else {"{{ NEW_VERSION }}"}
    print "\nChangelog:\n"
    git cliff --strip all -u -t $new_version
    input -s $"Version will be bumped from ($current_version) to ($new_version)\nPress enter to confirm.\n"
    open manifest.json | upsert version $new_version | save -f manifest.json; git add manifest.json
    open README.md | str replace -a $current_version $new_version | collect | save -f README.md; git add README.md
    git cliff -t $new_version -o CHANGELOG.md; git add CHANGELOG.md
    git commit -n -m $"Release version ($new_version)"
    git tag -s -m $new_version $new_version
    git push --atomic origin refs/heads/main $"refs/tags/($new_version)"
    git cliff --strip all --current | gh release create -F - $new_version

# Release application
release: push

# CI pipeline task that will create a release of the package
ci:
    docker run -w "/app" -v "${PWD}:/app" -v "${DOCKER_CONFIG:-${HOME}/.docker}/config.json:/root/.docker/config.json" "nixos/nix:{{ NIXOS_VERSION }}" /bin/sh -c "nix-env -iA nixpkgs.just; just _ci"

# Release task that can only be executed within a NixOS environment
_ci:
    # Enable experimental flakes feature
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
    # Workaround if git directory doesn't belong to the current user, see bug https://github.com/NixOS/nix/issues/10202
    git config --global --add safe.directory "/app"
    mkdir -p /etc/containers
    # See https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md
    # Disable all container security by default
    echo '{ "default": [ { "type": "insecureAcceptAnything" } ] }' > /etc/containers/policy.json
    nix develop .#ci --command just release

# Run test
test:
    # no tests specified

# Clean files
clean: githooks
    rm -pf result
