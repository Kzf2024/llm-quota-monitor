import Foundation
import Observation

@Observable
final public class ModelService {

    // MARK: - State

    public var appState: AppState = .idle
    public var keys: [APIKeyEntry] = []
    public var activeKeyIndex: Int = 0
    public var showingKeyManager: Bool = false

    // MARK: - Computed

    public var activeKey: APIKeyEntry? {
        guard activeKeyIndex >= 0, activeKeyIndex < keys.count else { return nil }
        return keys[activeKeyIndex]
    }

    public var statusBarTitle: String {
        switch appState {
        case .idle:
            return "\u{2699}\u{FE0F}"
        case .loading:
            return "..."
        case .loadedZhiPu(let info):
            return "\(info.tier.displayName) \(info.percentage5h)%"
        case .loadedDeepSeek(let info):
            return "\(info.currencySymbol)\(info.totalBalance)"
        case .error:
            return "\u{26A0}\u{FE0F}"
        }
    }

    public var statusBarTooltip: String {
        var lines = ["LLM Quota Monitor"]
        if let key = activeKey {
            lines.append("Key: \(key.name)")
        }
        switch appState {
        case .idle:
            lines.append("请添加 API Key 开始使用")
        case .loading:
            lines.append("加载中...")
        case .loadedZhiPu(let info):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let resetStr = formatter.localizedString(for: info.nextReset, relativeTo: Date())
            lines.append("平台: 智谱 AI")
            lines.append("套餐: GLM Coding \(info.tier.displayName)")
            lines.append("5h 额度: \(info.percentage5h)%")
            lines.append("重置: \(resetStr)")
        case .loadedDeepSeek(let info):
            lines.append("平台: DeepSeek")
            lines.append("余额: \(info.currencySymbol)\(info.totalBalance)")
            if info.isLowBalance {
                lines.append("⚠️ 余额不足")
            }
        case .error(let message):
            lines.append("错误: \(message)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    public init() {}

    private var autoRefreshTimer: Timer?
    private static let activeKeyIndexKey = "LLMQuotaMonitor.activeKeyIndex"
    private static let legacyActiveKeyIndexKey = "ModelStatus.activeKeyIndex"

    private let quotaURL = URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!
    private let subscriptionURL = URL(string: "https://open.bigmodel.cn/api/biz/subscription/list")!
    private let deepSeekBalanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    private static var keysFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LLMQuotaMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("keys.json")
    }

    private static var legacyKeysFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ModelStatus/keys.json", isDirectory: false)
    }

    // MARK: - Error

    public enum ServiceError: LocalizedError {
        case invalidResponse
        case noFiveHourLimit
        case noBalanceInfo
        case unauthorized
        case rateLimited
        case httpError(Int)

        public var errorDescription: String? {
            switch self {
            case .invalidResponse: return "API 响应格式错误"
            case .noFiveHourLimit: return "未找到5小时额度数据"
            case .noBalanceInfo: return "未获取到余额信息"
            case .unauthorized: return "API Key 无效或已过期"
            case .rateLimited: return "请求过于频繁，请稍后重试"
            case .httpError(let code): return "HTTP 错误 \(code)"
            }
        }
    }

    // MARK: - Key Persistence

    private func saveKeysToFile() {
        do {
            let data = try JSONEncoder().encode(keys)
            try data.write(to: Self.keysFileURL, options: .atomic)
        } catch {
            print("Failed to save keys: \(error)")
        }
    }

    private func loadKeysFromFile() -> [APIKeyEntry] {
        do {
            let data = try Data(contentsOf: Self.keysFileURL)
            return try JSONDecoder().decode([APIKeyEntry].self, from: data)
        } catch {
            // Try migrating from legacy path
            do {
                let legacyData = try Data(contentsOf: Self.legacyKeysFileURL)
                let legacyKeys = try JSONDecoder().decode([APIKeyEntry].self, from: legacyData)
                if !legacyKeys.isEmpty {
                    try legacyData.write(to: Self.keysFileURL, options: .atomic)
                }
                return legacyKeys
            } catch {
                return []
            }
        }
    }

    // MARK: - Key Management

    public func loadKeys() {
        keys = loadKeysFromFile()
        var savedIndex = UserDefaults.standard.integer(forKey: Self.activeKeyIndexKey)
        // Migrate from legacy UserDefaults key if new one has no value
        if savedIndex == 0 && UserDefaults.standard.object(forKey: Self.activeKeyIndexKey) == nil {
            savedIndex = UserDefaults.standard.integer(forKey: Self.legacyActiveKeyIndexKey)
            if savedIndex > 0 {
                UserDefaults.standard.set(savedIndex, forKey: Self.activeKeyIndexKey)
            }
        }
        activeKeyIndex = (savedIndex >= 0 && savedIndex < keys.count) ? savedIndex : 0
    }

    public func addKey(name: String, key: String, provider: Provider = .zhiPu) throws {
        let entry = APIKeyEntry(name: name, key: key, provider: provider)
        keys.append(entry)
        saveKeysToFile()

        if keys.count == 1 {
            activeKeyIndex = 0
            UserDefaults.standard.set(0, forKey: Self.activeKeyIndexKey)
            Task { await refresh() }
        }
    }

    public func deleteKey(at index: Int) throws {
        guard index >= 0, index < keys.count else { return }
        keys.remove(at: index)

        if keys.isEmpty {
            activeKeyIndex = 0
        } else if index < activeKeyIndex {
            activeKeyIndex -= 1
        } else if index == activeKeyIndex, activeKeyIndex >= keys.count {
            activeKeyIndex = keys.count - 1
        }
        UserDefaults.standard.set(activeKeyIndex, forKey: Self.activeKeyIndexKey)
        saveKeysToFile()
    }

    public func renameKey(at index: Int, newName: String) throws {
        guard index >= 0, index < keys.count else { return }
        keys[index].name = newName
        saveKeysToFile()
    }

    public func updateKeyValue(at index: Int, newKey: String) throws {
        guard index >= 0, index < keys.count else { return }
        keys[index].key = newKey
        saveKeysToFile()
    }

    // MARK: - API Methods

    public func refresh(silent: Bool = false) async {
        guard let keyEntry = activeKey else {
            appState = .error("No API key selected")
            return
        }

        if !silent {
            appState = .loading
        }

        do {
            switch keyEntry.provider {
            case .zhiPu:
                let quotaData = try await fetchQuota(key: keyEntry.key)
                let quotaResp = try JSONDecoder().decode(QuotaResponse.self, from: quotaData)

                let subResp: SubscriptionResponse
                do {
                    let subData = try await fetchSubscription(key: keyEntry.key)
                    subResp = try JSONDecoder().decode(SubscriptionResponse.self, from: subData)
                } catch {
                    subResp = SubscriptionResponse(code: 0, data: nil, success: false)
                }

                let info = try Self.buildZhiPuQuotaInfo(quotaResp: quotaResp, subResp: subResp)
                appState = .loadedZhiPu(info)

            case .deepSeek:
                let data = try await fetchDeepSeekBalance(key: keyEntry.key)
                let resp = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
                let info = try Self.buildDeepSeekBalanceInfo(resp: resp)
                appState = .loadedDeepSeek(info)
            }
        } catch let err as ServiceError {
            appState = .error(err.errorDescription ?? err.localizedDescription)
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    public func switchKey(to index: Int) async {
        guard index >= 0, index < keys.count else { return }
        activeKeyIndex = index
        UserDefaults.standard.set(index, forKey: Self.activeKeyIndexKey)
        await refresh()
    }

    // MARK: - ZhiPu Builders

    public static func buildZhiPuQuotaInfo(quotaResp: QuotaResponse, subResp: SubscriptionResponse) throws -> ZhiPuQuotaInfo {
        guard let fiveHourLimit = quotaResp.data?.fiveHourLimit else {
            throw ServiceError.noFiveHourLimit
        }

        let percentage = fiveHourLimit.percentage ?? 0
        let number = fiveHourLimit.number ?? 0
        let totalHours = Double(number)
        let usedHours = totalHours * Double(percentage) / 100.0

        var tier: Tier = .unknown
        if let level = quotaResp.data?.level {
            tier = Tier(productName: level)
        } else if let sub = subResp.validSubscription, let productName = sub.productName {
            tier = Tier(productName: productName)
        }

        let nextReset: Date
        if let resetTimestamp = fiveHourLimit.nextResetTime {
            nextReset = Date(timeIntervalSince1970: resetTimestamp / 1000.0)
        } else {
            nextReset = Date().addingTimeInterval(5 * 3600)
        }

        return ZhiPuQuotaInfo(
            tier: tier,
            percentage5h: percentage,
            total5h: Int64(number),
            usedHours: usedHours,
            totalHours: totalHours,
            nextReset: nextReset
        )
    }

    // MARK: - DeepSeek Builders

    public static func buildDeepSeekBalanceInfo(resp: DeepSeekBalanceResponse) throws -> DeepSeekBalanceInfo {
        guard let infos = resp.balance_infos, let first = infos.first else {
            throw ServiceError.noBalanceInfo
        }
        return DeepSeekBalanceInfo(
            currency: first.currency,
            totalBalance: first.total_balance,
            grantedBalance: first.granted_balance,
            toppedUpBalance: first.topped_up_balance,
            isAvailable: resp.is_available
        )
    }

    // MARK: - Auto-Refresh

    public func startAutoRefresh(interval: TimeInterval = 120) {
        stopAutoRefresh()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refresh(silent: true)
            }
        }
    }

    public func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    // MARK: - Private Network

    private func fetchQuota(key: String) async throws -> Data {
        var request = URLRequest(url: quotaURL)
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response: response)
        return data
    }

    private func fetchSubscription(key: String) async throws -> Data {
        var request = URLRequest(url: subscriptionURL)
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response: response)
        return data
    }

    private func fetchDeepSeekBalance(key: String) async throws -> Data {
        var request = URLRequest(url: deepSeekBalanceURL)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTPStatus(response: response)
        return data
    }

    private func checkHTTPStatus(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw ServiceError.unauthorized
        case 429: throw ServiceError.rateLimited
        default: throw ServiceError.httpError(httpResponse.statusCode)
        }
    }
}
