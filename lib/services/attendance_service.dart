import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AttendanceService {
  static String get baseUrl => AuthService.baseUrl;


   static Future<Map<String, dynamic>> scanQR(String qrCode) async {
     try {
       final userData = await AuthService.getUserData();
       final employeeId = userData['employeeId'];

       if (employeeId == null) {
         return {'success': false, 'message': 'Employee data not found. Please login again.'};
       }

       final response = await http.post(
         Uri.parse('$baseUrl/scan_attendance.php'),
         body: {
           'employee_id': employeeId.toString(),
           'qr_code': qrCode,
         },
       );

       if (response.statusCode == 200) {
         try {
           return jsonDecode(response.body);
         } on FormatException catch (_) {
           // Check if response is HTML (likely server error)
           if (response.body.contains('<html') || response.body.contains('<!DOCTYPE')) {
             return {'success': false, 'message': 'Server returned an error page instead of JSON. Check your PHP backend logs for database connection issues.'};
           }
           return {'success': false, 'message': 'Invalid response format from server: ${response.body}'};
         }
       }
       return {'success': false, 'message': 'Server error: ${response.statusCode}: ${response.body}'};
     } catch (e) {
       return {'success': false, 'message': 'Connection error: $e\nPlease check:\n1. Your server IP address in baseUrl\n2. That your device and server are on the same Wi-Fi network\n3. That your backend server is running\n4. That there are no firewall restrictions'};
     }
   }

   static Future<Map<String, dynamic>> getAttendanceHistory() async {
     try {
       final userData = await AuthService.getUserData();
       final employeeId = userData['employeeId'];

       if (employeeId == null) {
         return {'success': false, 'message': 'Employee data not found'};
       }

       final response = await http.get(
         Uri.parse('$baseUrl/attendance_history.php?employee_id=$employeeId'),
       );

       if (response.statusCode == 200) {
         try {
           return jsonDecode(response.body);
         } on FormatException catch (_) {
           // Check if response is HTML (likely server error)
           if (response.body.contains('<html') || response.body.contains('<!DOCTYPE')) {
             return {'success': false, 'message': 'Server returned an error page instead of JSON. Check your PHP backend logs for database connection issues.'};
           }
           return {'success': false, 'message': 'Invalid response format from server: ${response.body}'};
         }
       }
       return {'success': false, 'message': 'Server error: ${response.statusCode}: ${response.body}'};
     } catch (e) {
       return {'success': false, 'message': 'Connection error: $e\nPlease check:\n1. Your server IP address in baseUrl\n2. That your device and server are on the same Wi-Fi network\n3. That your backend server is running\n4. That there are no firewall restrictions'};
     }
   }
}
