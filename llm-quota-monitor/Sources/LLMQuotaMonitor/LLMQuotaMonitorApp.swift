import SwiftUI
import LLMQuotaMonitorKit

@main
struct LLMQuotaMonitorApp: App {
    @State private var service = ModelService()

    init() {
        ProcessInfo.processInfo.disableAutomaticTermination("LLMQuotaMonitor is running")
    }

    var body: some Scene {
        MenuBarExtra {
            ModelMenuView(service: service)
                .task {
                    service.loadKeys()
                    if service.activeKey != nil {
                        await service.refresh()
                    }
                    service.startAutoRefresh()
                }
        } label: {
            Text(service.statusBarTitle)
        }
        .menuBarExtraStyle(.window)

        Window("管理 API Key", id: "key-manage") {
            KeyManageView(service: service)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 500)
    }
}
