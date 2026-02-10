# efb_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## TODO

- [ ] **Document Viewer: Aircraft/folder selection not working on Flutter Web** — In `document_viewer_screen.dart`, tapping the aircraft or folder chip in the metadata bar to attach a document to an aircraft or move it to a folder does not work on Flutter Web. The bottom sheet either doesn't open or items don't respond to taps. Needs investigation — may be a Flutter Web gesture/overlay issue. Relevant files: `lib/features/documents/widgets/document_viewer_screen.dart`, `lib/features/documents/widgets/attach_aircraft_sheet.dart`.
