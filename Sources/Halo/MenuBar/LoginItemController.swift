import AppKit
import ServiceManagement

/// "Avvia al login" backed by `SMAppService.mainApp` (registers Halo.app itself as a
/// login item; the system shows it in Settings › General › Login Items).
@MainActor
struct LoginItemController {
    private var service: SMAppService { .mainApp }

    var isEnabled: Bool {
        service.status == .enabled
    }

    var requiresApproval: Bool {
        service.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    /// Applies the switch; opens Login Items when macOS wants approval, and explains a
    /// failure instead of failing silently.
    func setEnabledReportingErrors(_ enable: Bool) {
        do {
            try setEnabled(enable)
            if enable && requiresApproval {
                openSystemSettings()
            }
        } catch {
            Log.app.error("login item update failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = enable ? "Impossibile attivare l'avvio al login" : "Impossibile disattivare l'avvio al login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Apri Impostazioni")
            NSApp.activate()
            if alert.runModal() == .alertSecondButtonReturn {
                openSystemSettings()
            }
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
