//
//  SDDataSource.swift
//  NativeiOSIntegrations
//
//  Created by Porter McGary on 1/24/24.
//

import Foundation
import GatewayBasics
import SwiftData

public class SDDataSource<Model: PersistentModel>: MutableDataSource {
    public typealias MutablePayload = Model
    
    public func initialize() async throws {
        <#code#>
    }
    
    public func delete() async throws {
        <#code#>
    }
    
    public func insert(_ payload: Model) async throws {
        <#code#>
    }
    
    public func update(_ payload: Model) async throws {
        <#code#>
    }
    
    public func fetch(id: Model.ID) async -> Result<Model, Error> {
        <#code#>
    }
    
    public func fetch() async -> Result<[Model.ID : Model], Error> {
        <#code#>
    }
    
    public func remove(id: Model.ID) async throws {
        <#code#>
    }
    
    public func clear() async throws {
        <#code#>
    }
}
