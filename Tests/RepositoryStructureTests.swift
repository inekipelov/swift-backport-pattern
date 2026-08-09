import Foundation
import XCTest

final class RepositoryStructureTests: XCTestCase {
    private let fileManager = FileManager.default

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testCanonicalDocumentationFilesExist() {
        let requiredPaths = [
            "AGENTS.md",
            "CLAUDE.md",
            "CONTRIBUTING.md",
            "README.md",
            "docs/README.md",
            "docs/AI_AGENT_ADOPTION.md",
            "docs/BACKPORT_ADOPTION_GUIDE.md",
            "docs/RELEASING.md",
            "Tests/DocumentationExamples.swift",
            ".agents/skills/swiftui-backport-adoption/SKILL.md",
            ".agents/skills/swiftui-backport-adoption/agents/openai.yaml",
            ".agents/skills/swiftui-backport-adoption/assets/backport-decision-record.md",
            ".agents/skills/swiftui-backport-adoption/references/category-examples.md",
        ]

        for path in requiredPaths {
            XCTAssertTrue(
                fileManager.fileExists(atPath: repositoryRoot.appendingPathComponent(path).path),
                "Missing canonical repository file: \(path)"
            )
        }
    }

    func testClaudeImportsCanonicalInstructionsWithoutDuplication() throws {
        let claudeFile = repositoryRoot.appendingPathComponent("CLAUDE.md")
        let content = try String(contentsOf: claudeFile, encoding: .utf8)
        let nonemptyLines = content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        XCTAssertEqual(nonemptyLines, ["@AGENTS.md"])
    }

    func testClaudeSkillBridgeTargetsCanonicalSkill() throws {
        let bridge = repositoryRoot.appendingPathComponent(
            ".claude/skills/swiftui-backport-adoption"
        )
        let attributes = try fileManager.attributesOfItem(atPath: bridge.path)

        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)

        let destination = try fileManager.destinationOfSymbolicLink(atPath: bridge.path)
        XCTAssertEqual(destination, "../../.agents/skills/swiftui-backport-adoption")

        let resolvedTarget = bridge
            .deletingLastPathComponent()
            .appendingPathComponent(destination)
            .standardizedFileURL
        var isDirectory: ObjCBool = false
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: resolvedTarget.path,
                isDirectory: &isDirectory
            ) && isDirectory.boolValue,
            "Claude skill bridge target does not resolve to a directory"
        )
    }

    func testSwiftUIBackportSkillFrontmatterMatchesItsDirectory() throws {
        let skillDirectory = repositoryRoot.appendingPathComponent(
            ".agents/skills/swiftui-backport-adoption"
        )
        let skillFile = skillDirectory.appendingPathComponent("SKILL.md")
        let content = try String(contentsOf: skillFile, encoding: .utf8)
        let sections = content.components(separatedBy: "---")

        XCTAssertGreaterThanOrEqual(sections.count, 3, "SKILL.md frontmatter is missing")
        guard sections.count >= 3 else { return }

        var fields: [String: String] = [:]
        for line in sections[1].components(separatedBy: .newlines) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)

            XCTAssertNil(fields.updateValue(value, forKey: key), "Duplicate key: \(key)")
        }

        XCTAssertEqual(Set(fields.keys), Set(["name", "description"]))
        XCTAssertEqual(fields["name"], skillDirectory.lastPathComponent)
        XCTAssertFalse(fields["description", default: ""].isEmpty)
    }

    func testRelativeMarkdownLinksResolve() throws {
        let linkPattern = try NSRegularExpression(
            pattern: #"\[[^\]]*\]\(([^)]+)\)"#
        )

        for markdownFile in try markdownFiles() {
            let content = try String(contentsOf: markdownFile, encoding: .utf8)
            let range = NSRange(content.startIndex..., in: content)

            for match in linkPattern.matches(in: content, range: range) {
                guard let destinationRange = Range(match.range(at: 1), in: content) else {
                    continue
                }

                let destination = String(content[destinationRange])
                guard let relativePath = relativePath(from: destination) else {
                    continue
                }

                let target = markdownFile
                    .deletingLastPathComponent()
                    .appendingPathComponent(relativePath)
                    .standardizedFileURL
                let source = markdownFile.path.replacingOccurrences(
                    of: repositoryRoot.path + "/",
                    with: ""
                )

                XCTAssertTrue(
                    fileManager.fileExists(atPath: target.path),
                    "Broken relative Markdown link in \(source): \(destination)"
                )
            }
        }
    }

    private func markdownFiles() throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: repositoryRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        let excludedDirectories = Set([".build", ".git", ".swiftpm"])
        var files: [URL] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey]
            )

            if values.isDirectory == true && excludedDirectories.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            if values.isRegularFile == true && url.pathExtension.lowercased() == "md" {
                files.append(url)
            }
        }

        return files
    }

    private func relativePath(from destination: String) -> String? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()

        if trimmed.hasPrefix("#") ||
            lowercase.hasPrefix("https://") ||
            lowercase.hasPrefix("http://") ||
            lowercase.hasPrefix("mailto:") {
            return nil
        }

        let withoutBrackets = trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let path = withoutBrackets.split(separator: "#", maxSplits: 1)[0]

        return String(path).removingPercentEncoding
    }
}
