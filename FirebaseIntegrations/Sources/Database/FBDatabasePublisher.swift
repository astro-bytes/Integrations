//
//  FBDatabasePublisher.swift
//  FirebaseIntegrations
//
//  Created by Porter McGary on 1/23/24.
//

import Combine
import FirebaseDatabase
import Foundation

struct FBDatabasePublisher<Output: FirebaseTableEntry>: Combine.Publisher {
    typealias Failure = Error
    
    private let reference: DatabaseReference
    private let eventType: DataEventType
    private let decoder: Database.Decoder
    private let domain: String
    
    init(_ reference: DatabaseReference, eventType: DataEventType, decoder: Database.Decoder, domain: String) {
        self.reference = reference
        self.eventType = eventType
        self.decoder = decoder
        self.domain = domain
    }
    
    func receive<Subscriber>(subscriber: Subscriber) where Subscriber : Combine.Subscriber,
                                                           FBDatabasePublisher.Failure == Subscriber.Failure,
                                                           FBDatabasePublisher.Output == Subscriber.Input {
        let subscription = FBDatabaseSubscription(
            subscriber: subscriber,
            reference: reference,
            eventType: eventType,
            decoder: decoder,
            domain: domain
        )
        
        subscriber.receive(subscription: subscription)
    }
}
