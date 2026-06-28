import Foundation

/// Parses ISO-8601 video durations (e.g. "PT1H2M3S", "PT4M13S", "PT45S", "P0D").
/// `ISO8601DateFormatter` does NOT parse durations, so we scan manually.
enum YTDuration {
    /// Total seconds. YouTube video durations only ever use H/M/S (and P0D for live).
    static func seconds(from iso: String) -> Int {
        guard iso.hasPrefix("P") else { return 0 }
        var total = 0
        var number = 0
        var inTime = false   // flipped true after we hit 'T'
        for ch in iso {
            switch ch {
            case "P": continue
            case "T": inTime = true
            case "0"..."9": number = number * 10 + Int(String(ch))!
            case "H": total += number * 3600; number = 0
            case "M": total += number * (inTime ? 60 : 0); number = 0  // 'M' before 'T' = months (never for videos)
            case "S": total += number; number = 0
            case "D": total += number * 86400; number = 0
            default: number = 0
            }
        }
        return total
    }

    /// "1:02:03" / "4:13" / "0:45" label for a list row. Returns nil for zero-length (live).
    static func label(from iso: String) -> String? {
        let s = seconds(from: iso)
        guard s > 0 else { return nil }
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}
