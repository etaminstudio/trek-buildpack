# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Preload jemalloc when the `Aptfile` installs it (`libjemalloc2`, in Trek's `Aptfile`). rv's Rubies aren't built with jemalloc, so until now the library was installed but never used: apps ran on glibc's allocator, whose memory grows with fragmentation. The runtime environment now sets `LD_PRELOAD` to it, and `MALLOC_CONF` to `dirty_decay_ms:1000,muzzy_decay_ms:1000` unless the app sets its own. `TREK_BUILDPACK_JEMALLOC=0` opts out.

## [0.1.2] - 2026-09-29

### Fixed

- Force the Bundler install past the default gem: `bundler` ships with Ruby, so `bin/bundle` already exists and RubyGems refused to overwrite it — `"bundle" from bundler conflicts with vendor/ruby/*/bin/bundle` — which failed the build outright.

### Documentation

- Give the pinned archive URL in the README, and say why `#ref` does not work: Scalingo reads it as a branch, so a tag returns 404. Also note that a `.buildpacks` file takes precedence over `BUILDPACK_URL`.

## [0.1.1] - 2026-09-29

### Fixed

- Install the Bundler version named by `BUNDLED WITH` in `Gemfile.lock`. RubyGems activates that version at boot, so an app whose lockfile asks for a Bundler newer than the one shipped with Ruby built fine and then died on start with `Could not find 'bundler' (~> 2.7)`.

## [0.1.0] - 2026-08-24

### Added

- Initial buildpack: APT packages from `Aptfile` (with fingerprint-based cache reuse), Ruby via rv (pinned by `.ruby-version`), Bundler with a Ruby-version-keyed gem cache, build-time-only Node.js (pinned by `.node-version`) with Corepack-provided Yarn, single `yarn install` before `assets:precompile`, and slug slimming.
