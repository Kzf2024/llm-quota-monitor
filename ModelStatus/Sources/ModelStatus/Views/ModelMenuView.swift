import SwiftUI

public struct ModelMenuView: View {
    public let service: ModelService
    @Environment(\.openWindow) private var openWindow

    public init(service: ModelService) {
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
            keySection
            Divider()
            infoSection
            Divider()
            actionsSection
        }
        .frame(width: 280)
    }

    // MARK: - Key Switcher Section

    @ViewBuilder
    private var keySection: some View {
        if service.keys.isEmpty {
            Button(action: { openKeyManage() }) {
                Label("添加 API Key", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(10)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(service.keys.enumerated()), id: \.element.id) { index, entry in
                    KeyRow(
                        entry: entry,
                        isActive: index == service.activeKeyIndex
                    ) {
                        Task {
                            await service.switchKey(to: index)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private var infoSection: some View {
        switch service.appState {
        case .idle:
            Text("请添加 API Key 开始使用")
                .foregroundColor(.secondary)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)

        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("加载中...")
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(16)

        case .loaded(let info):
            loadedView(info: info)

        case .error(let message):
            VStack(spacing: 6) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(16)
        }
    }

    @ViewBuilder
    private func loadedView(info: QuotaInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("套餐:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("GLM Coding \(info.tier.displayName)")
                    .font(.callout)
                    .fontWeight(.medium)
            }

            Text("5小时额度:")
                .font(.callout)
                .foregroundColor(.secondary)

            let progress = Double(info.percentage5h) / 100.0
            ProgressView(value: progress)
                .tint(progressTintColor(percentage: info.percentage5h))

            Text("\(info.percentage5h)%")
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.medium)

            HStack {
                Text("重置:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text(info.nextReset, style: .relative)
                    .font(.callout)
            }
        }
        .padding(12)
    }

    private func progressTintColor(percentage: Int) -> Color {
        if percentage > 80 {
            return .red
        } else if percentage > 50 {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        HStack(spacing: 0) {
            Button(action: {
                Task {
                    await service.refresh()
                }
            }) {
                Label("刷新", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            Button(action: { openKeyManage() }) {
                Label("管理 Key", systemImage: "key")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("退出", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func openKeyManage() {
        openWindow(id: "key-manage")
    }
}

// MARK: - KeyRow

private struct KeyRow: View {
    let entry: APIKeyEntry
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Group {
                    if isActive {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .frame(width: 14)
                    } else {
                        Color.clear
                            .frame(width: 14)
                    }
                }

                Text(entry.name)
                    .lineLimit(1)

                Spacer()

                Text(entry.maskedKey)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
