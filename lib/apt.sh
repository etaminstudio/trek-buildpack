# Installs the packages listed in Aptfile into $BUILD_DIR/.apt (extracted with
# dpkg, not installed system-wide — same technique as Scalingo's apt-buildpack).
#
# Improvements over apt-buildpack:
# - `apt-get update` + dependency resolution + download are skipped entirely
#   when the Aptfile (and stack) haven't changed — the cached .debs are reused.
# - Supported Aptfile syntax: one package per line, optionally followed by
#   apt-get flags (e.g. `libvips-tools --no-install-recommends`), blank lines
#   and `#` comments. Custom repos (`:repo:` lines) are not supported.

apt_install() {
  [ -f "$BUILD_DIR/Aptfile" ] || return 0

  local apt_cache="$CACHE_DIR/apt/cache"
  local apt_state="$CACHE_DIR/apt/state"
  local fingerprint_file="$CACHE_DIR/apt/fingerprint"
  local fingerprint
  fingerprint="$STACK:$(sha256sum "$BUILD_DIR/Aptfile" | cut -d' ' -f1)"

  mkdir -p "$apt_cache/archives/partial" "$apt_state/lists/partial"

  local apt_opts=(-o debug::nolocking=true -o dir::cache="$apt_cache" -o dir::state="$apt_state" -q -y)

  if [ "$(cat "$fingerprint_file" 2>/dev/null)" = "$fingerprint" ]; then
    topic "Reusing APT cache (Aptfile unchanged)"
  else
    topic "Downloading APT packages"
    rm -f "$apt_cache"/archives/*.deb
    apt-get "${apt_opts[@]}" update 2>&1 | indent

    local line
    while IFS= read -r line; do
      line="${line%%#*}"
      [ -n "${line// /}" ] || continue
      info "Fetching .debs for $line"
      # shellcheck disable=SC2086 — the line may carry extra apt-get flags
      apt-get "${apt_opts[@]}" -d install --reinstall --no-upgrade $line 2>&1 | indent
    done < "$BUILD_DIR/Aptfile"

    echo "$fingerprint" > "$fingerprint_file"
  fi

  topic "Installing APT packages into .apt"
  local deb
  for deb in "$apt_cache"/archives/*.deb; do
    [ -e "$deb" ] || continue
    dpkg -x "$deb" "$BUILD_DIR/.apt/"
  done
  info "$(ls "$apt_cache"/archives/*.deb 2>/dev/null | wc -l | tr -d ' ') packages installed"

  # Build-time environment so bundle install / native extensions find them.
  export PATH="$BUILD_DIR/.apt/usr/bin:$PATH"
  export LD_LIBRARY_PATH="$BUILD_DIR/.apt/usr/lib/x86_64-linux-gnu:$BUILD_DIR/.apt/usr/lib:${LD_LIBRARY_PATH:-}"
  export LIBRARY_PATH="$BUILD_DIR/.apt/usr/lib/x86_64-linux-gnu:$BUILD_DIR/.apt/usr/lib:${LIBRARY_PATH:-}"
  export INCLUDE_PATH="$BUILD_DIR/.apt/usr/include:$BUILD_DIR/.apt/usr/include/x86_64-linux-gnu:${INCLUDE_PATH:-}"
  export CPATH="$INCLUDE_PATH"
  export CPPPATH="$INCLUDE_PATH"
  export PKG_CONFIG_PATH="$BUILD_DIR/.apt/usr/lib/x86_64-linux-gnu/pkgconfig:$BUILD_DIR/.apt/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

  # Point pkg-config files at the extraction prefix.
  find "$BUILD_DIR/.apt" -type f -name '*.pc' \
    -exec sed -i "s|^prefix=|prefix=$BUILD_DIR/.apt|" {} + 2>/dev/null || true
}
