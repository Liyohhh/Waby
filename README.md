# Waby

Waby is a smart baby car seat safety system built as a final-year BIT project. An ESP32 seat module reads sensors (weight, buckle, temperature, GPS) over Wi-Fi and sends live data to Supabase. The Flutter app lets caregivers monitor seat status, manage family members, and receive escalating alerts when a child may be at risk.

The stack is Flutter (Dart) on mobile, Supabase for auth and realtime data, and ESP32 firmware for on-seat sensing and local alarms. Data is scoped per family — users create or join a family after sign-up before they can read or write anything.

This repo was originally named `seatcare_app`; user-facing branding is **Waby** throughout the app.
