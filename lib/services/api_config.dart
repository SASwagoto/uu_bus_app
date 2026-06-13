// lib/services/api_config.dart

class ApiConfig {
  // 💡 আপনার লোকাল সার্ভারের আইপি (প্রয়োজন অনুযায়ী পরিবর্তন করে নেবেন)
  static const String baseUrl = "http://192.168.0.193/uu-bus-manage/public/api";

  // Auth Endpoints
  static const String login = "$baseUrl/login";
  static const String register = "$baseUrl/register";
  static const String logout = "$baseUrl/logout";
  static const String userProfile = "$baseUrl/user";

  // Shared Endpoint (Driver & Passenger)
  static const String getSchedules = "$baseUrl/schedules";

  // Driver Endpoints
  static const String currentActiveTrip = "$baseUrl/driver/current-active-trip";
  static const String startTrip = "$baseUrl/driver/trip/start";

  // 💡 ড্রাইভারের লোকেশন আপডেট করার ডাইনামিক ইউআরএল মেথড
  static String updateLocation(int tripId) {
    return "$baseUrl/driver/trip/$tripId/update-location";
  }

  // 💡 ড্রাইভারের ট্রিপ এন্ড করার ডাইনামিক ইউআরএল মেথড
  static String endTrip(int tripId) {
    return "$baseUrl/driver/trip/$tripId/end";
  }

  // Passenger Endpoints
  static const String activeTrips = "$baseUrl/passenger/active-trips";

  // 💡 প্যাসেঞ্জারের বাস ট্র্যাক করার ডাইনামিক ইউআরএল মেথড
  static String trackBus(int tripId) {
    return "$baseUrl/passenger/trip/$tripId/track";
  }

  // 💡 প্যাসেঞ্জারের বাসে চেক-ইন করার ডাইনামিক ইউআরএল মেথড
  static String tripCheckIn(int tripId) {
    return "$baseUrl/passenger/trip/$tripId/check-in";
  }
  static String tripCheckOut(int tripId) {
    return "$baseUrl/passenger/trip/$tripId/check-out";
  }

  static String tripStatus(int tripId) => "$baseUrl/passenger/trip/$tripId/status";

}