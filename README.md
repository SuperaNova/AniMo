# animo

AniMo App

## Purpose

AniMo is a mobile app aimed at reducing food loss and waste by connecting smallholder farmers in Cebu to nearby buyers (markets, NGOs, community kitchens) through a decentralized delivery network. In the Philippines, agriculture is vital (10.18% of GDP in 2020) , yet an estimated 30% of produce is wasted due to poor logistics . AniMo's mission is to empower farmers, boost incomes, and improve food security by matching surplus harvests to urgent local demand. Using AI (Google's Gemini/Gemma models), AniMo's hero feature recommends optimal supply-demand pairings – prioritizing highly perishable crops and nearby buyers. For example, high-value crops in the Philippines suffer 20–40% post-harvest losses without proper handling . By quickly routing these surpluses to community kitchens or markets, AniMo can significantly cut waste. (Notably, the Philippine Dept. of Trade reported that a similar digital marketplace doubled farmer incomes and slashed waste from 50% to 5% in its pilot .) Overall, AniMo delivers social impact by feeding communities and raising rural incomes while aligning with national goals to reduce food insecurity.

## Main Functionalities

*   **User Authentication:** Secure sign-up and login for farmers, buyers, and drivers.
*   **Farmer Portal:**
    *   List surplus produce with details (type, quantity, price, perishability).
    *   Manage inventory of listed items.
    *   Receive and manage AI-powered match suggestions with nearby buyers.
    *   Track order status and history.
*   **Buyer Portal:**
    *   Search and browse available produce listings from local farmers.
    *   Place orders for desired produce.
    *   Receive and manage AI-powered match suggestions for available surplus.
    *   Track order status and history.
*   **Driver Module:**
    *   View available delivery tasks based on location and capacity.
    *   Accept and manage delivery assignments.
    *   Utilize in-app navigation (leveraging Google Maps) for optimal routing.
    *   Update delivery status.
*   **AI-Powered Matching:**
    *   Intelligent recommendation engine (using Google's Gemini/Gemma models) to pair farmers' surplus with buyer demand, prioritizing perishable goods and proximity.
*   **Real-time Notifications:** Updates for order confirmations, matches, delivery status, etc.
*   **Location-based Services:**
    *   Map-based visualization of produce, farmers, and buyers.
    *   Address selection and geocoding for pickup and delivery locations.

## Google Developer Technologies Used

*   **Flutter:** For building a cross-platform (iOS and Android) mobile application from a single codebase.
*   **Firebase:**
    *   **Authentication:** Secure user sign-in and identity management.
    *   **Cloud Firestore:** NoSQL database for storing app data (user profiles, produce listings, orders, etc.).
    *   **Firebase Storage:** For storing user-generated content like produce images.
    *   **Cloud Functions (Potentially):** For backend logic and AI model integration.
*   **Google AI (Gemini/Gemma Models):** For the core feature of recommending optimal supply-demand pairings.
*   **Google Maps Platform:**
    *   **Maps SDK:** For displaying maps within the application.
    *   **Geocoding API:** To convert addresses to geographic coordinates and vice-versa.
    *   **Routes API:** To calculate optimal delivery routes for drivers.

## Team: IntelliJays

*   Jared Sheohn Acebes
*   James Ewican
*   Jamiel Kyne Pinca
*   Jervin Ryle Milleza

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
