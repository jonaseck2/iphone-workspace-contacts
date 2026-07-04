import Foundation

/// Best-effort E.164 normalization. A pragmatic heuristic (not a full libphonenumber);
/// good enough for a single-region corporate directory. Swap in a real library later if
/// multi-region correctness is needed.
public enum PhoneNormalizer {

    /// Returns a `+`-prefixed E.164-ish string (8–15 digits after `+`), or nil.
    /// - Parameters:
    ///   - raw: the raw phone string from the directory.
    ///   - defaultCountryCode: digits only, e.g. "46" for Sweden.
    public static func e164(_ raw: String, defaultCountryCode: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasPlus = trimmed.hasPrefix("+")
        let digits = trimmed.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        let national: String
        if hasPlus {
            national = digits
        } else if digits.hasPrefix("00") {
            national = String(digits.dropFirst(2))
        } else if digits.hasPrefix("0") {
            national = defaultCountryCode + String(digits.dropFirst(1))
        } else {
            national = defaultCountryCode + digits
        }

        guard (8...15).contains(national.count) else { return nil }
        return "+" + national
    }
}
