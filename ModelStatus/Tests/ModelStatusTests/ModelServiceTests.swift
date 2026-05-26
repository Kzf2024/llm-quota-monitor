import Foundation
@testable import ModelStatusKit

// MARK: - ModelService Test Helpers

private func makeQuotaResponse(
    usage: Int64,
    number: Int,
    percentage: Int? = nil,
    nextResetTime: Double? = nil
) -> QuotaResponse {
    let limit = LimitItem(
        type: "TOKENS_LIMIT",
        unit: 3,
        number: number,
        percentage: percentage,
        usage: nil,
        currentValue: usage,
        remaining: nil,
        nextResetTime: nextResetTime
    )
    return QuotaResponse(
        code: 200,
        data: QuotaData(limits: [limit], level: nil),
        success: true
    )
}

private func makeSubscriptionResponse(
    productName: String? = nil,
    status: String = "valid"
) -> SubscriptionResponse {
    let item = SubscriptionItem(productName: productName, status: status)
    return SubscriptionResponse(
        code: 200,
        data: [item],
        success: true
    )
}

// MARK: - buildQuotaInfo Tests

func testBuildQuotaInfo_Success() throws {
    let quotaResp = makeQuotaResponse(
        usage: 360_000_000,
        number: 800_000_000,
        percentage: 45,
        nextResetTime: 1_700_000_000_000
    )
    let subResp = makeSubscriptionResponse(productName: "GLM-4 Pro")

    let info = try ModelService.buildQuotaInfo(quotaResp: quotaResp, subResp: subResp)

    assertEqual(info.tier, .pro)
    assertEqual(info.percentage5h, 45)
    assertEqual(info.usedHours, Double(800_000_000) * 45.0 / 100.0)
    assertEqual(info.totalHours, Double(800_000_000))
}

func testBuildQuotaInfo_NoFiveHourLimit() {
    let quotaResp = QuotaResponse(
        code: 200,
        data: QuotaData(limits: [], level: nil),
        success: true
    )
    let subResp = makeSubscriptionResponse(productName: "GLM-4 Pro")

    assertThrowsError {
        try ModelService.buildQuotaInfo(quotaResp: quotaResp, subResp: subResp)
    }
}

func testBuildQuotaInfo_MaxTier() throws {
    let quotaResp = makeQuotaResponse(
        usage: 1_200_000_000,
        number: 2_000_000_000,
        percentage: 60
    )
    let subResp = makeSubscriptionResponse(productName: "GLM-4 Max")

    let info = try ModelService.buildQuotaInfo(quotaResp: quotaResp, subResp: subResp)

    assertEqual(info.tier, .max)
    assertEqual(info.percentage5h, 60)
    assertEqual(info.usedHours, Double(2_000_000_000) * 60.0 / 100.0)
    assertEqual(info.totalHours, Double(2_000_000_000))
}

func testBuildQuotaInfo_NoValidSubscription() throws {
    let quotaResp = makeQuotaResponse(
        usage: 100_000,
        number: 500_000,
        percentage: 20
    )
    let subResp = SubscriptionResponse(
        code: 200,
        data: [SubscriptionItem(productName: "Free", status: "expired")],
        success: true
    )

    let info = try ModelService.buildQuotaInfo(quotaResp: quotaResp, subResp: subResp)

    assertEqual(info.tier, .unknown)
    assertEqual(info.percentage5h, 20)
}

// MARK: - statusBarTitle Tests

func testStatusBarTitle_Idle() {
    let service = ModelService()
    service.appState = .idle
    assertEqual(service.statusBarTitle, "\u{2699}\u{FE0F}")
}

func testStatusBarTitle_Loading() {
    let service = ModelService()
    service.appState = .loading
    assertEqual(service.statusBarTitle, "...")
}

func testStatusBarTitle_Loaded() {
    let service = ModelService()
    let info = QuotaInfo(
        tier: .pro,
        percentage5h: 62,
        total5h: 800_000_000,
        usedHours: 496_000_000,
        totalHours: 800_000_000,
        nextReset: Date()
    )
    service.appState = .loaded(info)
    assertEqual(service.statusBarTitle, "P 62%")
}

func testStatusBarTitle_Error() {
    let service = ModelService()
    service.appState = .error("Something went wrong")
    assertEqual(service.statusBarTitle, "\u{26A0}\u{FE0F}")
}
