import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let frontendAIBackup = UTType(exportedAs: "app.echo-ui.frontendai.backup")
}

struct FrontendAIBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.frontendAIBackup, .data]
    }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
