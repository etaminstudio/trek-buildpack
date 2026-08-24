# Log helpers matching the classic buildpack output style.

topic() {
  echo "-----> $*"
}

info() {
  echo "       $*"
}

# Pipe command output through this to get the standard 7-space indent.
indent() {
  sed -u 's/^/       /'
}

warn() {
  echo " !     $*" >&2
}

fail() {
  warn "$*"
  exit 1
}
