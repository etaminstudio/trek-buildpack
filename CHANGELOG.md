# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-08-24

### Added

- Initial buildpack: APT packages from `Aptfile` (with fingerprint-based cache reuse), Ruby via rv (pinned by `.ruby-version`), Bundler with a Ruby-version-keyed gem cache, build-time-only Node.js (pinned by `.node-version`) with Corepack-provided Yarn, single `yarn install` before `assets:precompile`, and slug slimming.
