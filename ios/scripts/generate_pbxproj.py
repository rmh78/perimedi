#!/usr/bin/env python3
"""Generate ios/PeriMedi.xcodeproj/project.pbxproj from the app source tree."""
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJ = ROOT / "PeriMedi.xcodeproj"
APP = ROOT / "PeriMedi"
UITESTS = ROOT / "PeriMediUITests"


def hid(name: str) -> str:
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def main() -> None:
    swift = sorted(p.relative_to(APP) for p in APP.rglob("*.swift"))
    xcstrings = APP / "Resources" / "Localizable.xcstrings"

    ids = {
        "project": hid("project"),
        "app_target": hid("app_target"),
        "sources": hid("phase_sources"),
        "resources": hid("phase_resources"),
        "frameworks": hid("phase_frameworks"),
        "group_root": hid("group_root"),
        "group_app": hid("group_app"),
        "group_products": hid("group_products"),
        "product": hid("product_app"),
        "config_list_proj": hid("xc_list_proj"),
        "config_list_app": hid("xc_list_app"),
        "debug_proj": hid("xc_debug_proj"),
        "release_proj": hid("xc_release_proj"),
        "debug_app": hid("xc_debug_app"),
        "release_app": hid("xc_release_app"),
        "pkg_ref": hid("pkg_ref"),
        "pkg_prod": hid("pkg_prod"),
        "assets": hid("file_assets"),
        "strings": hid("file_strings"),
        "entitlements": hid("file_entitlements"),
        "info": hid("file_info"),
        "ui_target": hid("ui_target"),
        "ui_product": hid("product_ui"),
        "ui_sources": hid("phase_ui_sources"),
        "ui_frameworks": hid("phase_ui_frameworks"),
        "ui_resources": hid("phase_ui_resources"),
        "ui_group": hid("group_ui"),
        "config_list_ui": hid("xc_list_ui"),
        "debug_ui": hid("xc_debug_ui"),
        "release_ui": hid("xc_release_ui"),
        "ui_proxy": hid("proxy_ui"),
        "ui_dep": hid("dep_ui"),
    }

    file_refs = []
    build_files = []
    source_builds = []
    resource_builds = []

    for rel in swift:
        key = hid(f"swift:{rel}")
        bkey = hid(f"build:{rel}")
        file_refs.append(
            f"\t\t{key} /* {rel.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel.name}; sourceTree = \"<group>\"; }};"
        )
        build_files.append(
            f"\t\t{bkey} /* {rel.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {key} /* {rel.name} */; }};"
        )
        source_builds.append(f"\t\t\t\t{bkey} /* {rel.name} in Sources */,")
        ids[f"ref:{rel}"] = key

    file_refs.append(
        f"\t\t{ids['product']} /* PeriMedi.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PeriMedi.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    file_refs.append(
        f"\t\t{ids['assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
    )
    file_refs.append(
        f"\t\t{ids['strings']} /* Localizable.xcstrings */ = {{isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Localizable.xcstrings; sourceTree = \"<group>\"; }};"
    )
    file_refs.append(
        f"\t\t{ids['entitlements']} /* PeriMedi.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = PeriMedi.entitlements; sourceTree = \"<group>\"; }};"
    )
    file_refs.append(
        f"\t\t{ids['info']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};"
    )

    assets_build = hid("build:assets")
    strings_build = hid("build:strings")
    pkg_build = hid("build:pkg")
    build_files.append(
        f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids['assets']} /* Assets.xcassets */; }};"
    )
    build_files.append(
        f"\t\t{strings_build} /* Localizable.xcstrings in Resources */ = {{isa = PBXBuildFile; fileRef = {ids['strings']} /* Localizable.xcstrings */; }};"
    )
    build_files.append(
        f"\t\t{pkg_build} /* PeriMediDomain in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids['pkg_prod']} /* PeriMediDomain */; }};"
    )
    resource_builds.append(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
    resource_builds.append(f"\t\t\t\t{strings_build} /* Localizable.xcstrings in Resources */,")

    # Group children by directory
    dirs: dict[str, list[str]] = {}
    for rel in swift:
        dirs.setdefault(str(rel.parent), []).append(str(rel))

    group_ids = {d: hid(f"group:{d}") for d in dirs}

    group_blocks = []
    # Resources group
    res_id = hid("group:Resources")
    group_blocks.append(
        f"""\t\t{res_id} /* Resources */ = {{
			isa = PBXGroup;
			children = (
				{ids['assets']} /* Assets.xcassets */,
				{ids['strings']} /* Localizable.xcstrings */,
				{ids['entitlements']} /* PeriMedi.entitlements */,
				{ids['info']} /* Info.plist */,
			);
			path = Resources;
			sourceTree = "<group>";
		}};"""
    )

    app_children = [f"{res_id} /* Resources */,"]
    for d, files in sorted(dirs.items()):
        children = []
        for rel in files:
            children.append(f"{ids[f'ref:{rel}']} /* {Path(rel).name} */,")
        if d == ".":
            app_children.extend(children)
            continue
        gid = group_ids[d]
        parts = Path(d).parts
        child_block = "\n".join("\t\t\t\t" + c for c in children)
        group_blocks.append(
            f"""\t\t{gid} /* {parts[-1]} */ = {{
			isa = PBXGroup;
			children = (
{child_block}
			);
			path = {parts[-1]};
			sourceTree = "<group>";
		}};"""
        )
        if len(parts) == 1:
            app_children.append(f"{gid} /* {parts[-1]} */,")

    # Nested App/Features/Persistence: Features has Cycle, Month, More, Sheets
    # The simple grouping above puts each directory as a sibling under PeriMedi
    # if we only add top-level dirs to app_children. Nested dirs like Features/Cycle
    # are their own groups with path = last component, so they MUST be children of Features.
    # Rebuild groups properly.

    # Simpler: flatten all swift files into one PeriMedi group with path = PeriMedi
    # and use full relative path on each file ref.

    # Override with flat group — more reliable for xcodebuild.
    flat_children = [
        f"{ids['assets']} /* Assets.xcassets */,",
        f"{ids['strings']} /* Localizable.xcstrings */,",
        f"{ids['entitlements']} /* PeriMedi.entitlements */,",
        f"{ids['info']} /* Info.plist */,",
    ]
    file_refs_flat = [
        f"\t\t{ids['product']} /* PeriMedi.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PeriMedi.app; sourceTree = BUILT_PRODUCTS_DIR; }};",
        f"\t\t{ids['assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = \"<group>\"; }};",
        f"\t\t{ids['strings']} /* Localizable.xcstrings */ = {{isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Resources/Localizable.xcstrings; sourceTree = \"<group>\"; }};",
        f"\t\t{ids['entitlements']} /* PeriMedi.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Resources/PeriMedi.entitlements; sourceTree = \"<group>\"; }};",
        f"\t\t{ids['info']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Resources/Info.plist; sourceTree = \"<group>\"; }};",
    ]
    for rel in swift:
        key = ids[f"ref:{rel}"]
        file_refs_flat.append(
            f"\t\t{key} /* {rel} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel.as_posix()}; sourceTree = \"<group>\"; }};"
        )
        flat_children.append(f"{key} /* {rel} */,")

    ui_swift = sorted(p.relative_to(UITESTS) for p in UITESTS.rglob("*.swift")) if UITESTS.exists() else []
    ui_file_refs = [
        f"\t\t{ids['ui_product']} /* PeriMediUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PeriMediUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
    ]
    ui_build_files = []
    ui_source_builds = []
    ui_group_children = []
    for rel in ui_swift:
        key = hid(f"ui-swift:{rel}")
        bkey = hid(f"ui-build:{rel}")
        ui_file_refs.append(
            f"\t\t{key} /* {rel} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel.as_posix()}; sourceTree = \"<group>\"; }};"
        )
        ui_build_files.append(
            f"\t\t{bkey} /* {rel.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {key} /* {rel} */; }};"
        )
        ui_source_builds.append(f"\t\t\t\t{bkey} /* {rel.name} in Sources */,")
        ui_group_children.append(f"{key} /* {rel} */,")

    nl = "\n"
    build_files_block = nl.join(build_files + ui_build_files)
    file_refs_block = nl.join(file_refs_flat + ui_file_refs)
    app_children_block = nl.join("\t\t\t\t" + c for c in flat_children)
    resource_block = nl.join(resource_builds)
    source_block = nl.join(source_builds)
    ui_source_block = nl.join(ui_source_builds)
    ui_group_block = nl.join("\t\t\t\t" + c for c in ui_group_children)

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_files_block}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs_block}
/* End PBXFileReference section */

