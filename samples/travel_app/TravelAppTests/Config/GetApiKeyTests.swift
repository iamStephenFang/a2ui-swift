// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `GetApiKey`.
///
/// Mirrors Flutter's `io_get_api_key.dart` logic:
/// env var → UserDefaults → hardcoded fallback.
final class GetApiKeyTests: XCTestCase {

    private let arkUserDefaultsKey = "arkAPIKey"
    private let geminiUserDefaultsKey = "geminiAPIKey"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: arkUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: geminiUserDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: arkUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: geminiUserDefaultsKey)
        super.tearDown()
    }

    func testResolveReturnsEmptyWhenNoKeyConfigured() {
        if ProcessInfo.processInfo.environment["ARK_API_KEY"] == nil {
            XCTAssertEqual(GetApiKey.resolve(provider: .ark), "")
        }
    }

    func testResolveUsesArkUserDefaultsWhenSet() {
        let customKey = "ark-test-api-key-12345"
        UserDefaults.standard.set(customKey, forKey: arkUserDefaultsKey)

        let key = GetApiKey.resolve(provider: .ark)
        XCTAssertEqual(key, customKey)
    }

    func testResolveUsesGeminiUserDefaultsWhenSet() {
        let customKey = "gemini-test-api-key-12345"
        UserDefaults.standard.set(customKey, forKey: geminiUserDefaultsKey)

        let key = GetApiKey.resolve(provider: .gemini)
        XCTAssertEqual(key, customKey)
    }

    func testResolveIgnoresEmptyUserDefaults() {
        UserDefaults.standard.set("   ", forKey: arkUserDefaultsKey)
        if ProcessInfo.processInfo.environment["ARK_API_KEY"] == nil {
            XCTAssertEqual(GetApiKey.resolve(provider: .ark), "")
        }
    }

    func testHasUserProvidedKeyFalseByDefault() {
        UserDefaults.standard.removeObject(forKey: arkUserDefaultsKey)
        if ProcessInfo.processInfo.environment["ARK_API_KEY"] == nil {
            XCTAssertFalse(GetApiKey.hasUserProvidedKey(provider: .ark))
        }
    }

    func testHasUserProvidedKeyTrueWhenStored() {
        UserDefaults.standard.set("my-key", forKey: arkUserDefaultsKey)
        XCTAssertTrue(GetApiKey.hasUserProvidedKey(provider: .ark))
    }
}
