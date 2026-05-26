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
        case .loaded(let info):
            return "\(info.tier.displayName) \(info.percentage5h)%"
        case .error:
            return "\u{26A0}\u{FE0F}"
        }
    }

    // MARK: - Private

    public init() {}

    private var autoRefreshTimer: Timer?
    private static let activeKeyIndexKey = "ModelStatus.activeKeyIndex"

    private let quotaURL = URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!
    private let subscriptionURL = URL(string: "https://open.bigmodel.cn/api/biz/subscription/list")!

    private static var keysFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ModelStatus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("keys.json")
    }

    // MARK: - Error

    public enum ServiceError: LocalizedError {
        case invalidResponse
        case noFiveHourLimit
        case unauthorized
        case rateLimited
        case httpError(Int)

        public var errorDescription: String? {
            switch self {
            case .invalidResponse: return "API 响应格式错误"
            case .noFiveHourLimit: return "未找到5小时额度数据"
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
            return []
        }
    }

    // MARK: - Key Management

    public func loadKeys() {
        keys = loadKeysFromFile()
        let savedIndex = UserDefaults.standard.integer(forKey: Self.activeKeyIndexKey)
        activeKeyIndex = (savedIndex >= 0 && savedIndex < keys.count) ? savedIndex : 0
    }

    public func addKey(name: String, key: String) throws {
        let entry = APIKeyEntry(name: name, key: key)
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
            let quotaData = try await fetchQuota(key: keyEntry.key)
            let quotaResp = try JSONDecoder().decode(QuotaResponse.self, from: quotaData)

            let subResp: SubscriptionResponse
            do {
                let subData = try await fetchSubscription(key: keyEntry.key)
                subResp = try JSONDecoder().decode(SubscriptionResponse.self, from: subData)
            } catch {
                subResp = SubscriptionResponse(code: 0, data: nil, success: false)
            }

            let info = try Self.buildQuotaInfo(quotaResp: quotaResp, subResp: subResp)
            appState = .loaded(info)
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

    public static func buildQuotaInfo(quotaResp: QuotaResponse, subResp: SubscriptionResponse) throws -> QuotaInfo {
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

        return QuotaInfo(
            tier: tier,
            percentage5h: percentage,
            total5h: Int64(number),
            usedHours: usedHours,
            totalHours: totalHours,
            nextReset: nextReset
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
