# Exports the app's environment variables (one file per variable in ENV_DIR)
# into the build environment, minus variables that would break the build.

export_env_dir() {
  [ -n "$ENV_DIR" ] && [ -d "$ENV_DIR" ] || return 0

  local denylist='^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|LD_LIBRARY_PATH|JAVA_OPTS|BUILD_DIR|CACHE_DIR|ENV_DIR|HOME|LANG|BUILDPACK_URL)$'
  local file name

  for file in "$ENV_DIR"/*; do
    [ -f "$file" ] || continue
    name="$(basename "$file")"
    if ! [[ "$name" =~ $denylist ]]; then
      export "$name=$(cat "$file")"
    fi
  done
}
