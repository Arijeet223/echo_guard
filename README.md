🛡️ Veritas

System-Wide Fact Checking at Your Fingertips

Veritas is an AI-powered misinformation detection application that enables users to verify the credibility of digital content without leaving the app they are currently using.

Using a floating Guardian Bubble overlay, Veritas can scan content directly from the screen and perform real-time multimodal fact-checking using AI.

The mission of Veritas is to break echo chambers, reduce misinformation, and empower digital truth.

🚨 The Problem

Modern digital platforms allow misinformation to spread faster than verified facts.

Social media ecosystems such as WhatsApp, X (Twitter), Instagram, and Facebook amplify:

• Fake news
• Deepfakes
• Clickbait headlines
• Misleading screenshots

Traditional fact-checking requires users to:

Copy the suspicious text

Leave the current application

Open a browser

Search and verify sources manually

This friction causes most users to skip verification entirely, allowing misinformation to propagate rapidly.

💡 The Solution

Veritas introduces frictionless fact verification.

Instead of forcing users to leave their apps, Veritas uses a floating overlay bubble that works across applications.

With a single tap, users can instantly scan and verify the credibility of the content they are currently viewing.

⚙️ Core Features
🫧 Guardian Bubble (System Overlay)

A floating Android overlay that sits above all apps.

Users can tap the bubble to instantly scan the current screen and analyze its credibility.

🔍 Multimodal Analysis Engine

Veritas can analyze multiple types of content:

• Text
• Images
• Screenshots
• URLs

Using OCR + AI reasoning + real-world news verification.

🤖 Mira AI Assistant

Mira is the built-in AI assistant that explains verification results.

Features include:

• Interactive explanations
• Animated emotional avatars (Thinking, Happy, Suspicious)
• Minimal, distraction-free interface

🌐 Bilingual Support (English + Hindi)

Veritas provides full bilingual functionality.

Users can toggle between:

• English
• Hindi (Devanagari)

This helps bring AI-powered misinformation detection to non-English speakers.

📰 Community Truth Feed

A community platform where users can share verified information.

Capabilities include:

• Posting verified claims
• Discussion threads
• Community validation

🧠 Local Scan History & Truth Score

The application stores scan results locally and tracks user engagement.

Users earn a Truth Score to encourage responsible information verification.

All history remains stored locally on the device for privacy.

🧩 Tech Stack
Layer	Technologies
Frontend	Flutter, Dart
State Management	Provider
Local Storage	Hive / SharedPreferences
Overlay System	flutter_overlay_window
Native Android APIs	Accessibility Service, System Alert Window
AI Engine	Inception Labs Mercury-2
OCR Engine	OCR.space API
Networking	HTTP REST APIs
UI Design	Figma
Image Processing	Python (Pillow)
🧠 System Architecture

Veritas uses a client-heavy architecture.

Instead of running complex backend infrastructure:

• The mobile device handles UI and state management
• AI reasoning is performed through API calls
• History and scores are stored locally

This design enables efficient scaling with minimal infrastructure requirements.

🔄 Verification Flow

1️⃣ User taps the Guardian Bubble

2️⃣ App captures the visible screen

3️⃣ OCR extracts text from the screen

4️⃣ Extracted claims are sent to the Mercury-2 AI model

5️⃣ AI verifies the claim using web evidence and reasoning

6️⃣ Structured verification result returned

Example output:

{
  "credibility_score": 78,
  "bias_level": "medium",
  "reasoning": "Claim partially supported but lacks full context.",
  "sources": [
    "BBC News",
    "The Hindu",
    "NASA"
  ]
}

7️⃣ Results are displayed in a floating analysis panel

📱 Screenshots

(Add screenshots after uploading them to your repo)

Example:

/screenshots/home.png
/screenshots/guardian_bubble.png
/screenshots/analysis_panel.png
/screenshots/mira_ai.png
🧪 Installation

Clone the repository:

git clone https://github.com/Arijeet223/echo_guard.git

Navigate into the project:

cd echo_guard

Install dependencies:

flutter pub get

Run the application:

flutter run
🔐 Permissions Required

Veritas requires several Android permissions:

• System Alert Window — to display the Guardian Bubble overlay
• Accessibility Service — to read screen content for analysis
• Internet Access — to communicate with AI and OCR APIs

🚀 Future Roadmap
🎥 Video Fact-Checking

Real-time transcript analysis for:

• YouTube Shorts
• Instagram Reels
• TikTok

A bigger forum with multiple iteractive features

⛓️ Decentralized Truth Ledger

A blockchain-based ledger for tamper-proof verification records.
