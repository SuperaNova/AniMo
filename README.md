# animo

AniMo App

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

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

For Vercel:
```
vercel
```

## Considerations for CI/CD
When setting up continuous integration or deployment:

1. Securely store your API keys as environment variables in your CI/CD platform
2. Generate the `env_config.dart` file during the build process
3. Never include actual API keys in your repository
