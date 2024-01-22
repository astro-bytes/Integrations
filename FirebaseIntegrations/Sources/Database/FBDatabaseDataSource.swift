//
//  FBDatabaseDataSource.swift
//  FirebaseIntegration
//
//  Created by Porter McGary on 1/21/24.
//

import Combine
import FirebaseDatabase
import FirebaseSharedSwift
import Foundation
import GatewayBasics
import Logger
import UseCaseBasics
import Utility

/// A class providing data source functionality for Firebase realtime database.
/// - Parameter Payload: A type conforming to `FirebaseTableEntry`.
public actor FBDatabaseDataSource<Value: FirebaseTableEntry>: MutableDataSource {
    public typealias MutablePayload = Value
    
    /// The domain associated with Firebase data source.
    private nonisolated let domain: String = "FB DataSource"
    /// The name of the Firebase table associated with the payload type.
    private nonisolated let tablename: String = MutablePayload.tablename
    /// The reference to the Firebase database.
    private nonisolated let reference: DatabaseReference
    /// A subject for publishing payload updates and errors.
    private nonisolated let subject = PassthroughSubject<Output, Error>()
    
    /// Encoder with date encoding strategy set to seconds since 1970.
    private let encoder = {
        let encoder = FirebaseDataEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    
    /// Decoder with date decoding strategy set to seconds since 1970.
    private let decoder = {
        let decoder = Database.Decoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
    
    /// Initializes the data source with a Firebase database reference.
    /// - Parameter reference: The reference to the Firebase database. This will be the root of where the table is located.
    public init(reference: DatabaseReference) {
        self.reference = reference
    }
    
    /// Initializes Firebase database table. No need to call; the table is created when a value is inserted.
    /// - Throws: a Firebase error if there is a failure
    public func initialize() async throws {
        sinkTable()
    }
    
    /// Deletes the entire Firebase table associated with the payload type.
    /// - Throws: a Firebase error if there is a failure
    public func delete() async throws {
        do {
            try await reference.removeValue()
        } catch {
            Logger.log(.warning, error: error, domain: domain)
            throw error
        }
    }
    
    /// Inserts a single object into the Firebase realtime database.
    /// - Parameter payload: The object to be inserted.
    /// - Throws: a Firebase error if there is a failure
    public func insert(_ payload: MutablePayload) async throws {
        do {
            try reference
                .child(tablename)
                .child(payload.id)
                .setValue(from: payload, encoder: encoder)
        } catch {
            Logger.log(.warning, error: error, domain: domain)
            throw error
        }
    }
    
    /// Updates an existing object in the Firebase realtime database.
    /// - Parameter payload: The updated object.
    /// - Throws: a Firebase error if there is a failure
    public func update(_ payload: MutablePayload) async throws {
        try await insert(payload)
    }
    
    /// Fetches an object by its ID from the Firebase table.
    /// - Parameter id: The ID of the object to fetch.
    /// - Returns: A Result containing the fetched object on success, or an error on failure.
    public func fetch(id: MutablePayload.ID) async -> Result<MutablePayload, Error> {
        do {
            let snapshot = try await reference
                .child(tablename)
                .child(id)
                .getData()
            
            guard snapshot.exists() else { return .failure(CoreError.notFound) }
            let payload = try snapshot.data(as: MutablePayload.self, decoder: decoder)
            return .success(payload)
        } catch {
            Logger.log(.warning, error: error, domain: domain)
            return .failure(error)
        }
    }
    
    /// Fetches all objects from the Firebase table.
    /// - Returns: A Result containing a dictionary of fetched objects (ID to Payload) on success, or an error on failure.
    public func fetch() async -> Result<[MutablePayload.ID : MutablePayload], Error> {
        do {
            let snapshot = try await reference
                .child(tablename)
                .getData()
            
            guard snapshot.exists() else { return .failure(CoreError.notFound) }
            let payloads = try snapshot.data(as: [MutablePayload.ID: MutablePayload].self, decoder: decoder)
            return .success(payloads)
        } catch {
            Logger.log(.warning, error: error, domain: domain)
            return .failure(error)
        }
    }
    
    /// Removes an object from the Firebase table by its ID.
    /// - Parameter id: The ID of the object to remove.
    /// - Throws: a Firebase error if there is a failure
    public func remove(id: MutablePayload.ID) async throws {
        do {
            try await reference
                .child(tablename)
                .child(id)
                .removeValue()
        } catch {
            Logger.log(.warning, error: error, domain: domain)
            throw error
        }
    }
    
    /// Clears all data from the Firebase table associated with the payload type.
    /// - Throws: a Firebase error if there is a failure
    public func clear() async throws {
        do {
            try await reference
                .child(tablename)
                .removeValue()
        } catch {
            Logger.log(.warning, error: error, domain: domain)
            throw error
        }
    }
}

/// An extension of `FBDatabaseDataSource` conforming to the `PublishableDataSource` and `IdentifiablePublishableDataSource` protocols.
extension FBDatabaseDataSource: PublishableDataSource, IdentifiablePublishableDataSource {
    /// The payload type for the publisher.
    public typealias Output = [Value.ID: Value]
    
    /// The identifiable payload type for the publisher.
    public typealias IdentifiableOutput = Value
    
    /// A publisher that emits the entire table payload when changes occur.
    public nonisolated var publisher: AnyPublisher<Output, Error> {
        subject.eraseToAnyPublisher()
    }
    
    /// Observes changes in the Firebase database table and sends updates to the publisher.
    func sinkTable() {
        reference.child(tablename).observe(.value) { [weak self] snapshot in
            guard self.isNotNil else {
                Logger.log(.warning, msg: "FBDatabaseDataSource has been de-initialized.")
                return
            }
            
            guard snapshot.exists() else {
                self!.subject.send([Value.ID: Value]())
                return
            }
            
            guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                Logger.log(.warning, msg: "Snapshot children do not exist")
                return
            }
            
            do {
                let payload = try children.reduce(into: Output()) { partialResult, snapshot in
                    let output = try snapshot.data(as: Value.self, decoder: self!.decoder)
                    partialResult[output.id] = output
                }
                self!.subject.send(payload)
            } catch {
                Logger.log(.warning, error: error, domain: self!.domain)
                self!.subject.send(completion: .failure(error))
            }
        } withCancel: { [weak self] error in
            guard self.isNotNil else { return }
            Logger.log(.warning, error: error, domain: self!.domain)
            self!.subject.send(completion: .failure(error))
        }
    }
    
    /// Returns a publisher for the specified identifier, observing changes in the database for that specific ID.
    /// - Parameter id: The identifier for which to observe changes.
    /// - Returns: A publisher emitting the payload for the given identifier or an error.
    public nonisolated func publisherForValue(with id: Value.ID) -> AnyPublisher<IdentifiableOutput, Error> {
        // Use this link to help solve the problem here
        // https://github.com/urban-health-labs/CombineFirebase/blob/master/Sources/Database/DatabaseQuery%2BCombine.swift
        let reference = self.reference.child(tablename).child(id)
        return FBDatabasePublisher(reference, eventType: .value, decoder: decoder, domain: domain).eraseToAnyPublisher()
    }
}
