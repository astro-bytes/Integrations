//
//  FBDatabaseSubscription.swift
//  FirebaseIntegrations
//
//  Created by Porter McGary on 1/23/24.
//

import Combine
import FirebaseDatabase
import Foundation
import Logger
import Utility

final class FBDatabaseSubscription<Subscriber: Combine.Subscriber>: Combine.Subscription 
where Subscriber.Input: Decodable, Subscriber.Failure == Error {
    
    private var reference: DatabaseReference?
    private var handle: DatabaseHandle?
    
    init(subscriber: Subscriber, reference: DatabaseReference, eventType: DataEventType, decoder: Database.Decoder, domain: String) {
        self.reference = reference
        handle = reference.observe(eventType, with: { snapshot in
            guard snapshot.exists() else {
                subscriber.receive(completion: .failure(CoreError.notFound))
                return
            }
            
            do {
                let payload = try snapshot.data(as: Subscriber.Input.self, decoder: decoder)
                _ = subscriber.receive(payload)
            } catch {
                Logger.log(.warning, error: error, domain: domain)
                subscriber.receive(completion: .failure(error))
            }
        }, withCancel: { error in
            subscriber.receive(completion: .failure(error))
        })
    }
    
    func request(_ demand: Subscribers.Demand) {
        // We do nothing here as we only want to send events when they occur.
        // See, for more info: https://developer.apple.com/documentation/combine/subscribers/demand
    }
    
    func cancel() {
        if let handle = handle {
            reference?.removeObserver(withHandle: handle)
        }
        handle = nil
        reference = nil
    }
}
