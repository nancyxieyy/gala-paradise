#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./build-release.sh
mkdir -p releases/staging/Mac releases/staging/Windows
ditto 'build/universal/旮旯乐园.app' 'releases/staging/Mac/旮旯乐园.app'
cp build/windows-x64/GalaParadise.exe releases/staging/Windows/
cp Docs/DotNet-*.txt Docs/WindowsDesktop-LICENSE.txt releases/staging/Windows/
for platform in Mac Windows; do
  cp Docs/朋友测试说明.txt "releases/staging/$platform/先读我.txt"
  cp Docs/反馈模板.txt "releases/staging/$platform/反馈模板.txt"
done
ditto -c -k --sequesterRsrc --keepParent releases/staging/Mac releases/GalaParadise-1.4-macOS-Universal.zip
python3 - <<'PY'
from pathlib import Path
import zipfile,hashlib
root=Path('releases')
with zipfile.ZipFile(root/'GalaParadise-1.4-Windows-x64.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted((root/'staging/Windows').iterdir()):
        if p.is_file():z.write(p,'GalaParadise-Windows/'+p.name)
(root/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(root.glob('*.zip'))))
PY
print 'Shareable packages are in releases/'
