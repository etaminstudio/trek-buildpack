# Gem installation with a persistent vendor/bundle cache, invalidated when the
# Ruby version changes (native extensions are linked against a specific Ruby).

# The version named by `BUNDLED WITH` in Gemfile.lock.
bundler_version_from_lockfile() {
  local lock="$BUILD_DIR/Gemfile.lock"
  [ -f "$lock" ] || return 0
  awk '/^BUNDLED WITH$/ { getline; gsub(/[[:space:]]/, ""); print; exit }' "$lock"
}

# RubyGems activates the bundler named in the lockfile, so a slug carrying only
# the one shipped with Ruby dies at boot:
#
#   Activating bundler (~> 2.7) failed:
#   Could not find 'bundler' (~> 2.7) - did find: [bundler-2.6.9]
#
# The build itself survives the mismatch, which is what makes it worth
# installing here rather than trusting `bundle install` to have proved it.
#
# Installed into Ruby's own gem directory: that is on the runtime GEM_PATH,
# where a user install under HOME would not survive the move to /app.
bundler_ensure_version() {
  local wanted
  wanted="$(bundler_version_from_lockfile)"
  [ -n "$wanted" ] || return 0

  if gem list --installed --exact --version "$wanted" bundler >/dev/null 2>&1; then
    info "Bundler $wanted already present"
    return 0
  fi

  info "Installing bundler $wanted (Gemfile.lock)"
  GEM_HOME="$(ruby -e 'print Gem.default_dir')" \
    gem install bundler --version "$wanted" --no-document 2>&1 | indent
}

bundler_install() {
  topic "Installing gems"

  bundler_ensure_version

  local ruby_signature cached_signature
  ruby_signature="$(ruby -v)"
  cached_signature="$(cat "$CACHE_DIR/ruby-signature" 2>/dev/null || true)"

  if [ -d "$CACHE_DIR/vendor-bundle" ]; then
    if [ "$ruby_signature" = "$cached_signature" ]; then
      info "Restoring gem cache"
      mkdir -p "$BUILD_DIR/vendor"
      cp -a "$CACHE_DIR/vendor-bundle" "$BUILD_DIR/vendor/bundle"
    else
      info "Ruby version changed, clearing gem cache"
      info "Old: ${cached_signature:-none}"
      info "New: $ruby_signature"
      rm -rf "$CACHE_DIR/vendor-bundle"
    fi
  fi

  # Written before `bundle install` so the same configuration drives the build
  # and the runtime (env vars are not carried into the running container).
  mkdir -p "$BUILD_DIR/.bundle"
  cat > "$BUILD_DIR/.bundle/config" <<EOF
---
BUNDLE_PATH: "vendor/bundle"
BUNDLE_BIN: "vendor/bundle/bin"
BUNDLE_WITHOUT: "development:test"
BUNDLE_DEPLOYMENT: "true"
BUNDLE_CLEAN: "true"
EOF

  # /usr/bin/env shebangs keep binstubs working after the app moves to /app.
  (cd "$BUILD_DIR" && BUNDLE_SHEBANG=ruby bundle install --jobs 4 2>&1 | indent)

  export PATH="$BUILD_DIR/vendor/bundle/bin:$PATH"

  info "Caching gems"
  rm -rf "$BUILD_DIR/vendor/bundle/cache"
  rm -rf "$CACHE_DIR/vendor-bundle"
  cp -a "$BUILD_DIR/vendor/bundle" "$CACHE_DIR/vendor-bundle"
  echo "$ruby_signature" > "$CACHE_DIR/ruby-signature"
}
