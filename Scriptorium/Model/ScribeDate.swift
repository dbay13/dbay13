import Foundation

/// The monastic hours of the day, used instead of clock time when enabled.
enum CanonicalHour: String, CaseIterable {
    case matins = "Matins"
    case lauds = "Lauds"
    case prime = "Prime"
    case terce = "Terce"
    case sext = "Sext"
    case nones = "Nones"
    case vespers = "Vespers"
    case compline = "Compline"

    init(date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 0..<3: self = .matins
        case 3..<6: self = .lauds
        case 6..<9: self = .prime
        case 9..<12: self = .terce
        case 12..<15: self = .sext
        case 15..<18: self = .nones
        case 18..<21: self = .vespers
        default: self = .compline
        }
    }
}

enum ScribeDate {
    /// "Today · Vespers", "Yesterday · 9:41 PM", "26 October · Matins".
    static func short(_ date: Date, canonical: Bool, calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDateInToday(date) {
            day = "Today"
        } else if calendar.isDateInYesterday(date) {
            day = "Yesterday"
        } else if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            day = date.formatted(.dateTime.day().month(.wide))
        } else {
            day = date.formatted(.dateTime.day().month(.wide).year())
        }
        return "\(day) · \(time(date, canonical: canonical, calendar: calendar))"
    }

    /// "The 28th of October · Vespers".
    static func long(_ date: Date, canonical: Bool, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: date)
        let ordinal = ordinalFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
        var month = date.formatted(.dateTime.month(.wide))
        if !calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            month += " \(calendar.component(.year, from: date))"
        }
        return "The \(ordinal) of \(month) · \(time(date, canonical: canonical, calendar: calendar))"
    }

    static func time(_ date: Date, canonical: Bool, calendar: Calendar = .current) -> String {
        canonical
            ? CanonicalHour(date: date, calendar: calendar).rawValue
            : date.formatted(date: .omitted, time: .shortened)
    }

    /// "Five" for small counts, digits for larger ones.
    static func countWord(_ count: Int) -> String {
        guard count <= 20 else { return "\(count)" }
        return spellOutFormatter.string(from: NSNumber(value: count))?.capitalized ?? "\(count)"
    }

    private static let ordinalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()

    private static let spellOutFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter
    }()
}
