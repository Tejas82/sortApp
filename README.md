# Sortapp

**See it. Sort it.** Sortapp reads school and club emails and turns them into one-tap actions for busy parents: add to calendar, draft a reply, or remember to do it.

This is the Android-first working prototype from the PRD: Gmail in, an LLM for extraction, Google Calendar out. There is no backend yet; the app calls Gmail, Calendar and OpenAI directly from the phone.

## What it does

- **Connect Gmail** (read-only) and backfill the last 30 days of school and club emails, found by keyword or by the senders you list.
- **Extract actions** with OpenAI: events, deadlines, replies, payments and things to prepare, each tagged to a child, with a confidence flag.
- **Action feed** grouped Overdue / Today / Next 7 days / Later / No date.
- **Add to calendar** after checking and editing the details. Calendar permission is asked for only the first time. Events get a popup reminder the day before (and one hour before for timed events).
- **Draft a reply** into the original Gmail thread. Nothing is sent: you review and send it from Gmail.
- **Snooze, mark done, or "This isn't right"** on every card; swipe left to mark done.
- **Paste a message** to try Sortapp with no Google access at all.
- **Privacy:** only extracted actions are stored on the phone, never email bodies. Settings has "Delete all Sortapp data".

## Run it

You need Flutter 3.27 or newer, Android Studio (or the Android SDK) and an Android phone or emulator with Google Play services.

```bash
git clone https://github.com/Tejas82/sortapp.git
cd sortapp
./tool/bootstrap.sh          # creates android/, fetches packages, analyzes, runs tests, prints your debug SHA-1
flutter run --dart-define=OPENAI_API_KEY=sk-...
```

You can also leave out the `--dart-define` and paste the key in the app's Settings.

## Install on a phone without building

Every push to `main` builds a signed APK with GitHub Actions and publishes it under [Releases](https://github.com/Tejas82/sortApp/releases/latest). Open that page on your Android phone, tap the `.apk`, and allow your browser to install unknown apps.

## Google Cloud setup (one time, about 10 minutes)

Google sign-in on Android works only once an OAuth client matches the app's package name and signing key.

1. Go to the [Google Cloud console](https://console.cloud.google.com/) and create a project, e.g. "Sortapp".
2. **APIs & Services → Library:** enable **Gmail API** and **Google Calendar API**.
3. **OAuth consent screen:** choose *External*, fill in the app name and your email, and add these scopes:
   - `https://www.googleapis.com/auth/gmail.readonly`
   - `https://www.googleapis.com/auth/gmail.compose`
   - `https://www.googleapis.com/auth/calendar.events`
   Leave it in **Testing** and add your Google account (and any beta parents) under **Test users**.
4. **Credentials → Create credentials → OAuth client ID → Android:**
   - Package name: `app.sortapp.sortapp`
   - SHA-1: `99:7F:AE:21:E3:5A:B9:0C:B7:2A:5E:79:68:00:9E:A4:84:5B:57:AF`
     (every build, local and CI, is signed with the shared prototype key in `tool/sortapp-debug.keystore`; replace it with a private key before any public release)
5. Run the app and tap **Connect Gmail**. No `google-services.json` is needed.

The Gmail scopes are *restricted*. Testing mode allows up to 100 test users; a public launch needs Google's OAuth verification and a security assessment (see the PRD's risks).

## Project layout

```
lib/
  main.dart                 App, theme, routing (onboarding or feed)
  app_state.dart            State: sync, extraction, actions, settings
  core/                     Pure Dart, unit tested
    email_parsing.dart      Gmail query, MIME body extraction, reply drafts
    extraction.dart         LLM prompt and JSON parsing/validation
    urgency.dart            Buckets and sorting
    format.dart             Date and sender formatting
  models/                   ActionItem, AppSettings
  services/
    google_service.dart     Google sign-in, Gmail, Calendar
    llm_service.dart        OpenAI Chat Completions
    storage_service.dart    On-device storage
  screens/                  Onboarding, feed, paste, settings
  widgets/                  Action card, edit-before-add sheet
test/                       Unit tests for core/ and models/
tool/bootstrap.sh           Generates android/ and checks the build
```

## Prototype limits and next steps

- **The OpenAI key lives on the phone.** Fine for testing; production should call the LLM through a backend.
- **Sync is manual** (pull to refresh or the refresh button). Background sync and push notifications need the backend from the PRD.
- **Reminders are Calendar reminders**, not app notifications.
- **WhatsApp isn't read.** Its Business API can't read a person's own chats; use Paste for now.
- The model defaults to `gpt-4o-mini` and can be changed in Settings.
