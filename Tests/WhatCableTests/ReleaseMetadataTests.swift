import XCTest

final class ReleaseMetadataTests: XCTestCase {
    func testBuildMetadataMatchesLatestReleaseTag() throws {
        let root = repoRoot()
        let current = try buildMetadata(in: root.appendingPathComponent("scripts/build-app.sh"))
        let latestTag = try latestReleaseTag(in: root)
        let taggedScript = try git(
            ["show", "\(latestTag):scripts/build-app.sh"],
            in: root
        )
        let tagged = try buildMetadata(inContents: taggedScript)

        XCTAssertEqual(current.version, String(latestTag.dropFirst()))
        XCTAssertEqual(current.version, tagged.version)
        XCTAssertEqual(current.buildNumber, tagged.buildNumber)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func latestReleaseTag(in root: URL) throws -> String {
        let tag = try git(
            ["describe", "--tags", "--abbrev=0", "--match", "v[0-9]*"],
            in: root
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !tag.isEmpty else {
            throw XCTSkip("No release tags are available in this checkout.")
        }
        return tag
    }

    private func buildMetadata(in script: URL) throws -> (version: String, buildNumber: String) {
        try buildMetadata(inContents: String(contentsOf: script, encoding: .utf8))
    }

    private func buildMetadata(inContents contents: String) throws -> (version: String, buildNumber: String) {
        var version: String?
        var buildNumber: String?

        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("VERSION=") {
                version = shellAssignmentValue(trimmed, key: "VERSION")
            } else if trimmed.hasPrefix("BUILD_NUMBER=") {
                buildNumber = shellAssignmentValue(trimmed, key: "BUILD_NUMBER")
            }
        }

        guard let version, let buildNumber else {
            XCTFail("VERSION and BUILD_NUMBER must be set in scripts/build-app.sh")
            return ("", "")
        }
        return (version, buildNumber)
    }

    private func shellAssignmentValue(_ line: String, key: String) -> String {
        String(line.dropFirst("\(key)=".count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private func git(_ arguments: [String], in root: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let outputText = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let errorText = String(data: errorData, encoding: .utf8) ?? ""
            throw XCTSkip("Cannot inspect git release metadata: \(errorText)")
        }
        return outputText
    }
}
