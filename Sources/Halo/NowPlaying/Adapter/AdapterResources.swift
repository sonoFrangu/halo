import Foundation

/// Absolute paths of the bundled mediaremote-adapter pieces
/// (`Contents/Resources/MediaRemoteAdapter/`, assembled by scripts/bundle.sh).
struct AdapterResources: Sendable {
    /// The system Perl is what makes this work: as a platform binary it is still allowed
    /// to use MediaRemote on macOS 15.4+, and it loads the adapter framework for us.
    let perl = URL(fileURLWithPath: "/usr/bin/perl")
    let script: URL
    let framework: URL

    enum LookupError: Error, CustomStringConvertible {
        case missing(String)

        var description: String {
            switch self {
            case .missing(let path):
                "Adapter non trovato in \(path). Avvia Halo.app creata da scripts/bundle.sh."
            }
        }
    }

    static func locate(in bundle: Bundle) -> Result<AdapterResources, LookupError> {
        guard let resources = bundle.resourceURL else {
            return .failure(.missing(bundle.bundlePath))
        }
        let directory = resources.appendingPathComponent("MediaRemoteAdapter", isDirectory: true)
        let script = directory.appendingPathComponent("mediaremote-adapter.pl")
        let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework", isDirectory: true)

        let fileManager = FileManager.default
        for url in [script, framework] where !fileManager.fileExists(atPath: url.path) {
            return .failure(.missing(url.path))
        }
        return .success(AdapterResources(script: script, framework: framework))
    }

    /// Builds the argument list for an adapter command, e.g. `["stream", "--micros"]`.
    func arguments(_ command: [String]) -> [String] {
        [script.path, framework.path] + command
    }
}
