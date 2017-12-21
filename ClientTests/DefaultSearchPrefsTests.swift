/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
@testable import Client
import UIKit

import XCTest

class DefaultSearchPrefsTests: XCTestCase {
    let searchPrefs = DefaultSearchPrefs(with: Bundle.main.resourceURL!.appendingPathComponent("SearchPlugins").appendingPathComponent("list.json"))!

    func testParsing() {
        let us = (lang: ["en-US", "en"], region: "US")
        XCTAssertEqual(searchPrefs.searchDefault(for: us.lang, and: us.region), "Google")
        XCTAssertEqual(searchPrefs.visibleDefaultEngines(for: us.lang, and: us.region), ["google-2018", "yahoo", "bing", "amazondotcom", "ddg", "twitter", "wikipedia"])

        let china = (lang: ["zn-hans-CN", "zn-CN", "zn"], region: "CN")
        XCTAssertEqual(searchPrefs.searchDefault(for: china.lang, and: china.region), "百度"")
        XCTAssertEqual(searchPrefs.visibleDefaultEngines(for: china.lang, and: china.region), ["google-2018", "yahoo", "bing", "amazondotcom", "ddg", "twitter", "wikipedia"])


        let chinaDefault = searchPrefs.searchDefault(for: ["zh-hans-CN", "zh-CN", "CN"], and: "CN")
        let chinaList = searchPrefs.visibleDefaultEngines(for: ["zh-hans-CN", "zh-CN", "CN"], and: "CN")

        let taiwanDefault = searchPrefs.searchDefault(for: ["zh-TW", "TW"], and: "TW")
        let taiwanList = searchPrefs.visibleDefaultEngines(for: ["zh-TW", "TW"], and: "TW")

        let spanishUSDefault = searchPrefs.searchDefault(for: ["es-US", "US"], and: "US")
        let spanishUSlist = searchPrefs.visibleDefaultEngines(for: ["es-US", "US"], and: "US")

        let britshDefault = searchPrefs.searchDefault(for: ["en-GB", "en"], and: "GB")
        let britishlist = searchPrefs.visibleDefaultEngines(for: ["en-GB", "en"], and: "GB")

        let russiaDefualt = searchPrefs.searchDefault(for: ["ru-RU", "ru"], and: "RU")
        let russiaList = searchPrefs.visibleDefaultEngines(for: ["ru-RU", "ru"], and: "RU")
    }
}

