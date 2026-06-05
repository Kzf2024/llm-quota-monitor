import Foundation

// MARK: - Provider

public enum Provider: String, Codable, CaseIterable {
    case zhiPu
    case deepSeek

    public var displayName: String {
        switch self {
        case .zhiPu: return "智谱"
        case .deepSeek: return "DeepSeek"
        }
    }

    public var shortTag: String {
        switch self {
        case .zhiPu: return "智谱"
        case .deepSeek: return "DS"
        }
    }
}

// MARK: - Tier

public enum Tier: String, CaseIterable {
    case lite
    case pro
    case max
    case unknown

    public var displayLetter: String {
        switch self {
        case .lite: return "L"
        case .pro: return "P"
        case .max: return "M"
        case .unknown: return "?"
        }
    }

    public var displayName: String {
        switch self {
        case .lite: return "Lite"
        case .pro: return "Pro"
        case .max: return "Max"
        case .unknown: return "Unknown"
        }
    }

    public init(productName: String) {
        let lower = productName.lowercased()
        if lower.contains("max") {
            self = .max
        } else if lower.contains("pro") {
            self = .pro
        } else if lower.contains("lite") {
            self = .lite
        } else {
            self = .unknown
        }
    }
}

// MARK: - APIKeyEntry

public struct APIKeyEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var key: String
    public var provider: Provider

    public var maskedKey: String {
        guard key.count > 4 else { return "****" }
        let suffix = String(key.suffix(4))
        return "****\(suffix)"
    }

    public init(id: UUID = UUID(), name: String, key: String, provider: Provider = .zhiPu) {
        self.id = id
        self.name = name
        self.key = key
        self.provider = provider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        key = try container.decode(String.self, forKey: .key)
        provider = (try? container.decode(Provider.self, forKey: .provider)) ?? .zhiPu
    }
}

// MARK: - formatTokens

public func formatTokens(_ value: Int64) -> String {
    if value >= 1_000_000_000 {
        let g = Double(value) / 1_000_000_000.0
        if g == floor(g) {
            return "\(Int(g))G"
        }
        return String(format: "%.1fG", g)
    } else if value >= 1_000_000 {
        let m = Double(value) / 1_000_000.0
        if m == floor(m) {
            return "\(Int(m))M"
        }
        return String(format: "%.1fM", m)
    } else if value >= 1_000 {
        let k = Double(value) / 1_000.0
        if k == floor(k) {
            return "\(Int(k))K"
        }
        return String(format: "%.1fK", k)
    } else {
        return "\(value)"
    }
}

// MARK: - ZhiPuQuotaInfo

public struct ZhiPuQuotaInfo: Equatable {
    public let tier: Tier
    public let percentage5h: Int
    public let total5h: Int64
    public let usedHours: Double
    public let totalHours: Double
    public let nextReset: Date

    public init(tier: Tier, percentage5h: Int, total5h: Int64, usedHours: Double, totalHours: Double, nextReset: Date) {
        self.tier = tier
        self.percentage5h = percentage5h
        self.total5h = total5h
        self.usedHours = usedHours
        self.totalHours = totalHours
        self.nextReset = nextReset
    }

    public var usedDisplay: String {
        if usedHours == floor(usedHours) {
            return "\(Int(usedHours))h"
        }
        return String(format: "%.1fh", usedHours)
    }

    public var totalDisplay: String {
        if totalHours == floor(totalHours) {
            return "\(Int(totalHours))h"
        }
        return String(format: "%.1fh", totalHours)
    }
}

// MARK: - DeepSeekBalanceInfo

public struct DeepSeekBalanceInfo: Equatable {
    public let currency: String
    public let totalBalance: String
    public let grantedBalance: String
    public let toppedUpBalance: String
    public let isAvailable: Bool

    public init(currency: String, totalBalance: String, grantedBalance: String, toppedUpBalance: String, isAvailable: Bool) {
        self.currency = currency
        self.totalBalance = totalBalance
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.isAvailable = isAvailable
    }

    public var isLowBalance: Bool {
        guard let value = Double(totalBalance) else { return true }
        return value < 10.0
    }

    public var currencySymbol: String {
        currency == "CNY" ? "¥" : "$"
    }
}

// MARK: - AppState

public enum AppState: Equatable {
    case idle
    case loading
    case loadedZhiPu(ZhiPuQuotaInfo)
    case loadedDeepSeek(DeepSeekBalanceInfo)
    case error(String)
}

// MARK: - ZhiPu API Response Models

public struct QuotaResponse: Codable {
    public let code: Int
    public let data: QuotaData?
    public let success: Bool
}

public struct QuotaData: Codable {
    public let limits: [LimitItem]
    public let level: String?

    public var fiveHourLimit: LimitItem? {
        limits.first { $0.type == "TOKENS_LIMIT" && $0.unit == 3 }
    }
}

public struct LimitItem: Codable, Equatable {
    public let type: String
    public let unit: Int?
    public let number: Int?
    public let percentage: Int?
    public let usage: Int64?
    public let currentValue: Int64?
    public let remaining: Int64?
    public let nextResetTime: Double?
}

public struct SubscriptionResponse: Codable {
    public let code: Int
    public let data: [SubscriptionItem]?
    public let success: Bool

    public var validSubscription: SubscriptionItem? {
        data?.first { $0.status?.lowercased() == "valid" }
    }
}

public struct SubscriptionItem: Codable, Equatable {
    public let productName: String?
    public let status: String?
}

// MARK: - DeepSeek API Response Models

public struct DeepSeekBalanceResponse: Codable {
    public let is_available: Bool
    public let balance_infos: [DeepSeekBalanceInfoDTO]?
}

public struct DeepSeekBalanceInfoDTO: Codable, Equatable {
    public let currency: String
    public let total_balance: String
    public let granted_balance: String
    public let topped_up_balance: String
}
