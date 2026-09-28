# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
