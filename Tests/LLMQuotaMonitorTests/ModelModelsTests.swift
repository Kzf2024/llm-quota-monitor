import Foundation
@testable import LLMQuotaMonitorKit

// MARK: - Minimal Test Helpers

var testsPassed = 0
var testsFailed = 0

func assertEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line, _ message: String = "") {
    if a != b {
        print("FAIL \(file):\(line) - \(message.isEmpty ? "\(a) != \(b)" : message)")
        testsFailed += 1
    } else {
        testsPassed += 1
    }
}

func assertTrue(_ expr: Bool, file: String = #file, line: Int = #line, _ message: String = "") {
    if !expr {
        print("FAIL \(file):\(line) - \(message.isEmpty ? "expected true" : message)")
        testsFailed += 1
    } else {
        testsPassed += 1
    }
}

func assertThrowsError<T>(_ block: () throws -> T, file: String = #file, line: Int = #line, _ message: String = "") {
    do {
        _ = try block()
        print("FAIL \(file):\(line) - \(message.isEmpty ? "expected error but none thrown" : message)")
        testsFailed += 1
    } catch {
        testsPassed += 1
    }
}

// MARK: - Tier Tests

func testTierFromProductName_Pro() {
    assertEqual(Tier(productName: "GLM Coding Pro"), .pro, "GLM Coding Pro")
    assertEqual(Tier(productName: "GLM Pro Plan"), .pro, "GLM Pro Plan")
    assertEqual(Tier(productName: "pro"), .pro, "pro")
}

func testTierFromProductName_Lite() {
    assertEqual(Tier(productName: "GLM Coding Lite"), .lite, "GLM Coding Lite")
    assertEqual(Tier(productName: "lite plan"), .lite, "lite plan")
}

func testTierFromProductName_Max() {
    assertEqual(Tier(productName: "GLM Coding Max"), .max, "GLM Coding Max")
    assertEqual(Tier(productName: "Max Tier"), .max, "Max Tier")
}

func testTierFromProductName_Unknown() {
    assertEqual(Tier(productName: "GLM Coding Free"), .unknown, "GLM Coding Free")
    assertEqual(Tier(productName: "Something Else"), .unknown, "Something Else")
    assertEqual(Tier(productName: ""), .unknown, "empty string")
}

func testTierDisplayLetter() {
    assertEqual(Tier.lite.displayLetter, "L")
    assertEqual(Tier.pro.displayLetter, "P")
    assertEqual(Tier.max.displayLetter, "M")
    assertEqual(Tier.unknown.displayLetter, "?")
}

// MARK: - QuotaResponse Parsing

