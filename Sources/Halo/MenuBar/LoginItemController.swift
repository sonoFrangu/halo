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

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
