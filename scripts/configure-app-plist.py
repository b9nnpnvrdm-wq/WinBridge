"""Set the monotonically increasing build and optional signed update feed."""

import base64
import os
import plistlib
import sys
from pathlib import Path
from urllib.parse import urlsplit

path = Path(sys.argv[1])
info = plistlib.loads(path.read_bytes())
build = os.environ.get("WINBRIDGE_BUILD_NUMBER", "1")
if not build.isascii() or not build.isdecimal() or build.startswith("0"):
    sys.exit("WINBRIDGE_BUILD_NUMBER must be a positive integer without leading zeroes")
info["CFBundleVersion"] = build

feed = os.environ.get("WINBRIDGE_UPDATE_FEED_URL", "")
key = os.environ.get("WINBRIDGE_UPDATE_PUBLIC_KEY", "")
if feed or key:
    try:
        public_key = base64.b64decode(key, validate=True)
    except ValueError:
        sys.exit("WINBRIDGE_UPDATE_PUBLIC_KEY must be a Sparkle Ed25519 public key (base64)")
    url = urlsplit(feed)
    if (len(public_key) != 32 or url.scheme != "https" or not url.hostname
            or url.username or url.password or url.fragment):
        sys.exit("Set both a Sparkle public key and a public HTTPS appcast URL")
    info.update(
        SUFeedURL=feed,
        SUPublicEDKey=key,
        SUEnableAutomaticChecks=True,
        SUAutomaticallyUpdate=True,
    )
path.write_bytes(plistlib.dumps(info))