func testParseQuotaResponse() throws {
    let json = """
    {
        "code": 200,
        "success": true,
        "data": {
            "limits": [
                {
                    "type": "TOKENS_LIMIT",
                    "unit": 3,
                    "number": 1,
                    "percentage": 45,
                    "usage": 450000000,
                    "currentValue": 450000000,
                    "remaining": 550000000,
                    "nextResetTime": 1716800000.0
                },
                {
                    "type": "TOKENS_LIMIT",
                    "unit": 1,
                    "number": 1,
                    "percentage": 20,
                    "usage": 2000000000,
                    "currentValue": 2000000000,
                    "remaining": 8000000000,
                    "nextResetTime": 1716900000.0
                }
            ]
        }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(QuotaResponse.self, from: json)
    assertTrue(response.success)
    assertEqual(response.code, 200)
    assertEqual(response.data?.limits.count, 2)

    let firstLimit = response.data?.limits.first
    assertEqual(firstLimit?.type, "TOKENS_LIMIT")
    assertEqual(firstLimit?.unit, 3)
    assertEqual(firstLimit?.percentage, 45)
    assertEqual(firstLimit?.usage, 450_000_000)
    assertEqual(firstLimit?.remaining, 550_000_000)
}

func testParseQuotaResponse_5HourFilter() throws {
    let json = """
    {
        "code": 200,
        "success": true,
        "data": {
            "limits": [
                {
                    "type": "TOKENS_LIMIT",
                    "unit": 3,
                    "number": 1,
                    "percentage": 60,
                    "usage": 600000000,
                    "currentValue": 600000000,
                    "remaining": 400000000,
                    "nextResetTime": 1716800000.0
                },
                {
                    "type": "TOKENS_LIMIT",
                    "unit": 1,
                    "number": 1,
                    "percentage": 20,
                    "usage": 2000000000,
                    "currentValue": 2000000000,
                    "remaining": 8000000000,
                    "nextResetTime": 1716900000.0
                },
                {
                    "type": "RATE_LIMIT",
                    "unit": 3,
                    "number": 1,
                    "percentage": 10,
                    "usage": 100,
                    "currentValue": 100,
                    "remaining": 900,
                    "nextResetTime": 1716800000.0
                }
            ]
        }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(QuotaResponse.self, from: json)
    let fiveHourLimit = response.data?.fiveHourLimit

    assertTrue(fiveHourLimit != nil)
    assertEqual(fiveHourLimit?.type, "TOKENS_LIMIT")
    assertEqual(fiveHourLimit?.unit, 3)
    assertEqual(fiveHourLimit?.percentage, 60)
    assertEqual(fiveHourLimit?.usage, 600_000_000)
}

// MARK: - SubscriptionResponse Parsing

func testParseSubscriptionResponse() throws {
    let json = """
    {
        "code": 200,
        "success": true,
        "data": [
            {
                "productName": "GLM Coding Pro",
                "status": "expired"
            },
            {
                "productName": "GLM Coding Lite",
                "status": "valid"
            },
            {
                "productName": "GLM Coding Max",
                "status": "cancelled"
            }
        ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(SubscriptionResponse.self, from: json)
    assertTrue(response.success)
    assertEqual(response.data?.count, 3)

    let valid = response.validSubscription
    assertTrue(valid != nil)
    assertEqual(valid?.productName, "GLM Coding Lite")
    assertEqual(valid?.status, "valid")
}

// MARK: - Token Formatting

func testTokenFormatting() {
    assertEqual(formatTokens(800_000_000), "800M")
    assertEqual(formatTokens(1_500_000_000), "1.5G")
    assertEqual(formatTokens(500_000), "500K")
    assertEqual(formatTokens(999), "999")
    assertEqual(formatTokens(1_000), "1K")
    assertEqual(formatTokens(1_000_000), "1M")
    assertEqual(formatTokens(1_000_000_000), "1G")
    assertEqual(formatTokens(1_200_000), "1.2M")
}

// MARK: - APIKeyEntry Coding

func testAPIKeyEntryCoding() throws {
    let original = APIKeyEntry(
        id: UUID(),
        name: "Test Key",
        key: "sk-abcdef1234567890",
        provider: .zhiPu
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(APIKeyEntry.self, from: data)

    assertEqual(decoded.id, original.id)
    assertEqual(decoded.name, original.name)
    assertEqual(decoded.key, original.key)
    assertEqual(decoded.provider, .zhiPu)
}

func testAPIKeyEntryMaskedKey() {
    let entry = APIKeyEntry(name: "Test", key: "sk-abcdef1234567890")
    assertEqual(entry.maskedKey, "****7890")

    let shortKey = APIKeyEntry(name: "Short", key: "abc")
    assertEqual(shortKey.maskedKey, "****")

    let exactFour = APIKeyEntry(name: "Four", key: "abcd")
    assertEqual(exactFour.maskedKey, "****")
}

// MARK: - APIKeyEntry Backward Compatibility

func testAPIKeyEntryBackwardCompat() throws {
    // JSON without provider field → should default to .zhiPu
    let json = """
    {"id": "550e8400-e29b-41d4-a716-446655440000", "name": "Old Key", "key": "sk-old"}
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(APIKeyEntry.self, from: json)
    assertEqual(decoded.provider, .zhiPu, "missing provider should default to zhiPu")
    assertEqual(decoded.name, "Old Key")
}

// MARK: - Provider Tests

func testProviderDisplayNames() {
    assertEqual(Provider.zhiPu.displayName, "智谱")
    assertEqual(Provider.deepSeek.displayName, "DeepSeek")
    assertEqual(Provider.zhiPu.shortTag, "智谱")
    assertEqual(Provider.deepSeek.shortTag, "DS")
}

// MARK: - DeepSeek Response Parsing

func testDeepSeekBalanceResponseParsing() throws {
    let json = """
    {
        "is_available": true,
        "balance_infos": [
            {
                "currency": "CNY",
                "total_balance": "110.00",
                "granted_balance": "10.00",
                "topped_up_balance": "100.00"
            },
            {
                "currency": "USD",
                "total_balance": "5.50",
                "granted_balance": "0.00",
                "topped_up_balance": "5.50"
            }
        ]
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: json)
    assertTrue(response.is_available)
    assertEqual(response.balance_infos?.count, 2)

    let cny = response.balance_infos?.first
    assertEqual(cny?.currency, "CNY")
    assertEqual(cny?.total_balance, "110.00")
    assertEqual(cny?.granted_balance, "10.00")
    assertEqual(cny?.topped_up_balance, "100.00")
}

// MARK: - DeepSeekBalanceInfo Tests

func testDeepSeekLowBalance() {
    let low = DeepSeekBalanceInfo(currency: "CNY", totalBalance: "5.20", grantedBalance: "0.00", toppedUpBalance: "5.20", isAvailable: true)
    assertTrue(low.isLowBalance, "5.20 < 10 should be low balance")

    let ok = DeepSeekBalanceInfo(currency: "CNY", totalBalance: "100.00", grantedBalance: "10.00", toppedUpBalance: "90.00", isAvailable: true)
    assertTrue(!ok.isLowBalance, "100 >= 10 should not be low balance")

    let usd = DeepSeekBalanceInfo(currency: "USD", totalBalance: "9.99", grantedBalance: "0.00", toppedUpBalance: "9.99", isAvailable: true)
    assertTrue(usd.isLowBalance, "9.99 < 10 should be low balance")
}

func testDeepSeekCurrencySymbol() {
    let cny = DeepSeekBalanceInfo(currency: "CNY", totalBalance: "50.00", grantedBalance: "0.00", toppedUpBalance: "50.00", isAvailable: true)
    assertEqual(cny.currencySymbol, "¥")

    let usd = DeepSeekBalanceInfo(currency: "USD", totalBalance: "10.00", grantedBalance: "0.00", toppedUpBalance: "10.00", isAvailable: true)
    assertEqual(usd.currencySymbol, "$")
}
