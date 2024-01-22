//
//  FirebaseTableEntry.swift
//  FirebaseIntegrations
//
//  Created by Porter McGary on 1/23/24.
//

import Foundation

/// A protocol representing an entry in a Firebase table.
/// Conforming types must be Identifiable and Codable where ID is of type String.
public protocol FirebaseTableEntry: Identifiable, Codable where ID == String {
    /// The name of the Firebase table associated with the conforming type.
    static var tablename: String { get }
}
