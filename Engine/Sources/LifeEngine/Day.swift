import Foundation

/// A calendar date with no time and no zone. The engine reasons in days only.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, in zone: TimeZone = .current) {
        var cal = Day.calendar
        cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        self.init(c.year!, c.month!, c.day!)
    }

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    var utcDate: Date {
        Day.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 1 = Sunday ... 7 = Saturday, as in `Calendar.component(.weekday)`.
    public var weekday: Int {
        Day.calendar.component(.weekday, from: utcDate)
    }

    public func adding(days n: Int) -> Day {
        Day(Day.calendar.date(byAdding: .day, value: n, to: utcDate)!, in: Day.calendar.timeZone)
    }

    public func days(since other: Day) -> Int {
        Day.calendar.dateComponents([.day], from: other.utcDate, to: utcDate).day!
    }

    public static func < (a: Day, b: Day) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

extension Day: Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "expected YYYY-MM-DD, got \(s)"))
        }
        self.init(parts[0], parts[1], parts[2])
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
