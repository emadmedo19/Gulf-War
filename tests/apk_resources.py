"""Expose the actual Android APK resource bytes to the Godot texture validator."""
import sys
import zipfile
with zipfile.ZipFile(sys.argv[1]) as apk, zipfile.ZipFile(sys.argv[2], 'w') as resources:
    for item in apk.infolist():
        if item.filename.startswith('assets/') and not item.is_dir():
            resources.writestr(item.filename[len('assets/'):], apk.read(item))
print('Prepared actual APK resources for decode verification')
