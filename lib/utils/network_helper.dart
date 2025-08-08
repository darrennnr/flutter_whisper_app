import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logger.dart';

class NetworkHelper {
  static Future<bool> isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        AppLogger.warning('No network connectivity', tag: 'NetworkHelper');
        return false;
      }
      
      // Test actual internet connectivity
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      AppLogger.info('Internet connectivity: $isConnected', tag: 'NetworkHelper');
      return isConnected;
    } catch (e) {
      AppLogger.error('Error checking network connectivity', 
        tag: 'NetworkHelper', 
        error: e
      );
      return false;
    }
  }
  
  static Stream<ConnectivityResult> get connectivityStream {
    return Connectivity().onConnectivityChanged;
  }
}