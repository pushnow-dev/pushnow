import Foundation

struct DiscoveryAccountScope: Hashable {
    let userID: String
    let generation: UUID

    init?(session: AuthSession?, generation: UUID) {
        guard let session, session.isVerified, !session.userID.isEmpty else { return nil }
        userID = session.userID
        self.generation = generation
    }
}

struct DiscoverySubscription: Codable, Equatable, Identifiable {
    let channelID: String
    var wantsNotification: Bool
    var hour: Int
    var minute: Int
    var timeZoneID: String
    var id: String { channelID }

    init(channelID: String, wantsNotification: Bool = true, hour: Int = 9,
         minute: Int = 0, timeZoneID: String = TimeZone.current.identifier) {
        self.channelID = channelID
        self.wantsNotification = wantsNotification
        self.hour = hour
        self.minute = minute
        self.timeZoneID = timeZoneID
    }

    var isValid: Bool {
        !channelID.isEmpty && (0...23).contains(hour) && (0...59).contains(minute)
            && TimeZone(identifier: timeZoneID) != nil
    }

    // A fixed GMT calendar keeps wall-clock editing independent of the phone's timezone and DST.
    var pickerDate: Date {
        get { Self.pickerCalendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute))! }
        set {
            let components = Self.pickerCalendar.dateComponents([.hour, .minute], from: newValue)
            hour = components.hour ?? 9
            minute = components.minute ?? 0
        }
    }

    static var pickerCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

enum DiscoverySubscriptionError: Error {
    case accountChanged, invalidPreference, unreadableStorage
}
