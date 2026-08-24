# Node.js + Yarn, build-time only. Node is installed into the build cache and
# never enters the slug (Rails needs no Node at runtime once assets are built);
# set TREK_BUILDPACK_RUNTIME_NODE=1 to ship it in the slug anyway.
#
# The Node version is read from .node-version, then .tool-versions. Yarn is the
# exact release pinned by package.json's `packageManager` field, downloaded
# straight from repo.yarnpkg.com (Corepack is gone from Node >= 25 downloads,
# and Yarn berry is a single yarn.js file anyway).

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

  yarn_install_cli

  info "Using node $(node --version), yarn $(cd "$BUILD_DIR" && yarn --version)"

  if [ "${TREK_BUILDPACK_RUNTIME_NODE:-}" = "1" ]; then
    info "TREK_BUILDPACK_RUNTIME_NODE=1 — shipping Node.js in the slug"
    mkdir -p "$BUILD_DIR/vendor"
    cp -a "$node_dir" "$BUILD_DIR/vendor/node"
  fi
}

# Installs the Yarn CLI pinned by `packageManager` (e.g. "yarn@4.18.0") and
# puts a `yarn` shim on the build PATH.
yarn_install_cli() {
  local pin version
  pin="$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$BUILD_DIR/package.json" | head -1)"
  case "$pin" in
    yarn@*) version="${pin#yarn@}" ;;
    "") fail "No \"packageManager\" field in package.json — pin one, e.g. \"yarn@4.18.0\"" ;;
    *) fail "Unsupported package manager \"$pin\" (only yarn is supported)" ;;
  esac

  local yarn_js="$CACHE_DIR/yarn/$version/yarn.js"
  if [ ! -f "$yarn_js" ]; then
    info "Downloading Yarn $version"
    rm -rf "$CACHE_DIR/yarn"
    mkdir -p "$CACHE_DIR/yarn/$version"
    curl --fail --retry 3 --location --silent --show-error \
      -o "$yarn_js" "https://repo.yarnpkg.com/$version/packages/yarnpkg-cli/bin/yarn.js"
  fi

  local shim_dir="$CACHE_DIR/shims"
  rm -rf "$shim_dir"
  mkdir -p "$shim_dir"
  cat > "$shim_dir/yarn" <<EOF
#!/usr/bin/env bash
exec node "$yarn_js" "\$@"
EOF
  chmod +x "$shim_dir/yarn"
  export PATH="$shim_dir:$PATH"
}

yarn_install() {
  [ -f "$BUILD_DIR/package.json" ] || return 0

  topic "Installing npm packages"
  # Berry keeps its global folder (including the package cache) here.
  export YARN_GLOBAL_FOLDER="$CACHE_DIR/yarn-global"
  (cd "$BUILD_DIR" && yarn install --immutable 2>&1 | indent)
}
