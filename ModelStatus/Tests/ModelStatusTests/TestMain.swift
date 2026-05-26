import Foundation

// MARK: - Test Runner (standalone, no XCTest dependency)

@main
struct TestRunner {
    static func main() async {
        print("=== ModelStatus Tests ===\n")

        // Models tests
        run("testTierFromProductName_Pro", testTierFromProductName_Pro)
        run("testTierFromProductName_Lite", testTierFromProductName_Lite)
        run("testTierFromProductName_Max", testTierFromProductName_Max)
        run("testTierFromProductName_Unknown", testTierFromProductName_Unknown)
        run("testTierDisplayLetter", testTierDisplayLetter)
        run("testParseQuotaResponse", testParseQuotaResponse)
        run("testParseQuotaResponse_5HourFilter", testParseQuotaResponse_5HourFilter)
        run("testParseSubscriptionResponse", testParseSubscriptionResponse)
        run("testTokenFormatting", testTokenFormatting)
        run("testAPIKeyEntryCoding", testAPIKeyEntryCoding)
        run("testAPIKeyEntryMaskedKey", testAPIKeyEntryMaskedKey)

        // ModelService tests
        run("testBuildQuotaInfo_Success", testBuildQuotaInfo_Success)
        run("testBuildQuotaInfo_NoFiveHourLimit", testBuildQuotaInfo_NoFiveHourLimit)
        run("testBuildQuotaInfo_MaxTier", testBuildQuotaInfo_MaxTier)
        run("testBuildQuotaInfo_NoValidSubscription", testBuildQuotaInfo_NoValidSubscription)
        run("testStatusBarTitle_Idle", testStatusBarTitle_Idle)
        run("testStatusBarTitle_Loading", testStatusBarTitle_Loading)
        run("testStatusBarTitle_Loaded", testStatusBarTitle_Loaded)
        run("testStatusBarTitle_Error", testStatusBarTitle_Error)

        print("\n=== Results: \(testsPassed) passed, \(testsFailed) failed ===")

        if testsFailed > 0 {
            Foundation.exit(1)
        }
    }

    static func run(_ name: String, _ fn: () -> Void) {
        let beforePassed = testsPassed
        let beforeFailed = testsFailed
        fn()
        if testsFailed == beforeFailed {
            print("  PASS: \(name)")
        } else {
            print("  FAIL: \(name)")
        }
    }

    static func run(_ name: String, _ fn: () throws -> Void) {
        let beforePassed = testsPassed
        let beforeFailed = testsFailed
        do {
            try fn()
            if testsFailed == beforeFailed {
                print("  PASS: \(name)")
            } else {
                print("  FAIL: \(name)")
            }
        } catch {
            print("  FAIL: \(name) - threw unexpected error: \(error)")
            testsFailed += 1
        }
    }
}
