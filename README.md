
# 🚐 VanBond — Nomadic Dating, Community & Builder Marketplace

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![RevenueCat](https://img.shields.io/badge/RevenueCat-In--App%20Purchases-E75243)](https://www.revenuecat.com)
[![Google Play](https://img.shields.io/badge/Google%20Play-Live-brightgreen)](https://play.google.com/store/apps/details?id=com.vanbond.app)

> **Official Store Listing**: [Download on Google Play](https://play.google.com/store/apps/details?id=com.vanbond.app)  
> **Built for RevenueCat Shipaton 2026** | Targeting: **RevenueCat Peace Prize**, **RevenueCat Design Award**, & **Next Gen Award**

---

## 📌 Overview
*“For God so loved the world...” — John 3:16*  
Nomadic living offers unparalleled freedom but often brings profound isolation. Finding partners who share a mobile lifestyle or getting technical help when off-grid electrical setups fail is a major struggle. **VanBond** connects van-lifers and digital nomads for dating, outdoor activities, and DIY vehicle conversion mentorship.

---

## 🚀 Key Features
* **Dual-Mode Discovery Engine**: Toggle instantly between Nomadic Dating 💕 and Activity Friends 🤝 (climbing, skiing, surfing, hiking).
* **Route & Van-Type Matching**: Match based on shared itineraries, current GPS coordinates, and vehicle models (Sprinter, Transit, ProMaster).
* **Builder Help Marketplace**: Book certified conversion specialists for hourly video consultations and technical build advice.
* **AI Van-Build Assistant**: Instant technical answers for 12V solar wiring, plumbing, and insulation challenges.
* **RevenueCat Monetization**: Pro ($25/mo) and Premium ($35/mo) subscriptions for unlimited swipes and route matching, plus Booster Credit Packs for booking builder consultations.

---

## 💳 Judge Reviewer Credentials & Promo Codes
* **Reviewer Account**: `reviewer@vanbond.app` / `Reviewer123!`
* **Google Play / RevenueCat Promo Codes**:
  * 👑 **Premium Subscription**: `VANBONDFREE`
  * ⚡ **10 Builder Credit Pack**: `4ZH1GKZ7SUU3AK93PY0DVBJ`

---

## 🛠 Tech Stack & Architecture
* **Frontend**: Flutter / Dart with gesture-driven swipe cards, image uploaders, and live chat polling
* **Monetization Engine**: RevenueCat SDK (`purchases_flutter`)
* **Backend API**: Python REST API on Azure App Services (`https://vanbon-gbgzfqh8gpbpbkfa.eastus-01.azurewebsites.net`)
* **Verification Pipeline**: Selfie verification workflow for community safety

---

## 📂 Project Structure
```text
vanbond/
├── android/               # Native Android configuration
├── ios/                   # Native iOS configuration
├── lib/
│   ├── main.dart          # App entry, state management, RevenueCat configure
│   ├── models/            # UserSession, UserProfile, Message, BuilderProfile
│   ├── services/          # ApiService (Discovery, swiping, messaging, Azure backend)
│   └── screens/           # HomeScreen, DiscoverScreen, BuilderHubScreen, MessagesScreen, ProfileScreen, UpgradeScreen
├── azure_van/             # Azure backend services
│   ├── app.py             # Flask API endpoints
│   ├── vanbond.db         # SQLite database
│   └── requirements.txt   # Python dependencies
└── pubspec.yaml           # Flutter dependencies
```

---

## ⚙️ Getting Started
```bash
git clone https://github.com/Jerryblessed/vanbond.git
cd vanbond
flutter pub get
flutter run
```

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
