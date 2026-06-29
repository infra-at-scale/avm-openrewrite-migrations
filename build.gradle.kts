plugins {
    id("java-library")
    id("groovy")
    id("org.openrewrite.rewrite") version "7.28.1"
}

import org.gradle.api.tasks.testing.logging.TestExceptionFormat

repositories {
    mavenCentral()
}

dependencies {
    /*
    OpenRewrite recipes for:
      * Changing OpenTofu module version
      * Adding input variables to OpenTofu modules
      * Removing input variables from OpenTofu modules
    */
    rewrite("io.oczadly:openrewrite-recipes:1.5.0")

    /*
    The plugin builds the recipe classpath from `rewrite` dependencies during `rewriteRun` execution.
    We add src/main/resources/META-INF/rewrite to the classpath so custom recipes can be executed.

    Requires `:processResources` to complete before `:rewriteRun`.
    */
    rewrite(sourceSets.main.get().output)

    testImplementation(platform("org.spockframework:spock-bom:2.4-groovy-5.0"))
    testImplementation("org.spockframework:spock-core")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    listOf("recipeFile", "reportDir").forEach { key ->
        System.getProperty(key)?.let { systemProperty(key, it) }
    }
}

tasks.withType<Test>().configureEach {
    testLogging {
        events("passed", "skipped", "failed", "standardOut", "standardError")
        showStandardStreams = true
        exceptionFormat = TestExceptionFormat.FULL
    }
}

val allRecipeIntegrationTests = tasks.register("allRecipeIntegrationTests") {
    group = "verification"
    description = "Run RecipeIntegrationSpec for all recipe YAML files."
}

fileTree("src/main/resources/META-INF/rewrite") {
    include("*.yaml")
}.files
    .sortedBy { it.name }
    .forEach { recipeFile ->
        val recipeId = recipeFile.nameWithoutExtension
        val taskSuffix = recipeId.replace(Regex("[^A-Za-z0-9]"), "_")
        val taskName = "recipeIntegrationTest_${taskSuffix}"
        val recipePath = recipeFile.relativeTo(projectDir).invariantSeparatorsPath
        val reportPath = "tmp/reports/${recipeId}"

        val recipeTask = tasks.register<Test>(taskName) {
            group = "verification"
            description = "Run RecipeIntegrationSpec for ${recipeFile.name}."
            useJUnitPlatform()
            testClassesDirs = sourceSets.test.get().output.classesDirs
            classpath = sourceSets.test.get().runtimeClasspath
            filter {
                includeTestsMatching("io.oczadly.avm.migrations.RecipeIntegrationSpec")
            }
            systemProperty("recipeFile", recipePath)
            systemProperty("reportDir", reportPath)
            shouldRunAfter(tasks.test)
        }

        allRecipeIntegrationTests.configure {
            dependsOn(recipeTask)
        }
    }

/*
PROBLEM: OpenRewrite respects .gitignore patterns and excludes matching paths.
Reference: https://github.com/openrewrite/rewrite/blob/v8.71.0/rewrite-core/src/main/java/org/openrewrite/quark/QuarkParser.java#L75-L84

SOLUTION: Temporarily rename .gitignore to .gitignore-backup during recipe execution.
This ensures files excluded by .gitignore are processed by the recipes.
*/
val hideGitignore = { file: File -> file.renameTo(File(file.parentFile, ".gitignore-backup")) }
val restoreGitignore = { file: File -> file.renameTo(File(file.parentFile, ".gitignore")) }

/*
PROBLEM:JGit (used by OpenRewrite) automatically ignores .git directories.
Reference: https://github.com/openrewrite/jgit/blob/v1.3.1/jgit/src/main/java/org/openrewrite/jgit/api/CleanCommand.java#L113-L163
This is a security measure to prevent operations on nested Git repositories.

SOLUTION: Temporarily rename .git to .git-backup during recipe execution.
*/
val hideGitDirs = { dir: String ->
    file(dir).walk().filter { it.isDirectory && it.name == ".git" }
        .forEach { it.renameTo(File(it.parentFile, ".git-backup")) }
}

val restoreGitDirs = { dir: String ->
    file(dir).walk().filter { it.isDirectory && it.name == ".git-backup" }
        .forEach { it.renameTo(File(it.parentFile, ".git")) }
}

listOf("rewriteRun", "rewriteDryRun").forEach { taskName ->
    tasks.named(taskName) {
        dependsOn("processResources")
        doFirst {
            hideGitDirs("projects")
            file(".gitignore").takeIf { it.exists() }?.let { hideGitignore(it) }
        }
        doLast {
            file(".gitignore-backup").takeIf { it.exists() }?.let { restoreGitignore(it) }
            restoreGitDirs("projects")
        }
    }
}