/* Begin PBXContainerItemProxy section */
		{ids['ui_proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids['app_target']};
			remoteInfo = PeriMedi;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFrameworksBuildPhase section */
		{ids['frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{pkg_build} /* PeriMediDomain in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['ui_frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{ids['group_root']} = {{
			isa = PBXGroup;
			children = (
				{ids['group_app']} /* PeriMedi */,
				{ids['ui_group']} /* PeriMediUITests */,
				{ids['group_products']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids['group_app']} /* PeriMedi */ = {{
			isa = PBXGroup;
			children = (
{app_children_block}
			);
			path = PeriMedi;
			sourceTree = "<group>";
		}};
		{ids['group_products']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids['product']} /* PeriMedi.app */,
				{ids['ui_product']} /* PeriMediUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{res_id} /* Resources */ = {{
			isa = PBXGroup;
			children = (
			);
			name = Resources;
			sourceTree = "<group>";
		}};
		{ids['ui_group']} /* PeriMediUITests */ = {{
			isa = PBXGroup;
			children = (
{ui_group_block}
			);
			path = PeriMediUITests;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids['app_target']} /* PeriMedi */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['config_list_app']} /* Build configuration list for PBXNativeTarget "PeriMedi" */;
			buildPhases = (
				{ids['sources']} /* Sources */,
				{ids['frameworks']} /* Frameworks */,
				{ids['resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = PeriMedi;
			packageProductDependencies = (
				{ids['pkg_prod']} /* PeriMediDomain */,
			);
			productName = PeriMedi;
			productReference = {ids['product']} /* PeriMedi.app */;
			productType = "com.apple.product-type.application";
		}};
		{ids['ui_target']} /* PeriMediUITests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['config_list_ui']} /* Build configuration list for PBXNativeTarget "PeriMediUITests" */;
			buildPhases = (
				{ids['ui_sources']} /* Sources */,
				{ids['ui_frameworks']} /* Frameworks */,
				{ids['ui_resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{ids['ui_dep']} /* PBXTargetDependency */,
			);
			name = PeriMediUITests;
			productName = PeriMediUITests;
			productReference = {ids['ui_product']} /* PeriMediUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{ids['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2600;
				LastUpgradeCheck = 2600;
			}};
			buildConfigurationList = {ids['config_list_proj']} /* Build configuration list for PBXProject "PeriMedi" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				de,
				Base,
			);
			mainGroup = {ids['group_root']};
			packageReferences = (
				{ids['pkg_ref']} /* XCLocalSwiftPackageReference "." */,
			);
			productRefGroup = {ids['group_products']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids['app_target']} /* PeriMedi */,
				{ids['ui_target']} /* PeriMediUITests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids['resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{resource_block}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['ui_resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{ids['sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{source_block}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['ui_sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{ui_source_block}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{ids['ui_dep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids['app_target']} /* PeriMedi */;
			targetProxy = {ids['ui_proxy']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		{ids['debug_proj']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{ids['release_proj']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{ids['debug_app']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_STYLE = Manual;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = PeriMedi/Resources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = app.perimedi.ios;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Debug;
		}};
		{ids['release_app']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_STYLE = Manual;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = PeriMedi/Resources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = app.perimedi.ios;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Release;
		}};
		{ids['debug_ui']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_STYLE = Manual;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
				PRODUCT_BUNDLE_IDENTIFIER = app.perimedi.ios.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_TARGET_NAME = PeriMedi;
				USES_XCTRUNNER = YES;
			}};
			name = Debug;
		}};
		{ids['release_ui']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_STYLE = Manual;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
				PRODUCT_BUNDLE_IDENTIFIER = app.perimedi.ios.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_TARGET_NAME = PeriMedi;
				USES_XCTRUNNER = YES;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{ids['config_list_proj']} /* Build configuration list for PBXProject "PeriMedi" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['debug_proj']} /* Debug */,
				{ids['release_proj']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['config_list_app']} /* Build configuration list for PBXNativeTarget "PeriMedi" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['debug_app']} /* Debug */,
				{ids['release_app']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['config_list_ui']} /* Build configuration list for PBXNativeTarget "PeriMediUITests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['debug_ui']} /* Debug */,
				{ids['release_ui']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{ids['pkg_ref']} /* XCLocalSwiftPackageReference "." */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = .;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{ids['pkg_prod']} /* PeriMediDomain */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {ids['pkg_ref']} /* XCLocalSwiftPackageReference "." */;
			productName = PeriMediDomain;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {ids['project']} /* Project object */;
}}
"""
    # unused
    _ = xcstrings
    _ = group_blocks

    PROJ.mkdir(parents=True, exist_ok=True)
    (PROJ / "project.pbxproj").write_text(pbx)
    scheme_dir = PROJ / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "PeriMedi.xcscheme").write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference
               BuildableIdentifier="primary"
               BlueprintIdentifier="{ids['app_target']}"
               BuildableName="PeriMedi.app"
               BlueprintName="PeriMedi"
               ReferencedContainer="container:PeriMedi.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['ui_target']}"
               BuildableName = "PeriMediUITests.xctest"
               BlueprintName = "PeriMediUITests"
               ReferencedContainer = "container:PeriMedi.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference
            BuildableIdentifier="primary"
            BlueprintIdentifier="{ids['app_target']}"
            BuildableName="PeriMedi.app"
            BlueprintName="PeriMedi"
            ReferencedContainer="container:PeriMedi.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference
            BuildableIdentifier="primary"
            BlueprintIdentifier="{ids['app_target']}"
            BuildableName="PeriMedi.app"
            BlueprintName="PeriMedi"
            ReferencedContainer="container:PeriMedi.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
"""
    )
    print(f"Wrote {PROJ / 'project.pbxproj'} ({len(swift)} app swift, {len(ui_swift)} UI test swift)")


if __name__ == "__main__":
    main()
