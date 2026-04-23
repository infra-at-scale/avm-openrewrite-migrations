# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0](https://github.com/infra-at-scale/avm-openrewrite-migrations/releases/tag/v0.1.0) - 2026-04-23

### Added

Initial release of avm-openrewrite-migrations with 6 migration recipes:

**Networking**

- `avm-res-network-virtualnetwork-010-to-011.yaml`: Migrate avm-res-network-virtualnetwork from 0.10.x to 0.11.x
- `avm-res-network-virtualnetwork-014-to-015.yaml`: Migrate avm-res-network-virtualnetwork from 0.14.x to 0.15.x
- `avm-res-network-privatednszone-03x-to-04x.yaml`: Migrate avm-res-network-privatednszone from 0.3.x to 0.4.0
- `avm-res-network-networksecuritygroup-02x-to-03x.yaml`: Migrate avm-res-network-networksecuritygroup from 0.2.x to 0.3.x

**Security**

- `avm-res-keyvault-vault-08x-to-09x.yaml`: Migrate avm-res-keyvault-vault from 0.8.x to 0.9.x

**Storage**

- `avm-res-storage-storageaccount-064-to-065.yaml`: Migrate avm-res-storage-storageaccount from 0.64.x to 0.65.x

### Features

- OpenRewrite YAML recipe format for deterministic Terraform/OpenTofu migrations
- Comprehensive USAGE documentation in each recipe file
- Support for Gradle properties to parameterize migrations
- Safe dry-run mode to preview changes before applying
- Idempotent recipes that can be run multiple times safely
