import 'dart:io'; 
void main() { 
  var lines = File('pubspec.yaml').readAsLinesSync(); 
  var i = lines.indexOf('name: wifi_qr_generator', 1); 
  if (i != -1) { 
    lines = lines.sublist(0, i); 
    File('pubspec.yaml').writeAsStringSync(lines.join('\n') + '\nflutter_launcher_icons:\n  android: true\n  ios: true\n  image_path: "assets/icon.png"\n\nflutter_native_splash:\n  color: "#F2F2F7"\n  color_dark: "#0F172A"\n  image: "assets/icon.png"\n  android_12:\n    image: "assets/icon.png"\n    icon_background_color: "#F2F2F7"\n    icon_background_color_dark: "#0F172A"\n'); 
  } 
}
