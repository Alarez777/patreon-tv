//
//  CreatorSections.swift
//  PatreonTV
//
//  Splits the user's current creator relationships into paid memberships and
//  free follows, so the Creators tab can put the paid ones first.
//

import Foundation

enum CreatorSections {

    struct Split: Equatable {
        /// Campaigns with an active paid membership, in the order the API
        /// returned them (most recent first).
        var paid: [String]
        /// Campaigns the user follows for free, in API order.
        var free: [String]

        var isEmpty: Bool { paid.isEmpty && free.isEmpty }
    }

    /// - Parameters:
    ///   - members: the user's current relationships from `/api/members`
    ///     (active patrons and free follows, lapsed excluded). `isPaid` is
    ///     `Membership.isActivePatron`.
    ///   - pledgeCampaignIDs: campaigns with an active `/api/pledges` entry.
    ///     That endpoint also surfaces subscriptions `/api/members` hides.
    /// A campaign present in both groups counts as paid and appears once.
    static func split(
        members: [(campaignID: String, isPaid: Bool)],
        pledgeCampaignIDs: [String]
    ) -> Split {
        var paid: [String] = []
        var free: [String] = []
        var paidCampaignIDs = Set<String>()
        var freeCampaignIDs = Set<String>()

        for member in members {
            if member.isPaid {
                if paidCampaignIDs.insert(member.campaignID).inserted {
                    paid.append(member.campaignID)
                }
            } else if freeCampaignIDs.insert(member.campaignID).inserted {
                free.append(member.campaignID)
            }
        }

        for campaignID in pledgeCampaignIDs {
            if paidCampaignIDs.insert(campaignID).inserted {
                paid.append(campaignID)
            }
        }

        return Split(
            paid: paid,
            free: free.filter { !paidCampaignIDs.contains($0) }
        )
    }
}
