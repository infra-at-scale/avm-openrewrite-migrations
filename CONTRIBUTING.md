# Contributing to avm-openrewrite-migrations

Thank you for your interest in contributing! This project welcomes contributions in the form of bug reports, feature requests, and new migration recipes.

## Contributing New Migration Recipes

The primary way to contribute is by adding new OpenRewrite recipes for AVM module migrations.

### Before you start

1. Check if a recipe for your migration already exists in `src/main/resources/META-INF/rewrite/`
2. **Open an issue first** using the [Recipe Request template](https://github.com/infra-at-scale/avm-openrewrite-migrations/issues/new?template=30_recipe_request.yaml) to discuss the migration with maintainers (avoids duplicate work)
3. Ensure you have **JDK 11 or later** installed

### Adding a new recipe

1. **Create a new YAML file** in `src/main/resources/META-INF/rewrite/`:
   ```
   src/main/resources/META-INF/rewrite/avm-res-<service>-<module>-<version-from>-to-<version-to>.yaml
   ```

2. **Define the recipe** following existing patterns. Example:
   ```yaml
   type: specs.openrewrite.org/v1beta/recipe
   name: io.oczadly.avm.migrations.res.<service>.<module>.From<VersionA>To<VersionB>
   description: Migrate avm-res-<service>-<module> from <version-a> to <version-b>
   recipeList:
     - io.oczadly.openrewrite.hcl.ChangeModuleVersion:
         source: "Azure/avm-res-<service>-<module>/azurerm"
         version: "~> <version-a>"
         newVersion: "~> <version-b>"
     # Add additional transformations (RemoveModuleInput, AddModuleInput, etc.)
   ```

3. **Test your recipe**:
   ```bash
   ./gradlew rewriteDryRun \
     -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.<service>.<module>.From<VersionA>To<VersionB>
   
   cat build/reports/rewrite/rewrite.patch
   ```

4. **Submit a Pull Request** with:
   - The new YAML recipe file
   - A clear description of what the recipe does
   - Link to the AVM module documentation (if available)
   - Example of before/after Terraform code

## ✍️ Making Changes

✅ Follow existing **code style and patterns** in recipe files.

✅ Ensure your change is:

* **Well-scoped** (one logical change per PR)
* Includes a **test case** with example Terraform code
* Works correctly in both **dry-run and apply modes**
* Passes **all validation** before submitting

✅ If modifying existing recipes:

Include a test demonstrating the fix.

✅ If adding features or fixing bugs to the build system:

Update `README.md` and `FAQ.md` if needed.

## 🚦 Submitting a Pull Request

1. Push your changes to your fork
2. Open a Pull Request using the [pull request template](.github/pull_request_template.md)
3. Provide context: What does this migration do? Why is it needed?
4. Include before/after examples in the PR description

## Recipe Naming Convention

Follow this structure for consistency:

- **File name**: `avm-res-<service>-<module>-<from>-to-<to>.yaml`
- **Recipe name**: `io.oczadly.avm.migrations.res.<service>.<module>.From<VersionA>To<VersionB>`
- **Description**: "Migrate avm-res-<service>-<module> from X.X.x to Y.Y.x"

Examples:
- `avm-res-network-virtualnetwork-010-to-011.yaml`
- `io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x`

## Parameter Naming Convention

Follow [Microsoft's Cloud Adoption Framework resource naming guidelines](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) for parameter names:

**Gradle parameter format**: `-D<avm>.<module_abbreviation>.<parameter_name>`

**Components**:
- **D prefix**: Gradle property syntax
- **avm**: Namespace (Azure Verified Modules)
- **module_abbreviation**: Shortened module name (e.g., `pdns` for private-dns-zone, `vnet` for virtual-network)
- **parameter_name**: Snake_case parameter name

**Examples**:
- `-Davm.pdns.module_name="private_dns_zones"`
- `-Davm.pdns.subscription_id="00000000-0000-0000-0000-000000000000"`
- `-Davm.pdns.resource_group_name="my-rg"`
- `-Davm.pdns.role_assignment_id="role-id-guid"`
- `-Davm.vnet.parent_id='${data.terraform_remote_state.rg_default_eastus.outputs.resource.id}'`

**Azure Resource Abbreviations** (from CAF):
- `rg`: Resource Group
- `vnet`: Virtual Network
- `st`: Storage Account
- `pdns`: Private DNS Zone
- `nic`: Network Interface
- `nsg`: Network Security Group
- See [Microsoft's resource abbreviations reference](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations) for a complete list.

## 🤝 Code of Conduct

Please be respectful and constructive in your communication. Contributions are welcome from all skill levels.

## ⚠️ Maintainer note

> [!IMPORTANT]
> Please note that this project is developed and maintained in **focused time blocks** to ensure quality. Contributions and issues will be addressed on a **best-effort basis**, depending on ongoing priorities.
