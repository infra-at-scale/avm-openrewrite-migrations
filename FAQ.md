# FAQ

## How do I run migrations?

Use the `./gradlew rewriteDryRun` command to preview changes, then `./gradlew rewriteRun` to apply them:

```bash
# Preview changes
./gradlew rewriteDryRun \
  -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x \
  -Davm.vnet.parent_id='${data.terraform_remote_state.rg_default_eastus.outputs.resource.id}'

# Review the patch
cat build/reports/rewrite/rewrite.patch

# Apply changes
./gradlew rewriteRun \
  -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x \
  -Davm.vnet.parent_id='${data.terraform_remote_state.rg_default_eastus.outputs.resource.id}'
```

Recipe names and parameters are defined in the YAML files under `src/main/resources/META-INF/rewrite/`.

## What are the system requirements?

To run this project, you need:

- **JDK 17 or later**: Gradle and OpenRewrite require Java to run

That's it. Gradle is bundled with the repository (`gradlew`), so no additional installation is needed.

To verify your Java installation:

```bash
java -version
```

If you need to install JDK, visit [adoptium.net](https://adoptium.net/) / [sdkman.io](https://sdkman.io/) or use your package manager:

```bash
# macOS
brew install openjdk

# Ubuntu/Debian
sudo apt-get install openjdk-11-jdk

# Windows
choco install openjdk
```

## My migration didn't apply to all files. Why?

OpenRewrite recipes match based on patterns defined in the recipe. Common reasons why files might not be affected:

- **Module not found**: The recipe looks for modules with a specific source (e.g., `Azure/avm-res-network-virtualnetwork/azurerm`). If your module has a different source or is aliased differently, the recipe won't match.
- **Version mismatch**: Recipes target specific version ranges. Check that your current module version matches the range in the recipe.
- **Syntax variations**: Complex HCL syntax or non-standard formatting might prevent matching.

To debug: Check the dry-run output in `build/reports/rewrite/rewrite.patch` to see exactly which files were targeted.

## Can I run multiple migrations at once or in sequence?

You can chain migrations by specifying multiple recipe names:

```bash
./gradlew rewriteRun \
  -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x,io.oczadly.avm.migrations.res.storage.storageaccount.From064To065
```

> [!IMPORTANT]
> If one recipe's output is the input to another (e.g., version A→B then B→C), run them sequentially in separate commands to ensure correct transformation order.

## Does this work with modules outside of AVM?

No, this project is specifically designed for **Azure Verified Modules** (AVM). Recipes target module sources from the official AVM registry and won't apply to custom or third-party modules.

If you need similar migrations for other modules, you can create custom recipes following the OpenRewrite documentation and the patterns used in this repository.

## How do I integrate this with CI/CD?

You can automate migrations in your CI/CD pipeline by:

1. Cloning the target repository as a Git submodule or checking it out dynamically
2. Running `./gradlew rewriteRun` with appropriate parameters
3. Committing changes back with a bot account or creating a Pull Request
4. Example (GitHub Actions):

```yaml
- name: Run AVM migrations
  run: |
    ./gradlew rewriteRun \
      -Drewrite.activeRecipes=io.oczadly.avm.migrations.res.network.virtualnetwork.From010xTo011x \
      -Davm.vnet.parent_id='...'
  
- name: Create Pull Request
  uses: peter-evans/create-pull-request@v5
  with:
    commit-message: "chore: apply AVM migrations"
    branch: avm-migrations
```

## What if a recipe contains a bug: how do I report it?

Please open an issue on GitHub with:

- The **recipe name** used
- A **minimal reproducible example** (a small Terraform file that should be migrated)
- The **expected vs. actual behavior**
- The output from `./gradlew rewriteDryRun` (or the patch file)

This helps maintainers understand and fix the issue quickly.

## How do I roll back changes if something goes wrong?

Since migrations generate clean Git diffs, rolling back is straightforward:

```bash
cd projects/<repository-name>

# If not committed yet, discard changes
git checkout .

# If already committed, revert the commit
git revert HEAD
```

Always run `./gradlew rewriteDryRun` before applying (`rewriteRun`) to review changes first.

## Can I modify recipes for my specific needs?

Yes, you can create custom recipes by:

1. **Copying existing recipes** from `src/main/resources/META-INF/rewrite/` to a new `.yaml` file
2. **Modifying the recipe name, description, and rules** to fit your use case
3. **Running with your custom recipe** using the `-Drewrite.activeRecipes=your.custom.recipe.name` flag

**Note**: Keep custom recipes separate from the main repository if you're not contributing them back. For shared recipes, consider opening a PR to add them officially.

## What about Terraform Cloud/Enterprise or other remote backends?

This tool works with **local Terraform files only**. It doesn't interact with Terraform Cloud, Terraform Enterprise, or remote state directly.

To migrate modules stored in Terraform Cloud:

1. Pull the configuration to your local machine
2. Run migrations locally using this tool
3. Push changes back to Terraform Cloud

For remote state references, migrations can update local variable files or data source configurations accordingly.
