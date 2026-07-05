# WorkspaceContacts — launch kit

Collateral for driving colleague adoption of the TestFlight beta. Edit voice/channel to taste.
Companion to [`onboarding.md`](onboarding.md) (the invite itself) and
[`privacy-policy.md`](privacy-policy.md).

---

## Teaser announcement (post before the beta is live — build the list)

> **📱 Coming soon: never wonder who's calling you from an Imeto number again**
>
> I've built a small internal iPhone app, **WorkspaceContacts**. It puts our team directory into
> your iPhone Contacts, so when a colleague calls you see their **name** — and you can call anyone
> on the team by typing their name in the Phone app.
>
> It's opt-in, it only reads our own Imeto directory (sign-in is `@imeto.com` only), and you can
> wipe everything it added with one tap anytime.
>
> **Want in on the beta?** React 👍 / reply here and I'll send you a TestFlight invite the moment
> it's ready. Looking for a few early testers first — especially if you get a lot of calls from
> numbers you don't recognize.

## Beta-live announcement (when the TestFlight invite goes out)

> **📱 WorkspaceContacts beta is live — see colleague names on incoming calls**
>
> Your TestFlight invite is in your inbox. Setup is ~2 minutes: install TestFlight → open the
> invite → sign in with your `@imeto.com` account → tap **Enable & sync**. Done — colleagues now
> show up on incoming calls and you can call them by name.
>
> Full steps and what to expect: [onboarding note link]. Hit a snag? Reply here.

---

## FAQ (the trust questions that decide adoption)

**Will this mess up my existing contacts?**
No. It adds colleagues into a separate "Imeto Directory" group and only ever touches the entries it
created. Your own contacts are untouched.

**Will these contacts sync to iCloud / show on my other Apple devices?**
They may — they go into your real address book, and iOS gives apps no way to keep them on one
device only. If that's not what you want, you can remove them any time (below). We tell you this up
front on purpose.

**How do I remove them?**
In the app: **⋯ menu → "Remove all synced contacts."** Signing out also removes them. (Deleting the
app alone won't clean up contacts already synced to iCloud — remove or sign out first.)

**Who can see the data / where does it go?**
Nowhere new. The app has no server and no analytics. It reads *our own* Google Workspace directory
(the same colleagues you can already look up) and writes to *your* phone. Nothing is sent to me or
any third party.

**Do I have to keep it running / will it drain my battery?**
No babysitting. It refreshes quietly in the background so new colleagues and number changes appear
automatically. No noticeable battery impact.

**Is my account safe?**
Sign-in is standard Google Sign-In, restricted to `@imeto.com`. The app can only *read* the
directory — it can't change anything in Workspace.

---

## Running the beta (checklist)

- [ ] Line up 3–5 **champions** (heavy call-takers: sales / ops / leadership / support).
- [ ] Post the **teaser** in [channel] and start the interest list (reactions/replies or a form).
- [ ] Decide tester type: **internal** (≤100, must be App Store Connect users, no review, instant)
      vs **external** (email or public link, up to 10k, one-time light beta review).
- [ ] Once the build is uploaded: invite champions first, gather feedback for a few days.
- [ ] Have a champion confirm the payoff on a **real device**: an incoming call shows the caller's
      name. (This is also the project's Stage 6 end-to-end proof.)
- [ ] Capture a short **demo clip** from that real-device moment → attach to the wider rollout post.
- [ ] Widen: post the **beta-live** announcement + onboarding note to the interest list.

## Demo clip shot-list (record on a real device once live)

1. Open app → **Sign in with Google** (`@imeto.com`).
2. Colleague list appears; tap **Enable & sync** → **Allow** Contacts.
3. Open **Phone → Contacts**, search a colleague by name — they're there.
4. **The money shot:** have someone call; the incoming-call screen shows their **name**, not a
   number. (Only filmable on a real device — this is the whole point of the app.)

Keep it ~30 seconds, no narration needed; the name-on-the-call-screen sells itself.
