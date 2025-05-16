# AniMo

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

## Overview
AniMo is a Flutter application that connects farmers, buyers, and drivers in the agricultural supply chain.

## API Key Security
This project uses various API keys for services like Firebase and Google Maps. To secure these keys:

1. **Environment Configuration**
   - All API keys are stored in `lib/env_config.dart`
   - This file is added to `.gitignore` to prevent committing sensitive information
   - A sample template (`env_config.template.dart`) should be used for new installations

2. **Setting Up API Keys**
   When setting up the project for development or deployment:
   
   - Copy `env_config.template.dart` to `env_config.dart`
   - Fill in your API keys in the new file
   - Never commit the actual `env_config.dart` file to your repository

3. **Android Keys**
   - In the Android manifest, keys are referenced as `${MAPS_API_KEY}`
   - This variable is replaced during the build process
   - For local development, create a `local.properties` file in the android directory with:
     ```
     MAPS_API_KEY=your_api_key_here
     ```

4. **Web Keys**
   - Web API keys are loaded dynamically at runtime
   - The `EnvironmentService` class handles initialization

## Deployment
For deployment to platforms like Vercel or Firebase Hosting:

1. Make sure your environment variables are set correctly for each platform
2. Build the web app with `flutter build web --release`
3. Deploy using the platform's CLI or web interface

For Firebase Hosting:
```
firebase deploy --only hosting
```

## Considerations for CI/CD
When setting up continuous integration or deployment:

1. Securely store your API keys as environment variables in your CI/CD platform
2. Generate the `env_config.dart` file during the build process
3. Never include actual API keys in your repository
