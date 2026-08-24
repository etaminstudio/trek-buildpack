# Node.js + Yarn, build-time only. Node is installed into the build cache and
# never enters the slug (Rails needs no Node at runtime once assets are built);
# set TREK_BUILDPACK_RUNTIME_NODE=1 to ship it in the slug anyway.
#
# The Node version is read from .node-version, then .tool-versions; Yarn is
# whatever the app's package.json `packageManager` field pins, via Corepack.

node_version() {
  local version=""
  if [ -f "$BUILD_DIR/.node-version" ]; then
    version="$(head -1 "$BUILD_DIR/.node-version" | tr -d 'v[:space:]')"
  elif [ -f "$BUILD_DIR/.tool-versions" ]; then
    version="$(awk '$1 == "nodejs" || $1 == "node" { print $2; exit }' "$BUILD_DIR/.tool-versions")"
  fi
  echo "$version"
}

node_install() {
  [ -f "$BUILD_DIR/package.json" ] || return 0

  local version
  version="$(node_version)"
  if [ -z "$version" ]; then
    warn "No .node-version or .tool-versions found."
    warn "Falling back to Node.js $DEFAULT_NODE_VERSION — pin a version to control upgrades."
    version="$DEFAULT_NODE_VERSION"
  fi

  topic "Installing Node.js $version (build-time only)"

  local node_name="node-v$version-linux-x64"
  local node_dir="$CACHE_DIR/node/$node_name"

  if [ ! -x "$node_dir/bin/node" ]; then
    rm -rf "$CACHE_DIR/node"
    mkdir -p "$CACHE_DIR/node"
    local base="https://nodejs.org/dist/v$version"
    curl --fail --retry 3 --location --silent --show-error \
      -o "$CACHE_DIR/node/$node_name.tar.xz" "$base/$node_name.tar.xz"
    curl --fail --retry 3 --location --silent --show-error \
      -o "$CACHE_DIR/node/SHASUMS256.txt" "$base/SHASUMS256.txt"
    (cd "$CACHE_DIR/node" && grep " $node_name.tar.xz\$" SHASUMS256.txt | sha256sum --check --quiet) \
      || fail "Checksum verification failed for Node.js $version"
    tar -xJf "$CACHE_DIR/node/$node_name.tar.xz" -C "$CACHE_DIR/node"
    rm -f "$CACHE_DIR/node/$node_name.tar.xz" "$CACHE_DIR/node/SHASUMS256.txt"
  else
    info "Reusing cached Node.js"
  fi

  export PATH="$node_dir/bin:$PATH"

  # Corepack provides the Yarn version pinned by package.json `packageManager`,
  # cached between builds.
  export COREPACK_HOME="$CACHE_DIR/corepack"
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  corepack enable --install-directory "$node_dir/bin" 2>&1 | indent

  info "Using node $(node --version), yarn $(cd "$BUILD_DIR" && yarn --version)"

  if [ "${TREK_BUILDPACK_RUNTIME_NODE:-}" = "1" ]; then
    info "TREK_BUILDPACK_RUNTIME_NODE=1 — shipping Node.js in the slug"
    mkdir -p "$BUILD_DIR/vendor"
    cp -a "$node_dir" "$BUILD_DIR/vendor/node"
  fi
}

yarn_install() {
  [ -f "$BUILD_DIR/package.json" ] || return 0

  topic "Installing npm packages"
  # Berry keeps its global folder (including the package cache) here.
  export YARN_GLOBAL_FOLDER="$CACHE_DIR/yarn-global"
  (cd "$BUILD_DIR" && yarn install --immutable 2>&1 | indent)
}
