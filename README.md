# Translation Circuit

A Flutter client for a bidirectional speech interpretation system using Google Cloud Platform.

## Features

- Real-time bidirectional speech translation and interpretation to facilitate a conversation between two people that don't speak the same language
- Supports 100+ languages
- Cross-platform: Android and iOS

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install).
- My [fork](https://github.com/critt/transcription_service) of [this repo](saharmor/realtime-transcription-playground), which serves as the server for this client. This client does not interact with GCP directly.
- GCP account with [Cloud Speech-to-Text API](https://cloud.google.com/speech-to-text/?hl=en), [Cloud Translation API](https://cloud.google.com/translate?hl=en), a service account, and a JSON credentials file for the service account.
    - These are actually prerequisites for the server (the fork mentioned above), not the client (this repo). I'm listing them here so you know what you are in for from the start, as these GCP services aren't necessarily free. The backend repo has more information on its own installation and setup. Just make sure to enable the translation API in GCP in addition to the Speech-to-Text API.

<img src="screenshots/android3.png" alt="Android Screenshot" width="300"/>
