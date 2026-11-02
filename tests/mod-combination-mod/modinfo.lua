name = "Hitsugaya isolated mod combination review"
description = "Development tests. Enable only in a disposable test world."
author = "Local development"
version = "1"
api_version = 10
dst_compatible = true
server_only_mod = true
all_clients_require_mod = false
priority = -2147483647
configuration_options = {
    {name="isolated_review",label="Disposable test world",default=false,options={{description="Disabled",data=false},{description="Enabled",data=true}}},
    {name="expected_workshop_mods",label="Expected workshop count",default=29,options={{description="All 29",data=29},{description="Single-mod control",data=1}}},
}
