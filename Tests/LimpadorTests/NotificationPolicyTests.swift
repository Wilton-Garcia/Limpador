import Foundation
import Testing
@testable import Limpador

struct NotificationPolicyTests {
    @Test func suppressesRepeatedLowSpaceAlertsUntilRecoveryOrCooldown() {
        let now = Date()
        var policy = LowSpacePolicy()
        let decision1 = policy.shouldNotify(available: 1, threshold: 10, now: now)
        #expect(decision1)
        policy.lastSent = now
        let decision2 = !policy.shouldNotify(available: 1, threshold: 10, now: now.addingTimeInterval(60))
        #expect(decision2)
        let decision3 = !policy.shouldNotify(available: 20, threshold: 10, now: now.addingTimeInterval(90))
        #expect(decision3)
        let decision4 = policy.shouldNotify(available: 1, threshold: 10, now: now.addingTimeInterval(120))
        #expect(decision4)
        var restarted = LowSpacePolicy(lastSent: now)
        let decision5 = !restarted.shouldNotify(available: 1, threshold: 10, now: now.addingTimeInterval(180))
        #expect(decision5)
        let decision6 = restarted.shouldNotify(available: 1, threshold: 10, now: now.addingTimeInterval(86401))
        #expect(decision6)
    }
}
