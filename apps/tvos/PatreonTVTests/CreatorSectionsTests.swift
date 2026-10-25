//
//  CreatorSectionsTests.swift
//  PatreonTVTests
//
//  Paid/free split for the Creators tab: /api/members carries the relationships
//  and /api/pledges catches paid subscriptions that endpoint hides.
//

import XCTest
@testable import PatreonTV

final class CreatorSectionsTests: XCTestCase {

    func test_active_patron_is_paid() {
        let split = CreatorSections.split(
            members: [(campaignID: "c1", isPaid: true)],
            pledgeCampaignIDs: []
        )

        XCTAssertEqual(split.paid, ["c1"])
        XCTAssertTrue(split.free.isEmpty)
    }

    func test_free_follow_is_not_paid() {
        let split = CreatorSections.split(
            members: [(campaignID: "c1", isPaid: false)],
            pledgeCampaignIDs: []
        )

        XCTAssertTrue(split.paid.isEmpty)
        XCTAssertEqual(split.free, ["c1"])
    }

    /// A paid subscription can be missing from /members but show up in
    /// /pledges; it must still land in the paid section.
    func test_pledge_only_campaign_is_paid() {
        let split = CreatorSections.split(
            members: [],
            pledgeCampaignIDs: ["c9"]
        )

        XCTAssertEqual(split.paid, ["c9"])
        XCTAssertTrue(split.free.isEmpty)
    }

    func test_campaign_in_both_sources_is_paid_once() {
        let split = CreatorSections.split(
            members: [(campaignID: "c1", isPaid: false)],
            pledgeCampaignIDs: ["c1"]
        )

        XCTAssertEqual(split.paid, ["c1"])
        XCTAssertTrue(split.free.isEmpty)
    }

    func test_duplicates_are_dropped() {
        let split = CreatorSections.split(
            members: [
                (campaignID: "c1", isPaid: true),
                (campaignID: "c1", isPaid: true),
                (campaignID: "c2", isPaid: false),
                (campaignID: "c2", isPaid: false),
            ],
            pledgeCampaignIDs: ["c1", "c1"]
        )

        XCTAssertEqual(split.paid, ["c1"])
        XCTAssertEqual(split.free, ["c2"])
    }

    /// Each group keeps the API order (most recent first); paid stays above
    /// free regardless of the order the two sources arrive in.
    func test_order_is_preserved_within_each_group() {
        let split = CreatorSections.split(
            members: [
                (campaignID: "free-1", isPaid: false),
                (campaignID: "paid-1", isPaid: true),
                (campaignID: "free-2", isPaid: false),
                (campaignID: "paid-2", isPaid: true),
            ],
            pledgeCampaignIDs: ["paid-3"]
        )

        XCTAssertEqual(split.paid, ["paid-1", "paid-2", "paid-3"])
        XCTAssertEqual(split.free, ["free-1", "free-2"])
    }

    /// Lapsed patrons never reach the split: the view model filters on
    /// `isCurrentRelationship` first.
    func test_lapsed_membership_is_not_a_current_relationship() throws {
        let json = """
        {
          "data": {
            "type": "member",
            "id": "m1",
            "attributes": {
              "patron_status": "former_patron",
              "is_free_member": false,
              "currently_entitled_amount_cents": 0
            }
          }
        }
        """

        let doc = try JSONAPIDecoder.decode(
            SingleResource<Membership>.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(doc.data.isActivePatron)
        XCTAssertFalse(doc.data.isCurrentRelationship)
    }

    /// Both sections are listed A–Z, ignoring case and accents.
    func test_creators_sort_alphabetically() throws {
        let zeta = try campaign(id: "c3", name: "zeta")
        let beta = try campaign(id: "c2", name: "Beta")
        let alvarez = try campaign(id: "c1", name: "Álvarez")

        let sorted = [zeta, beta, alvarez]
            .sorted(by: CreatorsViewModel.alphabetically)
            .map(\.id)

        XCTAssertEqual(sorted, ["c1", "c2", "c3"])
    }

    func test_creators_with_the_same_name_fall_back_to_id() throws {
        let second = try campaign(id: "c2", name: "Same")
        let first = try campaign(id: "c1", name: "Same")

        let sorted = [second, first]
            .sorted(by: CreatorsViewModel.alphabetically)
            .map(\.id)

        XCTAssertEqual(sorted, ["c1", "c2"])
    }

    private func campaign(id: String, name: String) throws -> Campaign {
        let json = """
        { "type": "campaign", "id": "\(id)", "attributes": { "name": "\(name)" } }
        """
        return try JSONAPIDecoder.decode(Campaign.self, from: Data(json.utf8))
    }
}
