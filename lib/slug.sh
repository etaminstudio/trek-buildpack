# Slug slimming and runtime environment. Build-only material (node_modules,
# Yarn machinery, caches) is removed after asset precompilation — on a typical
# Trek app this halves the image, speeding up shipping, restarts and scaling.

slug_prune() {
  topic "Slimming the slug"

  local before
  before="$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)"

  rm -rf \
    "$BUILD_DIR/node_modules" \
    "$BUILD_DIR/.yarn/cache" \
    "$BUILD_DIR/.yarn/unplugged" \
    "$BUILD_DIR/.yarn/install-state.gz" \
    "$BUILD_DIR/tmp/cache" \
    "$BUILD_DIR/log"

  if [ "${TREK_BUILDPACK_PRUNE_SOURCEMAPS:-}" = "1" ]; then
    info "TREK_BUILDPACK_PRUNE_SOURCEMAPS=1 — removing JS/CSS sourcemaps"
    find "$BUILD_DIR/public/assets" "$BUILD_DIR/app/assets/builds" \
      -name '*.map' -type f -delete 2>/dev/null || true
  fi

  info "Slug size: $before -> $(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)"
}

write_profile_d() {
  mkdir -p "$BUILD_DIR/.profile.d"
  cat > "$BUILD_DIR/.profile.d/000_trek_buildpack.sh" <<'EOF'
export PATH="$HOME/bin:$HOME/vendor/bundle/bin:$HOME/vendor/ruby/current/bin:$HOME/vendor/node/bin:$HOME/.apt/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.apt/usr/lib/x86_64-linux-gnu:$HOME/.apt/usr/lib:$LD_LIBRARY_PATH"
export LIBRARY_PATH="$HOME/.apt/usr/lib/x86_64-linux-gnu:$HOME/.apt/usr/lib:$LIBRARY_PATH"

export RAILS_ENV="${RAILS_ENV:-production}"
export RACK_ENV="${RACK_ENV:-$RAILS_ENV}"
export RAILS_LOG_TO_STDOUT="${RAILS_LOG_TO_STDOUT:-enabled}"
export RAILS_SERVE_STATIC_FILES="${RAILS_SERVE_STATIC_FILES:-enabled}"
EOF
}

# Build-time environment for buildpacks running after this one
# (multi-buildpack contract).
write_export_file() {
  cat > "$BP_DIR/export" <<EOF
export PATH="$PATH"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="${LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
EOF
}
