import Foundation
import os

public enum RecallAnswer: Sendable, Hashable {
    case text(String)
    case number(Double)
    case list([String])

    public var stored: String {
        switch self {
        case .text(let text): text
        case .number(let number): jsNumberString(number)
        case .list(let items): items.joined(separator: ", ")
        }
    }

    var collapsed: RecallAnswer {
        switch self {
        case .text(let text): .text(text.jsCollapsed)
        case .number: self
        case .list(let items): .list(items.map(\.jsCollapsed))
        }
    }
}

public typealias RecallFormatFn = @Sendable (RecallAnswer, FormField, String) -> String

let storedRecallFormat: RecallFormatFn = { answer, _, _ in answer.stored }

private let stampTypes = ["date", "time", "datetime"]
private let localeLimit = 32
private let locales = OSAllocatedUnfairLock(initialState: [String: Locale]())
private let languages = Set(Locale.availableIdentifiers.map { $0.prefix { $0 != "_" }.lowercased() })
private let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
private let gregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    return calendar
}()

private func supportedLocale(_ tag: String) -> Locale {
    guard let parsed = canonicalTag(tag), languages.contains(parsed.parts[0]),
        parsed.extensions.allSatisfy({ (1...8).contains($0.count) && $0.allSatisfy(\.isASCIIAlphanumeric) })
    else { return Locale(identifier: "en") }
    return Locale(identifier: tag)
}

func recallLocale(_ tag: String) -> Locale {
    if let cached = locales.withLock({ $0[tag] }) { return cached }
    let locale = supportedLocale(tag)
    locales.withLock { cache in
        if cache.count >= localeLimit { cache.removeAll(keepingCapacity: true) }
        cache[tag] = locale
    }
    return locale
}

func formatNumber(_ number: Double, _ locale: Locale) -> String {
    (number + 0).formatted(.number.precision(.significantDigits(1...21)).locale(locale))
}

private func stamp(_ type: String, _ value: String) -> Date? {
    let digits = value.split { !$0.isASCIIDigit }.compactMap { Int($0) }
    let parts = type == "time" ? [1970, 1, 1] + digits : digits
    guard parts.count >= 3 else { return nil }
    let time = parts.dropFirst(3)
    let components = DateComponents(
        year: parts[0], month: parts[1], day: parts[2], hour: time.first ?? 0, minute: time.dropFirst().first ?? 0)
    return gregorian.date(from: components)
}

private func dateStyle(_ type: String, _ locale: Locale) -> Date.FormatStyle {
    var calendar = locale.calendar
    calendar.timeZone = utc
    return Date.FormatStyle(
        date: type == "time" ? .omitted : .abbreviated, time: type == "date" ? .omitted : .shortened, locale: locale,
        calendar: calendar, timeZone: utc)
}

private func localized(_ answer: RecallAnswer, _ type: String, _ locale: Locale) -> String? {
    switch answer {
    case .list(let items):
        return items.formatted(.list(type: .and, width: .standard).locale(locale))
    case .number(let number):
        guard numberTypes.contains(type) || type == "group", !jsNumberString(number).contains("e") else { return nil }
        return formatNumber(number, locale)
    case .text(let text):
        guard stampTypes.contains(type), matchesFormat(type, text), let date = stamp(type, text) else { return nil }
        return date.formatted(dateStyle(type, locale))
    }
}

let defaultRecallFormat: RecallFormatFn = { answer, field, locale in
    let collapsed = answer.collapsed
    return localized(collapsed, field.type, recallLocale(locale)) ?? collapsed.stored
}
