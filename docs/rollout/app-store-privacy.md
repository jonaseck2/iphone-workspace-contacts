# App Store Connect — App Privacy answers

Copy-paste answers for the **App Privacy** section in App Store Connect (also shown on the
TestFlight listing). Rationale included so you can defend each answer; adjust if Imeto's legal
review disagrees.

## Tracking

- **Do you use data to track users?** → **No.** No advertising, no cross-app/website tracking,
  no data brokers. (Matches `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`.)

## Data collection

Apple defines "collect" as transmitting data off-device other than for the listed exceptions.
This app has **no developer backend**: directory data is fetched from the user's *own* Google
Workspace and written to the on-device address book; nothing is sent to Imeto.

- **Does your app collect data?** → **No** — for data collected *by the developer*.

  The one nuance: the app uses the **Google Sign-In SDK**, which contacts Google to authenticate
  and may collect account identifiers / diagnostics on Google's side. If App Store review pushes
  back on "No," switch to **Yes** and declare the minimum below (this is the conservative
  fallback, tied to the SDK rather than to app features):

  | Data type | Linked to identity | Used for tracking | Purpose |
  |---|---|---|---|
  | Email address | Yes | No | App Functionality (sign-in) |
  | User ID | Yes | No | App Functionality (sign-in) |

  Do **not** declare the colleague directory (names/phones/emails) as "collected" — it is read
  from the org directory and stored on-device, not gathered by the developer.

## Privacy manifest (already in the build)

`app/Sources/PrivacyInfo.xcprivacy` declares:
- `NSPrivacyTracking = false`, no tracking domains, no collected data types.
- Required-reason API: **UserDefaults**, reason **CA92.1** (info accessible only to the app
  itself) — for `SyncStore`'s `resourceName → contactIdentifier` map.

GoogleSignIn (SPM, 9.x) ships its **own** privacy manifest, so its API-reason and data
declarations are covered by the SDK — you do not restate them here.

## Privacy policy URL

Required. Host [`privacy-policy.md`](privacy-policy.md) at a stable URL and enter it in the
App Privacy section and (for external testing) the TestFlight test information.

## Age rating / content

No objectionable content; standard 4+ rating. Answer all content questions "None."
