//
//  File.swift
//  
//
//  Created by Porter McGary on 1/22/24.
//

import EntityBasics
import FirebaseIntegrations
import Foundation

struct User: FirebaseTableEntry, Entity {
    static var tablename: String = "user"
    
    var id: String
    var name: String
    
    var uuid: UUID? {
        UUID(uuidString: id)
    }
    
    init(id: UUID? = UUID(), name: String) {
        if let id {
            self.id = id.uuidString
        } else {
            self.id = UUID().uuidString
        }
        
        self.name = name
    }
}

extension User {
    static let johnDoe = User(
        id: UUID(uuidString: "188CF379-39A4-49CE-9323-3A5DCBB26695"),
        name: "John Doe"
    )
    
    static let janeDoe = User(name: "Jane Doe")
}
