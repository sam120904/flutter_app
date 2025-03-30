import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BlynkService {
  // Blynk credentials from your code
  final String templateId = "TMPL3DNFQ3rfM";
  final String templateName = "final";
  final String authToken = "5VyqNitgoIiqWJynb38LQMgqtotgnj_M";
  final String baseUrl = "https://blynk.cloud/external/api";
  
  // Get current weight data from Blynk
  Future<double> getCurrentWeight() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get?token=$authToken&v0'),
      );
      
      if (response.statusCode == 200) {
        final value = response.body.replaceAll('[', '').replaceAll(']', '');
        print('Raw weight value from Blynk: $value');
      
        // Check if the value is empty (not if it's zero)
        if (value.isEmpty) {
          print('Received empty weight, checking if this is a temporary issue');
          // Wait a moment and try again
          await Future.delayed(const Duration(milliseconds: 300));
          final retryResponse = await http.get(
            Uri.parse('$baseUrl/get?token=$authToken&v0'),
          );
        
          if (retryResponse.statusCode == 200) {
            final retryValue = retryResponse.body.replaceAll('[', '').replaceAll(']', '');
            if (retryValue.isNotEmpty) {
              // Accept any non-empty value, including zero
              return double.parse(retryValue);
            }
          }
        
          // Only use default if we truly can't get a value
          return 0.0; // Return actual zero instead of default
        }
      
        // Accept any value, including zero
        return double.parse(value);
      } else {
        print('Failed to load weight data: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to load weight data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting weight: $e');
      // Return zero in case of error instead of default
      return 0.0;
    }
  }
  
  // Get historical weight data
  Future<List<double>> getWeightHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/data/get?token=$authToken&period=day&granularity=1&pin=v0'),
      );
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map<double>((item) => double.parse(item[1].toString())).toList();
      } else {
        throw Exception('Failed to load weight history');
      }
    } catch (e) {
      print('Error getting weight history: $e');
      // Return default values in case of error
      return [30, 35, 38, 40, 42, 42.5];
    }
  }
  
  // Send clearance status to Blynk
  Future<void> setClearance(bool isClearanceGiven) async {
    try {
      final value = isClearanceGiven ? "1" : "0";
      print('Setting clearance to: $value');
    
      final response = await http.get(
        Uri.parse('$baseUrl/update?token=$authToken&v1=$value'),
      );
    
      print('Clearance update response: ${response.statusCode}, ${response.body}');
    
      if (response.statusCode != 200) {
        throw Exception('Failed to update clearance status: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error setting clearance: $e');
      rethrow;
    }
  }
  
  // Send alert status to Blynk
  Future<void> sendAlert(bool sendAlert) async {
    try {
      final value = sendAlert ? "1" : "0";
      print('Setting alert to: $value');
    
      final response = await http.get(
        Uri.parse('$baseUrl/update?token=$authToken&v2=$value'),
      );
    
      print('Alert update response: ${response.statusCode}, ${response.body}');
    
      if (response.statusCode != 200) {
        throw Exception('Failed to update alert status: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error sending alert: $e');
      rethrow;
    }
  }
}