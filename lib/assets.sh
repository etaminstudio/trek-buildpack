# Rails asset precompilation. Runs after gems and npm packages are installed,
# so jsbundling's `yarn build` finds node_modules already populated and
# triggers no second install.

assets_precompile() {
  grep -q "rails" "$BUILD_DIR/Gemfile.lock" || return 0

  export RAILS_ENV="${RAILS_ENV:-production}"
  export RACK_ENV="${RACK_ENV:-$RAILS_ENV}"

  topic "Precompiling assets (RAILS_ENV=$RAILS_ENV)"
  (cd "$BUILD_DIR" && bundle exec rails assets:precompile 2>&1 | indent)
  (cd "$BUILD_DIR" && bundle exec rails assets:clean 2>&1 | indent)
}
