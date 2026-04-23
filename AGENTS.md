# AGENTS.md

## Project snapshot

**avm-openrewrite-migrations** is an OpenRewrite-based migration toolkit for Azure Verified Modules (AVM).

- **Purpose**: Provide safe, deterministic, and auditable migrations for OpenTofu/Terraform module version upgrades
- **Core Mechanism**: OpenRewrite YAML recipes that transform Terraform/OpenTofu configurations
- **Project Type**: Gradle-based build system with HCL (Terraform) transformation recipes
- **Tech Stack**: OpenRewrite (Java), Gradle, YAML recipes, Terraform/OpenTofu configurations
- **Primary Contribution**: Adding new migration recipes for AVM module version upgrades

## Key project structure

```
src/main/resources/META-INF/rewrite/
├── avm-res-network-virtualnetwork-010-to-011.yaml
├── avm-res-network-privatednszone-03x-to-04x.yaml
├── avm-res-storage-storageaccount-064-to-065.yaml
└── ... (more recipe files)

build.gradle.kts                       # Build configuration
README.md                              # Project overview and quick start
CONTRIBUTING.md                        # Contribution guidelines with naming conventions
FAQ.md                                 # Common questions and troubleshooting
```

## Critical concepts for AI agents

### Recipe Structure

Each migration recipe is a YAML file that:
1. Declares a unique recipe name (e.g., `io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x`)
2. Contains a `recipeList` with ordered transformations (e.g., `ChangeModuleVersion`, `RemoveModuleInput`, `AddModuleInput`, `AddProvider`, `AddRemovedBlock`, `AddImportBlock`)
3. Includes detailed USAGE comments showing how to invoke the recipe with Gradle parameters

### Gradle Parameter Naming Convention

**Format**: `-D<avm>.<module_abbreviation>.<parameter_name>`

**Examples**:
- `-Davm.pdns.module_name="private_dns_zones"` (module local variable name)
- `-Davm.pdns.subscription_id="<subscription-id>"` (Azure subscription ID)
- `-Davm.vnet.parent_id='${data.terraform_remote_state.rg_default_eastus.outputs.resource.id}'` (Terraform reference)

**Module abbreviations** (follow [Microsoft CAF naming guidelines](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)):
- `pdns`: Private DNS Zone
- `vnet`: Virtual Network
- `sa`: Storage Account
- `nsg`: Network Security Group

### Recipe Naming Convention

**YAML filename**: `avm-res-<service>-<module>-<from>-to-<to>.yaml`
- Example: `avm-res-network-privatednszone-03x-to-04x.yaml`

**Recipe name**: `io.oczadly.avm.migrations.res.<service>.<module>.From<VersionA>To<VersionB>`
- Example: `io.oczadly.avm.migrations.res.network.privatednszone.From03xTo04x`

## Common workflows for AI agents

### Adding a new migration recipe
1. Check existing recipes in `src/main/resources/META-INF/rewrite/` to avoid duplicates
2. Create a new YAML file following the naming convention
3. Define the recipe with transformations ordered logically (version change first, then input modifications, then import/removed blocks)
4. Include comprehensive USAGE comments with all required Gradle parameters
5. Test with `./gradlew rewriteDryRun` before submitting
6. Submit PR with before/after examples and AVM module documentation links

### Modifying existing recipes
- Always test dry-run (`rewriteDryRun`) before applying (`rewriteRun`)
- Verify transformations in `build/reports/rewrite/rewrite.patch`
- Update recipe description if semantics change
- Include test cases in PR that demonstrate the fix

### Documentation updates
- Update CONTRIBUTING.md if adding new naming conventions or guidelines
- Update FAQ.md for new common questions or troubleshooting scenarios
- Update README.md only for changes affecting quick start or project overview
- Maintain consistency with existing tone (clear, concise, practical)

## Documentation conventions to follow

- **Clear examples**: Include real-world usage examples in all documentation
- **Parameter documentation**: Always explain what Gradle parameters do and where values come from
- **Links to references**: Link to [Azure CAF naming](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) and AVM module docs
- **YAML comments**: Each recipe should have detailed USAGE and MANUAL FIXES NEEDED comments
- **Consistency**: Follow existing style in CONTRIBUTING.md and FAQ.md for tone and structure

## Important constraints

- **Java/Gradle requirement**: Users must have JDK 11 or later; Gradle is bundled
- **Local-only processing**: Tool works only with local Terraform files, not remote state directly
- **AVM-focused**: Recipes target only Azure Verified Modules; custom modules are out of scope
- **Deterministic transformations**: Recipes must produce identical results regardless of environment (no random data)
- **Idempotent**: Recipes should be safe to run multiple times on the same code

## Testing guidance for AI agents

When adding or modifying recipes:
1. Use `./gradlew rewriteDiscover` to verify recipe syntax
2. Create test Terraform files in `projects/` directory
3. Run `./gradlew rewriteDryRun -Drewrite.activeRecipes=<recipe-name>` with test parameters
4. Verify output in `build/reports/rewrite/rewrite.patch`
5. Confirm idempotency: run `rewriteRun` twice, second run should produce no changes
