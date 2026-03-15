/// Central configuration for the Veritas backend API.
/// 
/// The ngrok public URL is set here after starting the server.
/// Both the main app and the overlay read from this single source.
class AppConfig {
  // ═══════════════════════════════════════════════════════════════
  //  SET YOUR BACKEND URL HERE
  //  After starting the server, copy the ngrok URL from the 
  //  terminal output and paste it below, then rebuild the APK.
  //  
  //  Example: 'https://abc123.ngrok-free.app'
  //  
  //  For local testing on the same Wi-Fi, use your PC's IP:
  //  Example: 'http://192.168.1.100:8000'
  // ═══════════════════════════════════════════════════════════════
  static const String backendUrl = 'https://four-zoos-talk.loca.lt';
  
  // Fallback for web browser testing (Flutter web on same machine)
  static const String localUrl = 'http://127.0.0.1:8000';
}
