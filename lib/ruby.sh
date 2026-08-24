# Ruby installation via rv (https://rv.dev): precompiled portable Rubies,
# version discovered by rv itself from .ruby-version, .tool-versions, or
# Gemfile.lock.

rv_install() {
  local rv_dir="$CACHE_DIR/rv/$RV_VERSION"

  if [ ! -x "$rv_dir/rv" ]; then
    topic "Downloading rv $RV_VERSION"
    rm -rf "$CACHE_DIR/rv"
    mkdir -p "$rv_dir"
    local base="https://github.com/spinel-coop/rv/releases/download/v$RV_VERSION"
    local tarball="rv-x86_64-unknown-linux-gnu.tar.xz"
    curl --fail --retry 3 --location --silent --show-error \
      -o "$rv_dir/$tarball" "$base/$tarball"
    curl --fail --retry 3 --location --silent --show-error \
      -o "$rv_dir/$tarball.sha256" "$base/$tarball.sha256"
    (cd "$rv_dir" && sha256sum --check --quiet "$tarball.sha256") \
      || fail "Checksum verification failed for rv $RV_VERSION"
    tar -xJf "$rv_dir/$tarball" --strip-components=1 -C "$rv_dir"
    rm -f "$rv_dir/$tarball" "$rv_dir/$tarball.sha256"
  fi

  export PATH="$rv_dir:$PATH"
  # Persist rv's own download cache (Ruby tarballs) between builds.
  export XDG_CACHE_HOME="$CACHE_DIR/xdg-cache"
}

ruby_install() {
  topic "Installing Ruby"
  (cd "$BUILD_DIR" && rv ruby install --install-dir "$BUILD_DIR/vendor/ruby" 2>&1 | indent)

  local ruby_home
  ruby_home="$(find "$BUILD_DIR/vendor/ruby" -maxdepth 1 -type d -name 'ruby-*' | head -1)"
  [ -n "$ruby_home" ] || fail "Ruby installation not found in vendor/ruby"

  # Stable, relocatable path for PATH entries: a relative symlink survives the
  # move from the build directory to /app at runtime.
  ln -sfn "$(basename "$ruby_home")" "$BUILD_DIR/vendor/ruby/current"

  export PATH="$BUILD_DIR/vendor/ruby/current/bin:$PATH"
  info "Using $(ruby -v)"
}
