from pathlib import Path
import plistlib
import subprocess
import sys

image = Path(sys.argv[1]).resolve()
attached = plistlib.loads(subprocess.check_output([
    "hdiutil", "attach", "-readonly", "-nobrowse", "-plist", str(image)
]))
volume = Path(next(entity["mount-point"] for entity in attached["system-entities"]
                   if "mount-point" in entity))
try:
    subprocess.run(["codesign", "--verify", "--strict", str(volume / "Slip.app")], check=True)
    applications = volume / "Applications"
    if not applications.is_symlink() or applications.readlink() != Path("/Applications"):
        raise ValueError("The installer must link to /Applications.")
    print("Verified the packaged app signature and Applications link.")
finally:
    subprocess.run(["hdiutil", "detach", str(volume)], check=True)
