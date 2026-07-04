// Core/Tests/WorkspaceContactsCoreTests/PeopleAPIDecodingTests.swift
import Testing
import Foundation
@testable import WorkspaceContactsCore

@Suite struct PeopleAPIDecodingTests {
    private let json = """
    {
      "people": [
        {
          "resourceName": "people/c1",
          "etag": "etag-1",
          "names": [
            {"displayName": "Jane Doe", "givenName": "Jane", "familyName": "Doe", "metadata": {"primary": true}}
          ],
          "emailAddresses": [
            {"value": "jane@imeto.com", "metadata": {"primary": true}},
            {"value": "j.doe@imeto.com"}
          ],
          "phoneNumbers": [
            {"value": "+46701234567", "type": "mobile"}
          ],
          "organizations": [
            {"title": "Consultant", "department": "Engineering", "metadata": {"primary": true}}
          ],
          "photos": [
            {"url": "https://example.com/jane.jpg", "metadata": {"primary": true}}
          ]
        },
        {
          "resourceName": "people/c2",
          "names": [{"displayName": "No Phone Person"}],
          "emailAddresses": [{"value": "nophone@imeto.com"}]
        }
      ],
      "nextPageToken": "page-2",
      "nextSyncToken": "sync-abc"
    }
    """.data(using: .utf8)!

    @Test func decodesPeopleAndTokens() throws {
        let response = try ListDirectoryPeopleResponse.decode(json)

        #expect(response.nextPageToken == "page-2")
        #expect(response.nextSyncToken == "sync-abc")
        #expect(response.people.count == 2)

        let jane = response.people[0]
        #expect(jane.resourceName == "people/c1")
        #expect(jane.etag == "etag-1")
        #expect(jane.displayName == "Jane Doe")
        #expect(jane.givenName == "Jane")
        #expect(jane.familyName == "Doe")
        #expect(jane.emails == ["jane@imeto.com", "j.doe@imeto.com"])
        #expect(jane.phoneNumbers == ["+46701234567"])
        #expect(jane.organizationTitle == "Consultant")
        #expect(jane.department == "Engineering")
        #expect(jane.photoURL == "https://example.com/jane.jpg")

        let second = response.people[1]
        #expect(second.displayName == "No Phone Person")
        #expect(second.phoneNumbers.isEmpty)
        #expect(second.organizationTitle == nil)
    }

    @Test func missingDisplayNameFallsBackToEmpty() throws {
        let data = """
        {"people": [{"resourceName": "people/c3"}]}
        """.data(using: .utf8)!
        let response = try ListDirectoryPeopleResponse.decode(data)
        #expect(response.people[0].displayName == "")
    }
}
