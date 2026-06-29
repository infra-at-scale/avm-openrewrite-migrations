package io.oczadly.avm.migrations

import spock.lang.Specification

class RecipeIntegrationSpec extends Specification {

    private static String tailLines(String text, int maxLines = 120) {
        List<String> lines = text.readLines()
        if (lines.size() <= maxLines) {
            return text
        }
        return lines.takeRight(maxLines).join("\n")
    }

    def "recipe migration dry-run succeeds and generates reports"() {
        given:
        String recipeFileProp = System.getProperty("recipeFile")
        String reportDirProp = System.getProperty("reportDir")

        assert recipeFileProp: "Missing -DrecipeFile=<path>"
        assert reportDirProp: "Missing -DreportDir=<path>"

        File projectRoot = new File(System.getProperty("user.dir"))
        File recipeFile = new File(projectRoot, recipeFileProp)
        File reportDir = new File(projectRoot, reportDirProp)

        assert recipeFile.exists(): "Recipe file does not exist: ${recipeFile.absolutePath}"

        reportDir.mkdirs()

        String recipeId = recipeFile.name.replaceFirst(/\.yaml$/, "")
        File summaryFile = new File(reportDir, "${recipeId}.summary.txt")
        File patchFile = new File(reportDir, "${recipeId}.patch")
        File logFile = new File(reportDir, "${recipeId}.log")
        File processOutputFile = new File(reportDir, "${recipeId}.process-output.log")

        when:
        Process process = new ProcessBuilder(
            "bash",
            ".github/scripts/test_recipe_examples.sh",
            recipeFileProp,
            reportDirProp
        )
            .directory(projectRoot)
            .redirectErrorStream(true)
            .start()

        String output = process.inputStream.getText("UTF-8")
        int exitCode = process.waitFor()
        processOutputFile.text = output

        then:
        assert exitCode == 0: """
    Recipe script failed.
    recipeFile=${recipeFile.absolutePath}
    reportDir=${reportDir.absolutePath}
    exitCode=${exitCode}
    processOutputFile=${processOutputFile.absolutePath}
    scriptLogFile=${logFile.absolutePath}

    --- process output (tail) ---
    ${tailLines(output)}
    """.stripIndent()

        and:
        assert summaryFile.exists(): "Missing summary file: ${summaryFile.absolutePath}"
        assert patchFile.exists(): "Missing patch file: ${patchFile.absolutePath}"
        assert logFile.exists(): "Missing script log file: ${logFile.absolutePath}"

        and:
        assert summaryFile.text.contains("result=PASS"): "Summary file does not contain result=PASS: ${summaryFile.absolutePath}"

        and:
        assert output.contains("Recipe test passed"): "Process output did not contain success marker. See ${processOutputFile.absolutePath}"
    }
}
