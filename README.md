# avm-openrewrite-migrations

[![Latest Release](https://img.shields.io/github/v/release/infra-at-scale/avm-openrewrite-migrations?label=release)](https://github.com/infra-at-scale/avm-openrewrite-migrations/releases/latest)

Safe, deterministic [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) (AVM) migrations for [OpenTofu](https://opentofu.org/) and [Terraform](https://developer.hashicorp.com/terraform).

## Table of contents

* [Why](#why)
* [How it works](#how-it-works)
* [Quick start](#quick-start)
  * [1. Clone target repository into `projects`](#1-clone-target-repository-into-projects)
  * [2. Preview changes](#2-preview-changes)
  * [3. Review the patch](#3-review-the-patch)
  * [4. Apply](#4-apply)
  * [5. Commit](#5-commit)
* [Contributing](#contributing)
* [FAQ](#faq)
* [License](#license)
* [Author](#author)

## Why

Manually updating module versions and refactoring configurations across repositories is error-prone and doesn't scale. This repository provides **explicit, deterministic recipes** that apply migrations consistently.

Each migration:
- ✅ Produces identical results regardless of environment
- ✅ Can be run multiple times safely (idempotent)
- ✅ Generates clean, reviewable diffs
- ✅ Is fully auditable in Git

## How it works

Migrations are declared as [OpenRewrite](https://docs.openrewrite.org/) YAML recipes:

```yaml
type: specs.openrewrite.org/v1beta/recipe
name: io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x
description: Migrate avm-res-network-virtualnetwork from 0.10.x to 0.11.x
recipeList:
  - io.oczadly.openrewrite.hcl.ChangeModuleVersion:
      source: "Azure/avm-res-network-virtualnetwork/azurerm"
      version: "~> 0.10.0"
      newVersion: "~> 0.11.0"
  - io.oczadly.openrewrite.hcl.RemoveModuleInput:
      source: "Azure/avm-res-network-virtualnetwork/azurerm"
      version: "~> 0.11.0"
      inputName: resource_group_name
  - io.oczadly.openrewrite.hcl.AddModuleInput:
      source: "Azure/avm-res-network-virtualnetwork/azurerm"
      version: "~> 0.11.0"
      inputName: parent_id
      inputValue: data.terraform_remote_state.rg_default_eastus.outputs.resource.name
```

## Quick start

### 1. Clone target repository into `projects`

```bash
git clone <repository-url> projects/<repository-name>
```

### 2. Preview changes

```bash
./gradlew rewriteDryRun \
  -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x
```

### 3. Review the patch

```bash
cat build/reports/rewrite/rewrite.patch
```

### 4. Apply

```bash
./gradlew rewriteRun \
  -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x
```

### 5. Commit

```bash
cd projects/<repository-name>
git add .
git commit -m "chore: migrate virtualnetwork to 0.11.x"
```

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

> [!IMPORTANT]
> Please note that this project is developed and maintained in **focused time blocks** to ensure quality. Contributions and issues will be addressed on a **best-effort basis**, depending on ongoing priorities.

## 📄 License

MIT License – see [LICENSE](LICENSE) for details.

## 🙋 FAQ

See [FAQ.md](FAQ.md) for answers to common questions.

## 👤 Author

Paweł Oczadły ([GitHub](https://github.com/paweloczadly) / [LinkedIn](https://linkedin.com/in/paweloczadly)).
