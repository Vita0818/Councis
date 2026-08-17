#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"

if [[ -n "${RG_BIN:-}" && -x "$RG_BIN" ]]; then
    rg_path="$RG_BIN"
elif [[ -x "/Applications/ChatGPT.app/Contents/Resources/rg" ]]; then
    rg_path="/Applications/ChatGPT.app/Contents/Resources/rg"
else
    rg_path="$(command -v rg || true)"
fi
[[ -n "$rg_path" && -x "$rg_path" ]] \
    || { print -u2 -- "error: ripgrep is required"; exit 1; }

fail() {
    print -u2 -- "error: $*"
    exit 1
}

[[ -d "$project_root/Apps/CouncisMac" ]] \
    || fail "Apps/CouncisMac is missing"
[[ -d "$project_root/Apps/councis-cli" ]] \
    || fail "Apps/councis-cli is missing"
[[ -d "$project_root/Councis.icon" ]] \
    || fail "Councis.icon is missing"
[[ ! -e "$project_root/Apps/IntatisMac" ]] \
    || fail "legacy IntatisMac source path is still active"
[[ ! -e "$project_root/Apps/IntatisiOS" ]] \
    || fail "legacy iOS App source path is still active"
[[ ! -e "$project_root/Apps/CouncisiOS" ]] \
    || fail "iOS App source path is still active"
[[ ! -e "$project_root/Apps/intatis-cli" ]] \
    || fail "legacy CLI source path is still active"
[[ ! -e "$project_root/Intatis.icon" ]] \
    || fail "legacy icon source is still active"

/usr/bin/grep -Fq 'name: "Councis"' "$project_root/Package.swift" \
    || fail "SwiftPM package is not Councis"
/usr/bin/grep -Fq '.executable(name: "councis"' "$project_root/Package.swift" \
    || fail "SwiftPM does not expose the councis executable"
/usr/bin/grep -Fq 'name: Councis' "$project_root/project.yml" \
    || fail "Xcode project is not Councis"
/usr/bin/grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER: com.Vita0818.Councis' \
    "$project_root/project.yml" \
    || fail "shipping Bundle ID is not com.Vita0818.Councis"
/usr/bin/grep -Fq 'productName: Councis' "$project_root/project.yml" \
    || fail "shipping App product is not Councis.app"

if /usr/bin/grep -Eq \
    'CouncisMacAppStore:|CouncisiOS:|COUNCIS_MAC_APP_STORE' \
    "$project_root/project.yml"; then
    fail "a removed App Store or iOS product target is still declared"
fi

allowed_legacy_file() {
    case "$1" in
        .gitignore|\
        Apps/CouncisMac/Sources/AppConfig.swift|\
        Apps/CouncisMac/Sources/CoworkProjectSettings.swift|\
        Apps/CouncisMac/Sources/Keychain.swift|\
        Apps/CouncisMac/Sources/Workspace.swift|\
        Apps/councis-cli/Sources/CLIConfig.swift|\
        Apps/councis-cli/Sources/CLIProviderCatalog.swift|\
        Apps/councis-cli/Sources/MCPCLICommands.swift|\
        Apps/councis-cli/Tests/ProductBrandCompatibilityTests.swift|\
        Packages/CouncisAgentKernel/Sources/AuthorizationSidecar.swift|\
        Packages/CouncisAgentKernel/Tests/AuthorizationSidecarTests.swift|\
        Packages/CouncisCore/Sources/PathConfinement.swift|\
        Packages/CouncisCore/Sources/ProductIdentity.swift|\
        Packages/CouncisCore/Tests/ProductIdentityTests.swift|\
        Packages/CouncisMCP/Sources/MCPConfiguration.swift|\
        Packages/CouncisMCP/Sources/MCPSecretStore.swift|\
        Packages/CouncisMCP/Tests/ProductBrandCompatibilityTests.swift|\
        Packages/CouncisPermission/Sources/SecretScanner.swift|\
        Packages/CouncisProtocol/Sources/Leases.swift|\
        Packages/CouncisProviders/Sources/ProviderRequestAdapter.swift|\
        Packages/CouncisProviders/Tests/ProductBrandCompatibilityTests.swift|\
        Packages/CouncisSharedUI/Sources/ExecutionTracePresentation.swift|\
        Packages/CouncisSharedUI/Sources/MessageRendering/CouncisMessageRendererMode.swift|\
        Packages/CouncisTools/Sources/ShellGit.swift|\
        scripts/check-brand-boundary.sh)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

scan_paths=(
    Apps
    Packages
    Tests
    scripts
    Experiments
    .agents
    Package.swift
    project.yml
    Makefile
    .gitignore
    README.md
    ARCHITECTURE.md
    NOTICE.md
)

while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    relative="${path#$project_root/}"
    allowed_legacy_file "$relative" \
        || fail "unapproved active Intatis identity remains in $relative"
done < <(
    cd "$project_root"
    "$rg_path" -l -i 'intatis' "${scan_paths[@]}" \
        --glob '!*.pdf' \
        --glob '!*.png' \
        --glob '!*.zip' \
        --glob '!*.dmg' \
        | /usr/bin/sed "s#^#$project_root/#" \
        | /usr/bin/sort
)

while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    fail "active first-party path still contains Intatis: $path"
done < <(
    cd "$project_root"
    "$rg_path" --files Apps Packages Tests scripts Experiments .agents \
        | "$rg_path" -i '(^|/)intatis' || true
)

print -- "Councis brand boundary is consistent."
