import SwiftUI

public struct ModelMenuView: View {
    public let service: ModelService
    private var openKeyManageAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow

    public init(service: ModelService, openKeyManageAction: (() -> Void)? = nil) {
        self.service = service
        self.openKeyManageAction = openKeyManageAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            keySection
            Spacer().frame(height: 8)
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
            .padding(.vertical, 0)
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

        case .loadedZhiPu(let info):
            zhiPuInfoView(info: info)

        case .loadedDeepSeek(let info):
            deepSeekInfoView(info: info)

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

    // MARK: - ZhiPu Info

    @ViewBuilder
    private func zhiPuInfoView(info: ZhiPuQuotaInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("平台:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("智谱 AI")
                    .font(.callout)
                    .fontWeight(.medium)
            }

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
            ProgressBar(value: progress, color: progressTintColor(percentage: info.percentage5h))

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

    // MARK: - DeepSeek Info

    @ViewBuilder
    private func deepSeekInfoView(info: DeepSeekBalanceInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("平台:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("DeepSeek")
                    .font(.callout)
                    .fontWeight(.medium)
            }

            Text("账户余额")
                .font(.callout)
                .foregroundColor(.secondary)

            Text("\(info.currencySymbol)\(info.totalBalance)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("赠金余额")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(info.currencySymbol)\(info.grantedBalance)")
                    .font(.callout)
            }

            HStack {
                Text("充值余额")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(info.currencySymbol)\(info.toppedUpBalance)")
                    .font(.callout)
            }

            if info.isLowBalance {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("余额不足 \(info.currencySymbol)\(info.totalBalance)")
                        .foregroundColor(.red)
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
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
        if let action = openKeyManageAction {
            action()
        } else {
            openWindow(id: "key-manage")
        }
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
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 14, height: 12)
                    } else {
                        Color.clear
                            .frame(width: 14, height: 12)
                    }
                }

                Text(entry.name)
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .green : .primary)
                    .lineLimit(1)

                Text(entry.provider.shortTag)
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.provider == .zhiPu ? Color.blue : Color.purple)
                    )

                Spacer()

                Text(entry.maskedKey)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - ProgressBar

private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.12))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
    }
}
