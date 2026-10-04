#!/usr/bin/env python3
from pathlib import Path
import plistlib, shutil, subprocess, sys
root=Path(__file__).resolve().parents[1]
app=Path(sys.argv[2]) if len(sys.argv)>2 else root.parent/'SymptoPage-iOS-Preview.app'
contents=app/'Contents'
(contents/'MacOS').mkdir(parents=True,exist_ok=True)
(contents/'Resources').mkdir(exist_ok=True)
shutil.copy2(sys.argv[1],contents/'MacOS/SymptoPagePreview')
assets=root/'App/Resources/Assets.xcassets'
shutil.copy2(assets/'BrandLogo.imageset/SymptoPage_full_logo_transparent.png', contents/'Resources/BrandLogo.png')
shutil.copy2(assets/'BrandIconBlue.imageset/SymptoPage_app_icon_blue.png', contents/'Resources/BrandIconBlue.png')
shutil.copy2(assets/'BrandLogoWhite.imageset/SymptoPage_logo_white.png', contents/'Resources/BrandLogoWhite.png')
shutil.copy2(assets/'BrandIconWhite.imageset/SymptoPage_app_icon_white.png', contents/'Resources/BrandIconWhite.png')
for font in sorted((root/'App/Resources/Fonts').glob('*.ttf')):
    shutil.copy2(font, contents/'Resources'/font.name)
(contents/'MacOS/SymptoPagePreview').chmod(0o755)
info={'CFBundleExecutable':'SymptoPagePreview','CFBundleIdentifier':'app.symptopage.iospreview','CFBundleName':'SymptoPage iOS Preview','CFBundleDisplayName':'SymptoPage iOS Preview','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.8.0','CFBundleVersion':'5','LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True,'SymptoPagePreviewDataPath':str(root.parent.parent/'work/ios-user-data/records.json')}
if len(sys.argv)>3:
    info['SymptoPagePreviewDataPath']=sys.argv[3]
    info['CFBundleIdentifier']='app.symptopage.qa'
    info['CFBundleDisplayName']='SymptoPage QA'
with (contents/'Info.plist').open('wb') as f: plistlib.dump(info,f)
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
print(app)
