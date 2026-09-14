# ⚡ Smart Energy Meter

A smart energy monitoring mobile application built with **Flutter**, **Firebase Realtime Database**, and **ESP32** for real-time electricity monitoring and analytics.

## 🚀 Overview

Smart Energy Meter is an IoT-based mobile application designed to monitor electrical energy data in real time.

The system combines an **ESP32** device with **Firebase Realtime Database** to collect and synchronize energy readings, while the Flutter mobile application provides a clean dashboard and analytics interface for users to monitor energy consumption.

## ✨ Features

* ⚡ Real-time energy monitoring
* 📊 Interactive dashboard
* 📈 Energy analytics screen
* 🔄 Firebase Realtime Database integration
* 📱 Responsive Flutter mobile UI
* 🧩 Reusable Energy Card widget
* 🧭 Bottom navigation interface
* 🌐 IoT communication using ESP32

## 🛠️ Technology Stack

### Mobile Application

* Flutter
* Dart

### Backend / Cloud

* Firebase Realtime Database
* Firebase Core

### IoT

* ESP32

### Development Tools

* Git
* GitHub
* Android Studio
* VS Code

## 📁 Project Structure

```text
smart-energy-meter/
│
├── android/
├── ios/
├── lib/
│   │
│   ├── screens/
│   │   ├── analytics_screen.dart
│   │   ├── dashboard_screen.dart
│   │   └── main_navigation_screen.dart
│   │
│   ├── services/
│   │   └── firebase_service.dart
│   │
│   ├── widgets/
│   │   └── energy_card.dart
│   │
│   ├── firebase_options.dart
│   └── main.dart
│
├── test/
├── web/
├── windows/
├── linux/
├── macos/
├── pubspec.yaml
├── firebase.json
└── README.md
```

## 📱 Application Screens

### Dashboard

The dashboard provides an overview of the latest energy monitoring information using reusable energy cards.

### Analytics

The analytics screen is designed to visualize and analyze energy consumption data retrieved from Firebase.

### Navigation

The application uses a dedicated main navigation screen to switch between dashboard and analytics sections seamlessly.

## 🔥 Firebase Integration

Firebase Realtime Database is used as the cloud data source for synchronizing smart energy meter readings with the mobile application.

The Firebase service layer is implemented inside:

```text
lib/services/firebase_service.dart
```

This keeps Firebase communication separated from the UI for better code organization.

## 🧩 Reusable Widget

The project includes a reusable widget for displaying energy information.

```text
lib/widgets/energy_card.dart
```

This component is used to create consistent energy data cards across the application interface.

## ⚙️ Getting Started

### Prerequisites

Make sure you have installed:

* Flutter SDK
* Dart SDK
* Android Studio or VS Code
* Git

### 1. Clone the Repository

```bash
git clone https://github.com/Shashinka26/smart-energy-meter.git
cd smart-energy-meter
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Make sure Firebase is configured correctly for your environment.

The project already contains:

```text
firebase_options.dart
firebase.json
```

Use your own Firebase project configuration if required.

### 4. Run the Application

```bash
flutter run
```

## 📊 Architecture

The application follows a simple layered structure.

```text
ESP32 Device
      │
      ▼
Firebase Realtime Database
      │
      ▼
Firebase Service
      │
      ▼
Flutter Screens
      │
      ├── Dashboard
      ├── Analytics
      └── Navigation
```

## 🎯 Future Improvements

* 🔔 Energy usage notifications
* 📅 Historical consumption reports
* 📉 Advanced analytics and charts
* 👤 User authentication
* 🌙 Dark mode improvements
* ⚡ Multiple smart meter support

## 🤝 Contributing

Contributions, suggestions, and improvements are welcome.

Feel free to fork this repository and submit a pull request.

## 👨‍💻 Author

**Chamidu Shashinka Rathnasiri**

Software Developer

* GitHub: https://github.com/Shashinka26
* LinkedIn: https://www.linkedin.com/in/chamidu-shashinka-947709361

---


