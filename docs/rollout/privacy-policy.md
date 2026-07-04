# WorkspaceContacts — Privacy Policy

_Last updated: 2026-07-04. Publish this at a stable URL (e.g. imeto.com/workspacecontacts-privacy)
and enter that URL in App Store Connect. Have Imeto review the wording before publishing._

WorkspaceContacts ("the app") is an internal Imeto app that shows your Imeto colleagues' names on
incoming calls and lets you call them by name. This policy explains what it does with data.

## Who controls the data

Imeto is the data controller. Contact: privacy@imeto.com. _(Confirm the right contact address.)_

## What the app accesses

- **Your Imeto Google account**, to sign you in. Sign-in is restricted to `@imeto.com` accounts.
- **Your organization's Google Workspace directory**, read-only (Google People API,
  `directory.readonly` scope): colleague names, job titles, email addresses, and phone numbers,
  only where your organization has populated them and chosen to share them.
- **Your device Contacts**, to add and maintain colleague entries so caller ID works.

## What the app does with it

- Colleague directory entries are written to your device's address book, in a dedicated
  "Imeto Directory" contact group, and kept in sync.
- A local map linking each directory person to the contact it created is stored on your device
  (in app preferences) so the app can update and remove exactly the contacts it made.
- The app refreshes this in the background so caller ID stays current.

## What the app does NOT do

- It has **no server or backend**. Your data is not sent to Imeto or to any third party beyond
  Google (which provides your own organization's directory and the sign-in service).
- It contains **no analytics, advertising, or tracking**. Nothing is used to track you across
  apps or websites.

## Where your contacts live (important)

Contacts the app creates land in your **real device address book**. If you have iCloud Contacts
enabled, iOS may sync them to iCloud and your other Apple devices. iOS provides no way for an app
to wall these off on-device. You can remove them at any time:

- In the app: **⋯ menu → "Remove all synced contacts."**
- Signing out of the app also removes them.

Note that removing the app alone does not delete contacts that have already synced to iCloud —
use "Remove all synced contacts" or sign out first.

## Data retention

The app keeps directory-derived contacts on your device only while you are signed in and syncing.
Remove-all or sign-out deletes them. The local sync map is deleted when you sign out.

## Your choices

Signing in and enabling sync is entirely optional and requires your explicit consent in the app.
You can revoke Contacts access at any time in **Settings → WorkspaceContacts → Contacts**, and
remove all synced data as described above.

## Changes

We will update this policy as the app changes and revise the "Last updated" date above.
