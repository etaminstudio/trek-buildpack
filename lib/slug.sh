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

# jemalloc, when the Aptfile asks for it (libjemalloc2): rv's Rubies aren't built with it, so it
# only takes over malloc when preloaded. Unless the app preloads it already, or opts out. The
# library is in the slug when apt installed it, or in the stack's image, which ships it from
# scalingo-26 on: apt then has nothing to install.
trek_jemalloc=""
for trek_jemalloc_path in "$HOME/.apt/usr/lib/x86_64-linux-gnu/libjemalloc.so.2" /usr/lib/x86_64-linux-gnu/libjemalloc.so.2; do
  if [ -f "$trek_jemalloc_path" ]; then
    trek_jemalloc="$trek_jemalloc_path"
    break
  fi
done
if [ -n "$trek_jemalloc" ] && grep -qs '^libjemalloc2' "$HOME/Aptfile" && [ "${TREK_BUILDPACK_JEMALLOC:-1}" != "0" ]; then
  case "$LD_PRELOAD" in
    *libjemalloc*) ;;
    *) export LD_PRELOAD="$trek_jemalloc${LD_PRELOAD:+ $LD_PRELOAD}" ;;
  esac
  # Give freed memory back to the system after a second, rather than ten
  export MALLOC_CONF="${MALLOC_CONF:-dirty_decay_ms:1000,muzzy_decay_ms:1000}"
fi
unset trek_jemalloc trek_jemalloc_path
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
