//
//  FBDatabaseDataSourceTests.swift
//  FirebaseIntegrationTests
//
//  Created by Porter McGary on 1/21/24.
//

import Combine
import EntityBasics
@testable import FirebaseIntegrations
import FirebaseDatabase
import FirebaseCore
import Utility
import XCTest

final class FBDatabaseDataSourceTests: XCTestCase {
    static override func setUp() {
        let path = Bundle.module.path(forResource: "GoogleService-Info", ofType: "plist")
        guard let path else { fatalError("Url path failed") }
        guard let options = FirebaseOptions(contentsOfFile: path) else { fatalError("Failed to create firebase options") }
        FirebaseApp.configure(options: options)
    }
    
    var source: FBDatabaseDataSource<User>!
    var cancelBucket: Set<AnyCancellable>!
    
    var db: DatabaseReference {
        let url = Bundle.databaseURL
        let db = Database.database(url: url)
        let reference = db.reference()
        return reference
    }
    
    override func setUp() {
        source = FBDatabaseDataSource<User>(reference: db)
        cancelBucket = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        try await db.removeValue()
    }
    
    func test_Insert_InsertsSpecificValueWithID() async {
        let user = User.johnDoe
        do {
            try await source.insert(user)
        } catch {
            XCTFail(String(describing: error))
        }
        
        let result = await source.fetch(id: user.id)
        XCTAssertEqual(result.value, user)
        XCTAssertNil(result.error)
    }
    
    func test_FetchById_ReturnsSpecificValueWithID() async throws {
        try await source.insert(.johnDoe)
        
        let result = await source.fetch(id: User.johnDoe.id)
        
        XCTAssertEqual(result.value, .johnDoe)
        XCTAssertNil(result.error)
    }
    
    func test_FetchAll_ReturnsAllTableData() async throws {
        try await source.insert(.johnDoe)
        
        let result = await source.fetch()
        
        XCTAssertEqual(result.value?[User.johnDoe.id], .johnDoe)
        XCTAssertNil(result.error)
    }
    
    func test_Update_ChangesTheValueInDB() async throws {
        try await source.insert(.johnDoe)
        let newUser = User(id: .init(uuidString: User.johnDoe.id), name: "Fireman")
        
        try await source.update(newUser)
        let result = await source.fetch(id: newUser.id)
        
        XCTAssertEqual(result.value, newUser)
        XCTAssertNil(result.error)
    }
    
    func test_Delete_DeletesAllDBData() async throws {
        try await source.insert(.johnDoe)
        try await db.child("test-table").setValue("hello world")
        
        let initialResult = await source.fetch()
        
        XCTAssertEqual(initialResult.value?.isEmpty, false)
        XCTAssertNil(initialResult.error)
        
        do {
            try await source.delete()
        } catch {
            XCTFail(String(describing: error))
        }
        
        let testSnapshot = try await db.child("test-table").getData()
        XCTAssertFalse(testSnapshot.exists())
        let snapshot = try await db.child(User.tablename).getData()
        XCTAssertFalse(snapshot.exists())
    }
    
    func test_Clear_RemovesTableFromDB() async throws {
        try await source.insert(.johnDoe)
        try await db.child("test-table").setValue("hello world")
        
        let initialResult = await source.fetch()
        
        XCTAssertEqual(initialResult.value?.isEmpty, false)
        XCTAssertNil(initialResult.error)
        
        do {
            try await source.clear()
        } catch {
            XCTFail(String(describing: error))
        }
        
        let testSnapshot = try await db.child("test-table").getData()
        XCTAssertTrue(testSnapshot.exists())
        let snapshot = try await db.child(User.tablename).getData()
        XCTAssertFalse(snapshot.exists())
    }
    
    func test_RemoveById_RemovesElementWithID() async throws {
        let jane = User.janeDoe
        try await source.insert(.johnDoe)
        try await source.insert(jane)
        
        let initialResult = await source.fetch()
        
        XCTAssertEqual(initialResult.value?.isEmpty, false)
        XCTAssertNil(initialResult.error)
        
        do {
            try await source.remove(id: User.johnDoe.id)
        } catch {
            XCTFail(String(describing: error))
        }
        
        let johnResult = await source.fetch(id: User.johnDoe.id)
        XCTAssertNil(johnResult.value)
        XCTAssertNotNil(johnResult.error)
        
        let janeResult = await source.fetch(id: jane.id)
        XCTAssertEqual(janeResult.value, jane)
        XCTAssertNil(janeResult.error)
    }
    
