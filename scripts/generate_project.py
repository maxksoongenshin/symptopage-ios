#!/usr/bin/env python3
"""Deterministic Xcode project, no external generator dependency."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value))
def add(name, text):
    key = uid(name); objects[key] = text; return key
def seq(values): return '(' + ', '.join(values) + (',)' if values else ')')
appfiles = sorted(root.glob('Core/*.swift')) + sorted(root.glob('App/*.swift'))
testfiles = sorted(root.glob('UITests/*.swift'))
# Apple Watch app: platform-neutral Core files plus the watch UI.
watchcore = ['Catalog','Models','MedicationHistory','Scheduling','Health','WatchMessages','Persistence']
watchfiles = [root/f'Core/{n}.swift' for n in watchcore] + sorted(root.glob('Watch/*.swift'))
watchresources = ['Watch/Assets.xcassets'] + [str(p.relative_to(root)) for p in sorted(root.glob('App/Resources/Fonts/*.ttf'))]
resources = ['App/Resources/Assets.xcassets', 'App/Resources/PrivacyInfo.xcprivacy'] + [str(p.relative_to(root)) for p in sorted(root.glob('App/Resources/Fonts/*.ttf'))]
refs = []; builds = []; testbuilds = []; resourcebuilds = []; watchbuilds = []; watchresourcebuilds = []
known = {}
def fileref(rel, kind):
    if rel not in known:
        known[rel] = add('ref:'+rel, '{isa = PBXFileReference; lastKnownFileType = '+kind+'; path = '+q(rel)+'; sourceTree = "<group>";}'); refs.append(known[rel])
    return known[rel]
for path in appfiles + testfiles:
    rel = str(path.relative_to(root))
    ref = fileref(rel, 'sourcecode.swift')
    build = add('build:'+rel, '{isa = PBXBuildFile; fileRef = '+ref+';}')
    (testbuilds if path in testfiles else builds).append(build)
for path in watchfiles:
    rel = str(path.relative_to(root))
    watchbuilds.append(add('wbuild:'+rel, '{isa = PBXBuildFile; fileRef = '+fileref(rel, 'sourcecode.swift')+';}'))
def kind(rel): return 'folder.assetcatalog' if rel.endswith('xcassets') else 'file' if rel.endswith('.ttf') else 'text.xml'
for rel in resources:
    resourcebuilds.append(add('build:'+rel, '{isa = PBXBuildFile; fileRef = '+fileref(rel, kind(rel))+';}'))
for rel in watchresources:
    watchresourcebuilds.append(add('wbuild:'+rel, '{isa = PBXBuildFile; fileRef = '+fileref(rel, kind(rel))+';}'))
for rel in ['Configuration/iOS-Info.plist', 'Configuration/Watch-Info.plist', 'Configuration/HealthKit.entitlements']:
    fileref(rel, 'text.plist' if rel.endswith('plist') else 'text.plist.entitlements')
appProduct = add('appProduct', '{isa = PBXFileReference; explicitFileType = wrapper.application; path = SymptoPage.app; sourceTree = BUILT_PRODUCTS_DIR;}')
watchProduct = add('watchProduct', '{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SymptoPageWatch.app; sourceTree = BUILT_PRODUCTS_DIR;}')
testProduct = add('testProduct', '{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = SymptoPageUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
products = add('products', '{isa = PBXGroup; children = '+seq([appProduct, watchProduct, testProduct])+'; name = Products; sourceTree = "<group>";}')
main = add('main', '{isa = PBXGroup; children = '+seq(refs+[products])+'; sourceTree = "<group>";}')
def phase(name, isa, files): return add(name, '{isa = '+isa+'; buildActionMask = 2147483647; files = '+seq(files)+'; runOnlyForDeploymentPostprocessing = 0;}')
sourcePhase = phase('sources','PBXSourcesBuildPhase', builds)
resourcePhase = phase('resources','PBXResourcesBuildPhase',resourcebuilds)
frameworkPhase = phase('frameworks','PBXFrameworksBuildPhase',[])
testSource = phase('testSources','PBXSourcesBuildPhase',testbuilds)
testFrameworks = phase('testFrameworks','PBXFrameworksBuildPhase',[])
watchSource = phase('watchSources','PBXSourcesBuildPhase',watchbuilds)
watchResources = phase('watchResources','PBXResourcesBuildPhase',watchresourcebuilds)
watchFrameworks = phase('watchFrameworks','PBXFrameworksBuildPhase',[])
embedWatchFile = add('embedWatchFile', '{isa = PBXBuildFile; fileRef = '+watchProduct+'; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); };}')
embedWatch = add('embedWatch', '{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; dstSubfolderSpec = 16; files = '+seq([embedWatchFile])+'; name = "Embed Watch Content"; runOnlyForDeploymentPostprocessing = 0;}')
def configs(name, settings):
    items=[]
    for mode in ['Debug','Release']:
        values=dict(settings)
        values['SWIFT_OPTIMIZATION_LEVEL']='-Onone' if mode=='Debug' else '-O'
        if mode=='Debug': values['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        text=' '.join(k+' = '+q(v)+';' for k,v in values.items())
        items.append(add(name+mode,'{isa = XCBuildConfiguration; buildSettings = {'+text+'}; name = '+mode+';}'))
    return add(name+'ConfigList','{isa = XCConfigurationList; buildConfigurations = '+seq(items)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
common={'APP_BUNDLE_ID':'app.symptopage.ios','STRAVA_CLIENT_ID':'','STRAVA_TOKEN_URL':'','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','CODE_SIGN_STYLE':'Automatic'}
projectConfig=configs('project',common)
appConfig=configs('app',{'PRODUCT_BUNDLE_IDENTIFIER':'$(APP_BUNDLE_ID)','PRODUCT_NAME':'SymptoPage','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'SymptoPage','INFOPLIST_FILE':'Configuration/iOS-Info.plist','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','MARKETING_VERSION':'0.8.0','CURRENT_PROJECT_VERSION':'5','CODE_SIGN_ENTITLEMENTS':'Configuration/HealthKit.entitlements','INFOPLIST_KEY_NSHealthShareUsageDescription':'SymptoPage reads heart rate, resting heart rate, HRV, steps, sleep and workouts to add them to your visit report. Nothing is written to Health. / SymptoPage odczytuje tętno, tętno spoczynkowe, HRV, kroki, sen i treningi, aby dodać je do raportu na wizytę. Nic nie jest zapisywane w Zdrowiu.','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ENABLE_PREVIEWS':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'})
watchConfig=configs('watch',{'PRODUCT_BUNDLE_IDENTIFIER':'$(APP_BUNDLE_ID).watchkitapp','PRODUCT_NAME':'SymptoPageWatch','SDKROOT':'watchos','SUPPORTED_PLATFORMS':'watchos watchsimulator','TARGETED_DEVICE_FAMILY':'4','WATCHOS_DEPLOYMENT_TARGET':'10.0','INFOPLIST_FILE':'Configuration/Watch-Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_ENTITLEMENTS':'Configuration/HealthKit.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','SKIP_INSTALL':'YES','MARKETING_VERSION':'0.8.0','CURRENT_PROJECT_VERSION':'5','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','ENABLE_PREVIEWS':'YES'})
testConfig=configs('test',{'PRODUCT_BUNDLE_IDENTIFIER':'$(APP_BUNDLE_ID).uitests','PRODUCT_NAME':'SymptoPageUITests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'SymptoPage','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
appTarget = uid('appTarget'); testTarget=uid('testTarget'); watchTarget=uid('watchTarget'); project=uid('project')
watchProxy=add('watchProxy','{isa = PBXContainerItemProxy; containerPortal = '+project+'; proxyType = 1; remoteGlobalIDString = '+watchTarget+'; remoteInfo = SymptoPageWatch;}')
watchDependency=add('watchDependency','{isa = PBXTargetDependency; target = '+watchTarget+'; targetProxy = '+watchProxy+';}')
proxy=add('proxy','{isa = PBXContainerItemProxy; containerPortal = '+project+'; proxyType = 1; remoteGlobalIDString = '+appTarget+'; remoteInfo = SymptoPage;}')
dependency=add('dependency','{isa = PBXTargetDependency; target = '+appTarget+'; targetProxy = '+proxy+';}')
add('appTarget','{isa = PBXNativeTarget; buildConfigurationList = '+appConfig+'; buildPhases = '+seq([sourcePhase,frameworkPhase,resourcePhase,embedWatch])+'; buildRules = (); dependencies = '+seq([watchDependency])+'; name = SymptoPage; productName = SymptoPage; productReference = '+appProduct+'; productType = "com.apple.product-type.application";}')
add('watchTarget','{isa = PBXNativeTarget; buildConfigurationList = '+watchConfig+'; buildPhases = '+seq([watchSource,watchFrameworks,watchResources])+'; buildRules = (); dependencies = (); name = SymptoPageWatch; productName = SymptoPageWatch; productReference = '+watchProduct+'; productType = "com.apple.product-type.application";}')
add('testTarget','{isa = PBXNativeTarget; buildConfigurationList = '+testConfig+'; buildPhases = '+seq([testSource,testFrameworks])+'; buildRules = (); dependencies = '+seq([dependency])+'; name = SymptoPageUITests; productName = SymptoPageUITests; productReference = '+testProduct+'; productType = "com.apple.product-type.bundle.ui-testing";}')
add('project','{isa = PBXProject; attributes = {LastUpgradeCheck = 1600; BuildIndependentTargetsInParallel = YES; TargetAttributes = {'+appTarget+' = {CreatedOnToolsVersion = 16.0;}; '+watchTarget+' = {CreatedOnToolsVersion = 16.0;}; '+testTarget+' = {CreatedOnToolsVersion = 16.0; TestTargetID = '+appTarget+';};};}; buildConfigurationList = '+projectConfig+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, pl, Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+seq([appTarget,watchTarget,testTarget])+';}')
path=root/'SymptoPage.xcodeproj'; path.mkdir(exist_ok=True)
(path/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project+';}\n')
schemes=path/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def buildref(id,name,product): return '<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'+id+'" BuildableName="'+product+'" BlueprintName="'+name+'" ReferencedContainer="container:SymptoPage.xcodeproj"/>'
appref=buildref(appTarget,'SymptoPage','SymptoPage.app'); testref=buildref(testTarget,'SymptoPageUITests','SymptoPageUITests.xctest')
(schemes/'SymptoPage.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+appref+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'+testref+'</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+appref+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+appref+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>\n')
watchref=buildref(watchTarget,'SymptoPageWatch','SymptoPageWatch.app')
(schemes/'SymptoPage Watch.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+watchref+'</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+watchref+'</BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>\n')
print('Generated',path)
