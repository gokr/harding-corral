## ==========================================================================
## Harding Corral Library
## SQL-first data mapper and table gateway for Harding
## ==========================================================================

import harding/core/types
import harding/packages/package_api

const
  BootstrapHrd = staticRead("../../lib/corral/Bootstrap.hrd")
  CorralHrd = staticRead("../../lib/corral/Corral.hrd")

proc installCorral*(interp: var Interpreter) =
  let spec = HardingPackageSpec(
    name: "Corral",
    version: "0.1.0",
    bootstrapPath: "lib/corral/Bootstrap.hrd",
    sources: @[
      (path: "lib/corral/Bootstrap.hrd", source: BootstrapHrd),
      (path: "lib/corral/Corral.hrd", source: CorralHrd)
    ],
    registerPrimitives: nil
  )

  discard installPackage(interp, spec)
