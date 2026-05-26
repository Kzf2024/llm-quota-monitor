import Foundation

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

    public var maskedKey: String {
        guard key.count > 4 else { return "****" }
        let suffix = String(key.suffix(4))
        return "****\(suffix)"
    }

    public init(id: UUID = UUID(), name: String, key: String) {
        self.id = id
        self.name = name
        self.key = key
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

// MARK: - QuotaInfo

public struct QuotaInfo: Equatable {
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

// MARK: - AppState

public enum AppState: Equatable {
    case idle
    case loading
    case loaded(QuotaInfo)
    case error(String)
}

// MARK: - API Response Models

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
