#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
intatis_root="$(cd "$project_root/../Intatis" && pwd -P)"

fail() {
    print -u2 -- "error: $*"
    exit 1
}

require_text() {
    local source_file="$1"
    local expected_text="$2"
    /usr/bin/grep -Fq -- "$expected_text" "$source_file" \
        || fail "$source_file is missing required text: $expected_text"
}

[[ "$intatis_root" == "/Users/vita/Vitemis/Intatis" ]] \
    || fail "../Intatis resolved to unexpected root: $intatis_root"
[[ -f "$intatis_root/Package.swift" ]] \
    || fail "Intatis Package.swift is unavailable"

require_text "$project_root/Package.swift" '.package(path: "../Intatis")'
require_text "$project_root/Package.swift" 'name: "IntatisCodexRuntime"'
require_text "$project_root/project.yml" 'path: ../Intatis'
require_text "$project_root/project.yml" 'product: IntatisCodexRuntime'
require_text "$project_root/project.yml" 'PRODUCT_BUNDLE_IDENTIFIER: com.Vita0818.Councis'
require_text "$project_root/Apps/CouncisMac/Sources/AppConfig.swift" 'CouncisProductIdentity.applicationSupportDirectoryName'
require_text "$project_root/Apps/CouncisMac/Sources/AppConfig.swift" '"COUNCIS_CONFIG"'
require_text "$project_root/Apps/councis-cli/Sources/CLIConfig.swift" '"COUNCIS_MODEL"'
require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacApp.swift" 'IntatisHostApplication.configure(name: "Councis")'
require_text "$project_root/Apps/councis-cli/Sources/CouncisCLI.swift" 'IntatisHostApplication.configure(name: "Councis")'
require_text "$project_root/Apps/CouncisMac/Sources/CodeViewModel.swift" 'hostApplicationIdentity: hostApplicationIdentity'
require_text "$project_root/Apps/CouncisMac/Sources/CoworkViewModel.swift" 'hostApplicationIdentity: hostApplicationIdentity'
require_text "$project_root/Apps/councis-cli/Sources/CodexRuntimeCLI.swift" 'hostApplicationIdentity: hostApplicationIdentity'
require_text "$project_root/Apps/CouncisMac/Sources/CodeViewModel.swift" 'CodexAppServerSession'
require_text "$project_root/Apps/CouncisMac/Sources/CoworkViewModel.swift" 'CodexAppServerSession'
require_text "$project_root/Apps/councis-cli/Sources/Interactive.swift" 'codexRuntimeREPL'

if /usr/bin/grep -Fq '.package(path: "Vendor/' "$project_root/Package.swift"; then
    fail "Package.swift still selects a local vendored runtime dependency"
fi
if /usr/bin/grep -Eq 'library\(name: "Councis(Core|Protocol|Providers|AgentKernel|Cowork|Tools|MCP|Skills|Knowledge|SharedUI)' \
    "$project_root/Package.swift"; then
    fail "Package.swift still publishes a copied Councis runtime product"
fi

legacy_source_markers=(
    "$project_root/Packages/CouncisCore/Sources/IDs.swift"
    "$project_root/Packages/CouncisAgentKernel/Sources/AgentLoop.swift"
    "$project_root/Packages/CouncisCowork/Sources/Orchestrator.swift"
    "$project_root/Packages/CouncisTools/Sources/ToolProtocol.swift"
    "$project_root/Vendor/MCPClientSDK/Package.swift"
    "$project_root/Vendor/SwiftStreamingMarkdown/Package.swift"
    "$project_root/ThirdPartyStandards/OpenKnowledgeFormat/0.2/SPEC.md"
    "$project_root/Tests/MCPBM25ParityOracle/Cargo.toml"
    "$project_root/Tests/MCPConformance/official/run-official.sh"
)
for legacy_source in $legacy_source_markers; do
    [[ ! -e "$legacy_source" && ! -L "$legacy_source" ]] \
        || fail "copied snapshot source is still present: $legacy_source"
done

if /usr/bin/grep -R -E '^import Councis(Core|Protocol|Providers|Artifacts|Conversation|Tools|Knowledge|Skills|Permission|MCP|MCPStdio|AgentKernel|Cowork|Multimodal|SharedUI)$' \
    "$project_root/Apps/CouncisMac/Sources" \
    "$project_root/Apps/councis-cli/Sources"; then
    fail "active product source still imports a copied Councis implementation module"
fi

normal_startup_configuration_sources=(
    "$project_root/Apps/CouncisMac/Sources/AppConfig.swift"
    "$project_root/Apps/CouncisMac/Sources/Keychain.swift"
    "$project_root/Apps/councis-cli/Sources/CLIConfig.swift"
    "$project_root/Apps/councis-cli/Sources/CLIProviderCatalog.swift"
)
if /usr/bin/grep -E 'INTATIS_[A-Z0-9_]+|\.config/intatis|Application Support/Intatis|LegacyIntatisCompatibility' \
    $normal_startup_configuration_sources; then
    fail "normal Councis startup still reads an Intatis-owned configuration namespace"
fi
if /usr/bin/grep -R -E 'WorkspaceAccess\.(migrateLegacyBookmarks|clearLegacySessionStorage)' \
    "$project_root/Apps/CouncisMac/Sources"; then
    fail "normal Councis App startup still invokes automatic legacy Intatis workspace migration"
fi

require_text "$project_root/Apps/CouncisMac/Sources/CodeViewModel.swift" \
    '_ = try await runtime.runTurn('
require_text "$project_root/Apps/CouncisMac/Sources/CoworkViewModel.swift" \
    'runtime = try await self.codexSession('
require_text "$project_root/Apps/councis-cli/Sources/Interactive.swift" \
    'case .code, .cowork:'
require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacApp.swift" \
    'roleName: "judge"'
require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacApp.swift" \
    'permissionProfile: PermissionProfile.readOnly.rawValue'
require_text "$project_root/Apps/councis-cli/Sources/CodexRuntimeCLI.swift" \
    'roleName: "judge"'
require_text "$project_root/Apps/councis-cli/Sources/CodexRuntimeCLI.swift" \
    'sandbox: .readOnly'

require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacRootView.swift" \
    'Text("Councis")'
require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacRootView.swift" \
    '[.cowork]'
require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacRootView.swift" \
    'Choose Folder…'
require_text "$project_root/Apps/CouncisMac/Sources/CouncisMacRootView.swift" \
    'No Folder'
require_text "$project_root/Apps/councis-cli/Sources/Commands.swift" \
    'Councis CLI'

if /usr/bin/grep -R -E '"(Intatis|Message Intatis|Open Intatis Config)' \
    "$project_root/Apps/CouncisMac/Sources" \
    "$project_root/Apps/councis-cli/Sources"; then
    fail "active product source contains a user-visible Intatis brand literal"
fi

print -- "Councis identity is consistent: product overlay -> $intatis_root"
