# 🔬 Vitalyz: Your Smart Health Guardian

*Vitalyz* is a cutting-edge, proactive mobile health guardian application that works in conjunction with a specialized wearable device (watch) to provide comprehensive real-time health monitoring.

It uses continuous data streams from the body and surrounding environment to calculate and predict serious health risks like *organ failures, **heatstroke, and **dehydration*, offering users immediate, actionable insights to maintain optimal health.

---

## 💡 How It Works: The Calibration Advantage

Vitalyz relies on *personalized baseline data* to accurately identify health risks. The initial two-day period is critical:

### The Calibration Phase (48 Hours)
During this phase, the watch collects *baseline data* unique to the user's body. This establishes the user's *normal or usual range* for:
* *Resting Heart Rate* and normal daily rate variability.
* *Typical Body Temperature* fluctuations.
* *Personalized Sweat Levels* (measured via Skin Conductivity) under various activity and environmental conditions.

### Real-Time Anomaly Detection
After calibration, the app constantly compares the user's *Current Vitals* against their *Personalized Baseline. Any significant deviation from this established normal range—such as an abnormally high heart rate or a sudden drop in sweat levels—is flagged as an **abnormal vital activity* and used as the foundation for all risk predictions.

---

## ✨ Key Features

### 1. Real-Time Vitals Monitoring
Vitalyz uses four primary real-time data streams collected directly from the paired wearable device:
* *Heart Rate (bpm)*
* *Body Temperature (°C)* (Core and/or Skin)
* *Sweat Levels (μS)* (Measured via Skin Conductivity)
* *Surrounding Temperature (°C)*
* *Surrounding Humidity (%)*

### 2. Proactive Risk Prediction & Calculation Logic

Vitalyz uses its *calibrated baseline data* and the four key inputs to identify critical deviations and predict health risks:

| Risk Category | Key Anomaly Comparison | Logic Explained |
| :--- | :--- | :--- |
| *Predict Organ Risks* | *Current Heart Rate* vs. *Calibrated Resting/Activity HR* | Looks for prolonged episodes of Tachycardia or Bradycardia relative to the user's normal range, cross-referenced with unexplained Body Temperature spikes, signaling potential cardiovascular or kidney strain. |
| *Predict Heatstroke* | *Body Temp Trend* vs. *Calibrated Fluctuation* & *Surrounding Temp* | Monitors the rate of core temperature increase. An alert is triggered if the temperature rises too quickly or exceeds the personalized healthy maximum, especially when high environmental temperatures and humidity prevent effective cooling. |
| *Automatic Hydration Tracker* | *Current Sweat Levels* vs. *Calibrated Normal Levels* | Tracks a significant and sudden increase in *Sweat Levels* (fluid loss) and a compensatory increase in *Heart Rate, comparing these against the user's usual trends to accurately predict **Fluid Deficit* and trigger dehydration warnings. |

### 3. Data Analysis & Insights
* *Risk Refinements:* Advanced processing of raw data for highly accurate health assessments.
* *Trend Analysis & Charts:* Visualize your historical health data and identify patterns.
* *Anomaly Detection:* Instantly flags unusual or concerning vital sign readings.
* *Personalized Health Score:* A single, easy-to-understand metric summarizing your overall health status.

### 4. General Functionality
* *Profile Management:* Easily view and edit your personal health profile (Age, Height, Weight, Gender, and Medical Conditions) for personalized predictions.
* *Authentication:* Seamless *Sign in with Google* or traditional Email/Password login.

---

## 🛠 Technology Stack

* *Mobile App:* [Specify Framework, e.g., Flutter, React Native, Native Android/iOS]
* *Backend & Database:* *Firebase Firestore* (Used for storing all collected sensor data and user profiles).
* *Data Source:* Custom Wearable Watch (Data transfer via Bluetooth/BLE to the app, then to the backend).

---

## 🚀 Getting Started

Follow these steps to set up the Vitalyz mobile application locally.

### Prerequisites

* *[REQUIRED SOFTWARE 1, e.g., Flutter SDK]*
* *[REQUIRED SOFTWARE 2, e.g., A specific IDE like Android Studio or VS Code]*
* An Android or iOS device/emulator.

### Installation

1.  *Clone the repository:*
    bash
    git clone [https://github.com/your-username/vitalyz.git](https://github.com/your-username/vitalyz.git)
    cd vitalyz
    
2.  *Install Dependencies:*
    flutter pub get
   
    
3.  *Backend Configuration (Firebase):*
    To connect to the backend, you must add your own Firebase configuration files (google-services.json for Android and GoogleService-Info.plist for iOS). This setup handles the data flow from the simulated watch to the app to the backend.
4.  *Run the application:*
    flutter run




    VITALYZ APP LINK - https://drive.google.com/file/d/1quBi9aC7xBNF5mLlBHi4x1jwIKCMQwOD/view?usp=sharing

---