    func test_Initialize_SetsUpPublishers() async throws {
        try await source.initialize()
        
        let snapshot = try await db.child(User.tablename).getData()
        XCTAssertFalse(snapshot.exists())
        
        let expectation = XCTestExpectation(description: "Initialize Publisher")
        let publisher = source!.publisher
        let cancellable = publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Publisher Finished Unexpectedly")
            case .failure(let error):
                XCTFail(String(describing: error))
            }
        } receiveValue: { value in
            expectation.fulfill()
        }
        
        try await source.insert(.johnDoe)
        
        await fulfillment(of: [expectation], timeout: 1)
        cancellable.cancel()
    }
    
    func test_TablePublisher_PublishesValuesOnInsert() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let publisher = source.publisher
        try await source.initialize()
        
        let expectation = XCTestExpectation(description: "Receive a value on publisher after inserting to DB")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Publisher Finished Unexpectedly")
            case .failure(let error):
                XCTFail(String(describing: error))
            }
        } receiveValue: { value in
            XCTAssertEqual(value[User.johnDoe.id], User.johnDoe)
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        try await source.insert(.johnDoe)
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_TablePublisher_PublishesValuesOnUpdate() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let publisher = source.publisher
        try await source.initialize()
        let updatedUser = User(id: User.johnDoe.uuid, name: "Test Name")
        try await source.insert(.johnDoe)
        
        let expectation = XCTestExpectation(description: "Receive a value on publisher after inserting to DB")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Publisher Finished Unexpectedly")
            case .failure(let error):
                XCTFail(String(describing: error))
            }
        } receiveValue: { value in
            XCTAssertEqual(value[updatedUser.id], updatedUser)
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        try await source.update(updatedUser)
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_TablePublisher_PublishesValuesOnRemove() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let publisher = source.publisher
        try await source.initialize()
        try await source.insert(.johnDoe)
        
        let expectation = XCTestExpectation(description: "Receive a value on publisher after inserting to DB")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Publisher Finished Unexpectedly")
            case .failure(let error):
                XCTFail(String(describing: error))
            }
        } receiveValue: { value in
            XCTAssertNil(value[User.johnDoe.id])
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        try await source.remove(id: User.johnDoe.id)
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_TablePublisher_PublishesCompleteWhenTableRemoved() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let publisher = source.publisher
        try await source.initialize()
        try await source.insert(.johnDoe)
        
        let expectation = XCTestExpectation(description: "Receive a value on publisher after inserting to DB")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTFail(String(describing: error))
            }
        } receiveValue: { value in
            XCTAssertTrue(value.isEmpty)
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        try await source.delete()
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_TablePublisher_PublishesCompleteWhenDatabaseCleared() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let publisher = source.publisher
        try await source.initialize()
        try await source.insert(.johnDoe)
        
        let expectation = XCTestExpectation(description: "Receive a value on publisher after inserting to DB")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTFail(String(describing: error))
            }
        } receiveValue: { value in
            XCTAssertTrue(value.isEmpty)
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        try await source.clear()
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_ValuePublisher_PublishesPullsCurrentValueOnSubscription() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let userId = User.johnDoe.id
        let publisher = source.publisherForValue(with: userId)
        
        try await source.insert(.johnDoe)
        let expectation = XCTestExpectation(description: "Receive value")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTAssertEqual(error.toEquatableError(), CoreError.notFound.toEquatableError(), "Initially there is no value found")
            }
        } receiveValue: { value in
            XCTAssertEqual(value, .johnDoe)
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        await fulfillment(of: [expectation], timeout: 2)
    }
    
    func test_ValuePublisher_PublishesNewValueOnInsert() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let userId = User.johnDoe.id
        let publisher = source.publisherForValue(with: userId)
        
        let expectation = XCTestExpectation(description: "Receive value")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTAssertEqual(error.toEquatableError(), CoreError.notFound.toEquatableError())
            }
        } receiveValue: { value in
            XCTAssertEqual(value, .johnDoe)
            expectation.fulfill()
        }
        .store(in: &cancelBucket)
        
        try await source.insert(.johnDoe)
        await fulfillment(of: [expectation], timeout: 2)
    }
    
    func test_ValuePublisher_CompletesWithErrorOnRemoveWithID() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let userId = User.johnDoe.id
        let publisher = source.publisherForValue(with: userId)
        
        try await source.insert(.johnDoe)
        let expectation = XCTestExpectation(description: "Receive value")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTAssertEqual(error.toEquatableError(), CoreError.notFound.toEquatableError())
                expectation.fulfill()
            }
        } receiveValue: { value in
            XCTAssertEqual(value, .johnDoe)
        }
        .store(in: &cancelBucket)
        
        try await source.remove(id: User.johnDoe.id)
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_ValuePublisher_CompletesWithErrorOnTableDelete() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let userId = User.johnDoe.id
        let publisher = source.publisherForValue(with: userId)
        
        try await source.insert(.johnDoe)
        let expectation = XCTestExpectation(description: "Receive value")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTAssertEqual(error.toEquatableError(), CoreError.notFound.toEquatableError())
                expectation.fulfill()
            }
        } receiveValue: { value in
            XCTAssertEqual(value, .johnDoe)
        }
        .store(in: &cancelBucket)
        
        try await source.delete()
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    func test_ValuePublisher_CompletesWithErrorOnDatabaseClear() async throws {
        let source = FBDatabaseDataSource<User>(reference: db)
        let userId = User.johnDoe.id
        let publisher = source.publisherForValue(with: userId)
        
        try await source.insert(.johnDoe)
        let expectation = XCTestExpectation(description: "Receive value")
        
        publisher.sink { state in
            switch state {
            case .finished:
                XCTFail("Unexpected End of Stream")
            case .failure(let error):
                XCTAssertEqual(error.toEquatableError(), CoreError.notFound.toEquatableError())
                expectation.fulfill()
            }
        } receiveValue: { value in
            XCTAssertEqual(value, .johnDoe)
        }
        .store(in: &cancelBucket)
        
        try await source.clear()
        await fulfillment(of: [expectation], timeout: 1)
    }
}

