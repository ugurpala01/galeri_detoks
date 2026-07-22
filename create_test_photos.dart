import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  // 3 test fotoğrafı oluştur
  final photos = [
    ('test_photo1.jpg', 'HAYIRLI CUMALAR', 0xFF228B22),
    ('test_photo2.jpg', 'BAYRAMINIZ MUBAREK', 0xFF0064C8),
    ('test_photo3.jpg', 'KANDILINIZ KUTLU OLSUN', 0xFFB40000),
  ];

  for (final (filename, text, color) in photos) {
    final image = img.Image(width: 800, height: 800);
    
    // Arka planı doldur
    for (var y = 0; y < 800; y++) {
      for (var x = 0; x < 800; x++) {
        image.setPixel(x, y, img.ColorRgba8(
          (color >> 16) & 0xFF,
          (color >> 8) & 0xFF,
          color & 0xFF,
          255,
        ));
      }
    }
    
    // Basit beyaz kare ortaya (metin yerine)
    final centerX = 400;
    final centerY = 400;
    final size = 300;
    for (var y = centerY - size ~/ 2; y < centerY + size ~/ 2; y++) {
      for (var x = centerX - size ~/ 2; x < centerX + size ~/ 2; x++) {
        if (x >= 0 && x < 800 && y >= 0 && y < 800) {
          image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        }
      }
    }
    
    final encoded = img.encodeJpg(image);
    File(filename).writeAsBytesSync(encoded);
    print('$filename oluşturuldu');
  }
}
