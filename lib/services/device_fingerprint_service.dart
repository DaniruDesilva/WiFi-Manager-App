import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_ping/dart_ping.dart';
import 'package:multicast_dns/multicast_dns.dart';

class DeviceFingerprintService {
  static final Map<String, String> _mdnsCache = {};
  static MDnsClient? _mdnsClient;

  /// Starts listening to mDNS broadcasts to cache device names
  static Future<void> startMdnsDiscovery() async {
    if (_mdnsClient != null) return;
    
    _mdnsClient = MDnsClient();
    try {
      await _mdnsClient!.start();
      
      final services = [
        '_http._tcp.local',
        '_apple-mobdev2._tcp.local', 
        '_googlecast._tcp.local',
        '_spotify-connect._tcp.local',
        '_smb._tcp.local'
      ];
      
      for (final serviceType in services) {
        _mdnsClient!
            .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(serviceType))
            .listen((ptr) {
          _mdnsClient!
              .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
              .listen((srv) {
            _mdnsClient!
                .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
                .listen((ip) {
              
              // Clean up the name (e.g., "Daniru-iPhone.local" -> "Daniru-iPhone")
              String cleanName = srv.target;
              if (cleanName.endsWith('.local')) {
                cleanName = cleanName.substring(0, cleanName.length - 6);
              }
              if (cleanName.isNotEmpty) {
                _mdnsCache[ip.address.address] = cleanName;
              }
            });
          });
        });
      }
    } catch (e) {
      // mDNS might fail if permissions are missing or port 5353 is in use
    }
  }

  static void stopMdnsDiscovery() {
    _mdnsClient?.stop();
    _mdnsClient = null;
  }

  /// Attempts to identify a device using multiple heuristics
  static Future<String?> fingerprintIp(String ipAddress) async {
    // 1. Check mDNS cache (Apple devices, Casts, etc)
    if (_mdnsCache.containsKey(ipAddress)) {
      return _mdnsCache[ipAddress];
    }
    
    // 2. UPnP SSDP Broadcast (Smart TVs, Routers)
    final upnpName = await _checkUPnP(ipAddress);
    if (upnpName != null) {
      return upnpName;
    }

    // 3. NetBIOS Name Service (Windows PCs - e.g., LAPTOP-XXXXX)
    final netbiosName = await _checkNetBIOS(ipAddress);
    if (netbiosName != null) {
      return '$netbiosName (Windows)';
    }
    
    // 4. Ping TTL Analysis (OS identification fallback)
    try {
      final ping = Ping(ipAddress, count: 1, timeout: 1);
      String? osGuess;
      await for (final data in ping.stream) {
        if (data.response != null && data.response!.ttl != null) {
          final ttl = data.response!.ttl!;
          if (ttl > 100 && ttl <= 128) {
            osGuess = 'Windows Device';
          } else if (ttl > 200) {
            osGuess = 'Network Equipment';
          } else if (ttl > 0 && ttl <= 64) {
            // Unix/Linux/Android/iOS/Mac usually have 64
            // But if mDNS didn't catch it, it might just be a generic device
            // We leave it null to not incorrectly label a phone as Linux
          }
        }
      }
      if (osGuess != null) return osGuess;
    } catch (e) {
      // Ignore ping errors
    }
    
    return null;
  }

  /// Sends a NetBIOS Node Status Query to get Windows PC names
  static Future<String?> _checkNetBIOS(String ipAddress) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.readEventsEnabled = true;
      
      final query = <int>[
        0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 
        0x43, 0x4B, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21, 0x00, 0x01
      ];
      
      socket.send(query, InternetAddress(ipAddress), 137);
      
      final completer = Completer<String?>();
      
      socket.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          final d = socket.receive();
          if (d != null && d.data.length > 57) {
            final nameBytes = d.data.sublist(57, 57 + 15);
            final name = ascii.decode(nameBytes, allowInvalid: true).trim();
            if (name.isNotEmpty && !completer.isCompleted) {
              completer.complete(name);
            }
          }
        }
      });
      
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!completer.isCompleted) completer.complete(null);
        socket.close();
      });
      
      return await completer.future;
    } catch (e) {
      return null;
    }
  }
  
  /// Sends a UPnP SSDP probe to the given IP and extracts the Server header
  static Future<String?> _checkUPnP(String ipAddress) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.readEventsEnabled = true;
      
      final msg = "M-SEARCH * HTTP/1.1\r\n"
          "HOST: 239.255.255.250:1900\r\n"
          "MAN: \"ssdp:discover\"\r\n"
          "MX: 1\r\n"
          "ST: ssdp:all\r\n\r\n";
          
      socket.send(utf8.encode(msg), InternetAddress(ipAddress), 1900);
      
      final completer = Completer<String?>();
      
      socket.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          final d = socket.receive();
          if (d != null) {
            final response = utf8.decode(d.data, allowMalformed: true);
            
            // Extract SERVER: header which usually contains brand/OS info
            final serverMatch = RegExp(r'(?i)SERVER:\s*(.+)').firstMatch(response);
            if (serverMatch != null) {
              String srv = serverMatch.group(1)!.trim();
              if (srv.length > 30) {
                // Shorten long strings
                srv = srv.substring(0, 30);
              }
              if (!completer.isCompleted) {
                completer.complete(srv);
              }
            }
          }
        }
      });
      
      // Wait max 600ms for a response
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        socket.close();
      });
      
      return await completer.future;
    } catch (e) {
      return null;
    }
  }
}
