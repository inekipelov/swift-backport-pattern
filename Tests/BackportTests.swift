import XCTest
import Foundation
@testable import Backport

#if canImport(SwiftUI)
import SwiftUI
#endif

private struct ExampleValue {
    let title: String
}

private final class ExampleObject: NSObject {
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
        super.init()
    }
}

private extension Backport where Content == ExampleValue {
    var normalizedTitle: String {
        content.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private extension Backport where Content: ExampleObject {
    var debugIdentifier: String {
        "object::\(content.identifier)"
    }
}

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private extension Backport where Content: View {
    func eraseToAnyView() -> AnyView {
        AnyView(content)
    }
}
#endif

/// Comprehensive tests for the Backport framework.
///
/// This test class covers all three main components:
/// - Backport struct (generic wrapper)
/// - NSObjectProtocol extension
/// - SwiftUI View extension (when available)
final class BackportTests: XCTestCase {
    
    // MARK: - Backport struct tests
    
    /// Tests the basic initialization and content access of Backport struct.
    func testBackportInitialization() {
        let testString = "Hello, World!"
        let backport = Backport(testString)
        
        XCTAssertEqual(backport.content, testString)
    }
    
    /// Tests that Backport can wrap different types correctly.
    func testBackportWithDifferentTypes() {
        // Test with Int
        let intBackport = Backport(123)
        XCTAssertEqual(intBackport.content, 123)
        
        // Test with Array
        let arrayBackport = Backport([1, 2, 3])
        XCTAssertEqual(arrayBackport.content, [1, 2, 3])
        
        // Test with Dictionary
        let dictBackport = Backport(["key": "value"])
        XCTAssertEqual(dictBackport.content, ["key": "value"])
    }
    
    /// Tests nested property access through explicit `content`.
    func testBackportNestedPropertyAccessThroughContent() {
        struct Address {
            let street: String
            let city: String
        }
        
        struct Person {
            let name: String
            let address: Address
        }
        
        let person = Person(
            name: "John Doe",
            address: Address(street: "123 Main St", city: "Anytown")
        )
        let backport = Backport(person)
        
        XCTAssertEqual(backport.content.name, "John Doe")
        XCTAssertEqual(backport.content.address.street, "123 Main St")
        XCTAssertEqual(backport.content.address.city, "Anytown")
    }

    /// Tests that consumers can add custom backport APIs for plain Swift types.
    func testCustomBackportExtensionForValueType() {
        let value = ExampleValue(title: "  Hello Backport  ")

        XCTAssertEqual(Backport(value).normalizedTitle, "hello backport")
    }
    
    // MARK: - NSObjectProtocol extension tests
    
    /// Tests that NSObject instances can access backport property.
    func testNSObjectBackportProperty() {
        let nsObject = NSObject()
        let backport = nsObject.backport
        
        XCTAssertIdentical(backport.content, nsObject)
    }
    
    /// Tests backport functionality with UIKit/AppKit objects.
    func testFoundationObjectBackport() {
        let string = NSString(string: "Test String")
        let backport = string.backport
        
        XCTAssertEqual(backport.content as NSString, string)
        XCTAssertEqual(backport.content.length, string.length)
    }
    
    /// Tests backport with NSArray.
    func testNSArrayBackport() {
        let array = NSArray(array: ["item1", "item2", "item3"])
        let backport = array.backport
        
        XCTAssertEqual(backport.content, array)
        XCTAssertEqual(backport.content.count, 3)
    }
    
    /// Tests backport with NSDictionary.
    func testNSDictionaryBackport() {
        let dictionary = NSDictionary(dictionary: ["key1": "value1", "key2": "value2"])
        let backport = dictionary.backport
        
        XCTAssertEqual(backport.content, dictionary)
        XCTAssertEqual(backport.content.count, 2)
    }
    
    /// Tests backport with NSNumber.
    func testNSNumberBackport() {
        let number = NSNumber(value: 42)
        let backport = number.backport
        
        XCTAssertEqual(backport.content, number)
        XCTAssertEqual(backport.content.intValue, 42)
    }

    /// Tests that custom backport APIs are available through NSObjectProtocol `.backport`.
    func testCustomBackportExtensionForNSObjectType() {
        let object = ExampleObject(identifier: "sample")

        XCTAssertEqual(object.backport.debugIdentifier, "object::sample")
    }
    
    // MARK: - SwiftUI View extension tests
    
    #if canImport(SwiftUI)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testSwiftUIViewBackportProperty() {
        let text = Text("Hello, SwiftUI!")
        let backport = text.backport
        
        // We can't easily test Text content equality, but we can verify the backport wrapper
        XCTAssertTrue(type(of: backport.content) == Text.self)
    }
    
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testSwiftUIViewBackportWithVStack() {
        let vstack = VStack {
            Text("Line 1")
            Text("Line 2")
        }
        let backport = vstack.backport
        
        XCTAssertTrue(type(of: backport.content) == VStack<TupleView<(Text, Text)>>.self)
    }
    
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testSwiftUIViewBackportWithModifier() {
        let modifiedText = Text("Modified Text")
            .font(.title)
            .foregroundColor(.blue)
        let backport = modifiedText.backport
        
        // Verify that the backport wrapper can be created for modified views
        XCTAssertNotNil(backport.content)
    }

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func testCustomBackportExtensionForSwiftUIView() {
        let erasedView = Text("Backport").backport.eraseToAnyView()

        XCTAssertTrue(type(of: erasedView) == AnyView.self)
    }
    #endif
    
    // MARK: - Integration tests
    
    /// Tests that backport can be chained and used in complex scenarios.
    func testBackportIntegration() {
        class TestClass: NSObject {
            let identifier: String
            let value: Int
            
            init(identifier: String, value: Int) {
                self.identifier = identifier
                self.value = value
                super.init()
            }
        }
        
        let testObject = TestClass(identifier: "test", value: 100)
        let backport = testObject.backport
        
        // Test that we can access custom properties through explicit `content`
        XCTAssertEqual(backport.content.identifier, "test")
        XCTAssertEqual(backport.content.value, 100)
        XCTAssertIdentical(backport.content, testObject)
    }
    
    /// Tests type safety of the Backport wrapper.
    func testBackportTypeSafety() {
        let stringBackport = Backport("string")
        let intBackport = Backport(42)
        
        // Ensure that the types are preserved correctly
        XCTAssertTrue(type(of: stringBackport.content) == String.self)
        XCTAssertTrue(type(of: intBackport.content) == Int.self)
    }
    
    /// Tests performance of repeated `content` property access.
    func testBackportPerformance() {
        struct LargeStruct {
            let property1: String
            let property2: String
            let property3: String
            let property4: String
            let property5: String
        }
        
        let largeStruct = LargeStruct(
            property1: "value1",
            property2: "value2",
            property3: "value3",
            property4: "value4",
            property5: "value5"
        )
        let backport = Backport(largeStruct)
        
        measure {
            for _ in 0..<1000 {
                _ = backport.content.property1
                _ = backport.content.property2
                _ = backport.content.property3
                _ = backport.content.property4
                _ = backport.content.property5
            }
        }
    }
    
    // MARK: - Edge cases
    
    /// Tests backport with nil values where applicable.
    func testBackportWithOptionals() {
        struct OptionalStruct {
            let optionalString: String?
            let optionalInt: Int?
        }
        
        let optionalStruct = OptionalStruct(optionalString: nil, optionalInt: 42)
        let backport = Backport(optionalStruct)
        
        XCTAssertNil(backport.content.optionalString)
        XCTAssertEqual(backport.content.optionalInt, 42)
    }
    
    /// Tests backport with empty collections.
    func testBackportWithEmptyCollections() {
        let emptyArray: [String] = []
        let emptyDict: [String: String] = [:]
        
        let arrayBackport = Backport(emptyArray)
        let dictBackport = Backport(emptyDict)
        
        XCTAssertTrue(arrayBackport.content.isEmpty)
        XCTAssertTrue(dictBackport.content.isEmpty)
    }
}
