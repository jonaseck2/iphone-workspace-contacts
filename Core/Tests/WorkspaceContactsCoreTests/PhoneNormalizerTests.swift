import Testing
@testable import WorkspaceContactsCore

@Suite struct PhoneNormalizerTests {
    private func norm(_ s: String) -> String? {
        PhoneNormalizer.e164(s, defaultCountryCode: "46")
    }

    @Test func alreadyE164_passesThrough() {
        #expect(norm("+46701234567") == "+46701234567")
    }

    @Test func stripsFormatting() {
        #expect(norm("+46 70-123 45 67") == "+46701234567")
        #expect(norm("(070) 123.45.67") == "+46701234567")
    }

    @Test func nationalWithLeadingZero_usesDefaultCountryCode() {
        #expect(norm("0701234567") == "+46701234567")
    }

    @Test func doubleZeroInternationalPrefix_becomesPlus() {
        #expect(norm("004670 123 45 67") == "+46701234567")
    }

    @Test func bareNationalDigits_getDefaultCountryCode() {
        // No +, no leading 0, no 00 -> treat as national subscriber number.
        #expect(norm("701234567") == "+46701234567")
    }

    @Test func emptyOrJunk_returnsNil() {
        #expect(norm("") == nil)
        #expect(norm("   ") == nil)
        #expect(norm("abc") == nil)
        #expect(norm("+") == nil)
    }

    @Test func tooShortOrTooLong_returnsNil() {
        #expect(norm("+123") == nil)                 // 3 digits, too short
        #expect(norm("+1234567890123456") == nil)    // 16 digits, too long
    }
}
