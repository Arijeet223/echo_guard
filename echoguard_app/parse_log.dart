import 'dart:io';

void main() async {
  final process = await Process.start('flutter', ['build', 'apk', '-v'], runInShell: true);
  
  process.stderr.transform(SystemEncoding().decoder).listen((data) {
    if (data.contains('Exception') || data.contains('FAILURE') || data.contains('error') || data.contains('Missing classes') || data.contains('Unresolved reference')) {
      print('\n\n--- ERROR FOUND ---\n$data\n--- END ---');
    }
  });

  process.stdout.transform(SystemEncoding().decoder).listen((data) {
    if (data.contains('Exception') || data.contains('FAILURE') || data.contains('error') || data.contains('Missing classes') || data.contains('Unresolved reference')) {
      print('\n\n--- ERROR FOUND ---\n$data\n--- END ---');
    }
  });

  final exitCode = await process.exitCode;
  print('Build exited with: $exitCode');
}
