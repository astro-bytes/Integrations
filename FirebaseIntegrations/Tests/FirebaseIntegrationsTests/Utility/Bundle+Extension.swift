//
//  Bundle+Extension.swift
//  FirebaseIntegrations
//
//  Created by Porter McGary on 1/24/24.
//

import Foundation

extension Bundle {
    static func configDictionary(_ name: String) -> [String: String] {
        guard let configURL = module.url(forResource: name, withExtension: "xcconfig") else {
            fatalError("Failed to find config file")
        }
        
        do {
            let contents = try String(contentsOf: configURL)
            let lines = contents.split(separator: "\n").map { $0.description }
            let dictionary = lines.reduce(into: [String: String]()) { partialResult, line in
                let components = line.split(separator: "=").map { $0.description }
                guard let key = components.first, !key.isEmpty, let value = components.last, !value.isEmpty else { return }
                partialResult[key] = value
            }
            return dictionary
        } catch {
            fatalError(String(describing: error))
        }
    }
    
    static var databaseURL: String {
        let configDictionary = Self.configDictionary("Package")
        guard let host = configDictionary["HOST_NAME"], let database = configDictionary["DATABASE"] else {
            fatalError("Failed to find database url in dictionary")
        }
        return "http://\(host)?ns=\(database)"
    }
}
