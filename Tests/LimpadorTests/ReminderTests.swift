import Foundation
import Testing
@testable import Limpador

struct ReminderTests {
    @Test func schedulesLocalCalendarTimesAndRejectsInvalidValues() {
        let zone = TimeZone(identifier: "America/Sao_Paulo")!
        let weekly = ReminderSchedule(enabled: true, weekly: true, weekday: 2, hour: 9, minute: 30)
        #expect(weekly.valid)
        #expect(weekly.components(timeZone: zone).weekday == 2)
        #expect(weekly.components(timeZone: zone).hour == 9)
        #expect(weekly.components(timeZone: zone).timeZone == zone)
        let daily = ReminderSchedule(enabled: true, weekly: false)
        #expect(daily.components().weekday == nil)
        #expect(!ReminderSchedule(hour: 25).valid)
    }
}
