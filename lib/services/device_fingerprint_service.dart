import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DeviceFingerprintService {
  static final Map<String, String> _mdnsCache = {};
  static MDnsClient? _mdnsClient;
  static String? _gatewayIp;

  /// Reads the ARP table from /proc/net/arp to get MAC addresses.
  /// Works on many Android devices even Android 10+.
  static Future<Map<String, String>> readArpTable() async {
    final Map<String, String> arpMap = {};
    try {
      final file = File('/proc/net/arp');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (int i = 1; i < lines.length; i++) { // Skip header
          final parts = lines[i].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final ip = parts[0];
            final flags = parts[2];
            final mac = parts[3].toUpperCase();
            
            // Flags 0x2 means reachable/alive. 0x0 means incomplete.
            if (flags.contains('2') && mac != '00:00:00:00:00:00' && mac.contains(':') && mac.length == 17) {
              arpMap[ip] = mac;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ARP table read failed: $e');
    }

    // Also try `ip neigh` as a fallback
    if (arpMap.isEmpty) {
      try {
        final result = await Process.run('ip', ['neigh']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n');
          for (final line in lines) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 5) {
              final ip = parts[0];
              final llidx = parts.indexOf('lladdr');
              if (llidx != -1 && llidx + 1 < parts.length) {
                final mac = parts[llidx + 1].toUpperCase();
                
                // Only consider it if state is not FAILED or INCOMPLETE
                final state = parts.last.toUpperCase();
                if (state != 'FAILED' && state != 'INCOMPLETE') {
                  if (mac != '00:00:00:00:00:00' && mac.contains(':') && mac.length == 17) {
                    arpMap[ip] = mac;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    return arpMap;
  }

  /// Detects the default gateway IP address
  static Future<String?> detectGateway() async {
    if (_gatewayIp != null) return _gatewayIp;
    try {
      // Try to get gateway from `ip route`
      final result = await Process.run('ip', ['route']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          if (line.startsWith('default')) {
            final parts = line.split(RegExp(r'\s+'));
            final viaIdx = parts.indexOf('via');
            if (viaIdx != -1 && viaIdx + 1 < parts.length) {
              _gatewayIp = parts[viaIdx + 1];
              return _gatewayIp;
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: try common gateway from current IP
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          _gatewayIp = '${parts[0]}.${parts[1]}.${parts[2]}.1';
          return _gatewayIp;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Performs a very fast UDP NetBIOS sweep of the entire subnet.
  static Future<Map<String, String>> scanSubnetNetBIOS(String subnet) async {
    final Map<String, String> results = {};
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.readEventsEnabled = true;
      
      final query = <int>[
        0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 
        0x43, 0x4B, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21, 0x00, 0x01
      ];
      
      for (int i = 1; i < 255; i++) {
        socket.send(query, InternetAddress('$subnet.$i'), 137);
      }
      
      socket.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.data.length > 57) {
            final nameBytes = datagram.data.sublist(57, 57 + 15);
            final name = ascii.decode(nameBytes, allowInvalid: true).trim();
            if (name.isNotEmpty) {
              results[datagram.address.address] = name;
            }
          }
        }
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      socket.close();
    } catch (_) {}
    return results;
  }

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
        '_smb._tcp.local',
        '_airplay._tcp.local',
        '_raop._tcp.local',
        '_printer._tcp.local',
        '_ipp._tcp.local',
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

  /// Quickly checks if a TCP port is open on the given IP
  static Future<bool> _isPortOpen(String ip, int port, {int timeoutMs = 250}) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: timeoutMs));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Identifies device type based on which ports are open
  static Future<String?> _identifyByPorts(String ipAddress) async {
    // Run port checks in parallel for speed
    final results = await Future.wait([
      _isPortOpen(ipAddress, 80),    // HTTP (routers, smart devices)
      _isPortOpen(ipAddress, 443),   // HTTPS
      _isPortOpen(ipAddress, 53),    // DNS (routers)
      _isPortOpen(ipAddress, 62078), // Apple Sync (iPhone/iPad)
      _isPortOpen(ipAddress, 548),   // Apple Filing Protocol (Mac)
      _isPortOpen(ipAddress, 9100),  // Printer (raw printing)
      _isPortOpen(ipAddress, 631),   // IPP (network printers)
      _isPortOpen(ipAddress, 5353),  // mDNS
      _isPortOpen(ipAddress, 8008),  // Chromecast
      _isPortOpen(ipAddress, 8443),  // Chromecast secure
      _isPortOpen(ipAddress, 445),   // SMB (Windows file sharing)
      _isPortOpen(ipAddress, 3689),  // DAAP (iTunes/Apple Music)
      _isPortOpen(ipAddress, 5000),  // Synology NAS
      _isPortOpen(ipAddress, 8080),  // Alt HTTP (smart devices)
      _isPortOpen(ipAddress, 554),   // RTSP (IP cameras)
    ]);

    final hasHttp     = results[0];
    final hasHttps    = results[1];
    final hasDns      = results[2];
    final hasAppleSync = results[3];
    final hasAfp      = results[4];
    final hasPrinter  = results[5];
    final hasIpp      = results[6];
    // final hasMdns  = results[7]; // Not used for classification directly
    final hasCast1    = results[8];
    final hasCast2    = results[9];
    final hasSmb      = results[10];
    final hasDaap     = results[11];
    final hasNas      = results[12];
    final hasAltHttp  = results[13];
    final hasRtsp     = results[14];

    // Apple devices
    if (hasAppleSync) return 'Apple Device (iPhone/iPad)';
    if (hasAfp || hasDaap) return 'Apple Mac';

    // Printer
    if (hasPrinter || hasIpp) return 'Network Printer';

    // Chromecast / Google device
    if (hasCast1 || hasCast2) return 'Google Chromecast';

    // IP Camera
    if (hasRtsp) return 'IP Camera';

    // NAS
    if (hasNas) return 'NAS Storage';

    // Windows PC (SMB without DNS = likely a PC, not a router)
    if (hasSmb && !hasDns) return 'Windows PC';

    // Router / Gateway (has DNS + HTTP)
    if (hasDns && (hasHttp || hasHttps)) return 'Router / Gateway';
    if (hasDns) return 'DNS Server / Router';

    // Generic web server (could be a smart device)
    if (hasHttp || hasAltHttp) return 'Smart Device';

    return null;
  }

  /// Attempts to identify a device using multiple heuristics
  static Future<String?> fingerprintIp(String ipAddress) async {
    // 0. Check if this is the gateway/router
    final gateway = await detectGateway();
    if (gateway != null && ipAddress == gateway) {
      return 'Router / Gateway';
    }

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

    // 4. Port-based identification (most reliable fallback)
    final portId = await _identifyByPorts(ipAddress);
    if (portId != null) {
      return portId;
    }
    
    // 5. Ping TTL Analysis (last resort)
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
          } else if (ttl == 64) {
            osGuess = 'Linux / Android Device';
          } else if (ttl > 0 && ttl < 64) {
            // TTL degraded by hops, but started at 64
            osGuess = 'Mobile Device';
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
      
      const msg = "M-SEARCH * HTTP/1.1\r\n"
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
            
            final serverMatch = RegExp(r'SERVER:\s*(.+)', caseSensitive: false).firstMatch(response);
            if (serverMatch != null) {
              String srv = serverMatch.group(1)!.trim();
              if (srv.length > 30) {
                srv = srv.substring(0, 30);
              }
              if (!completer.isCompleted) {
                completer.complete(srv);
              }
            }
          }
        }
      });
      
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
