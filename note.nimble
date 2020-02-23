# Package

version       = "0.1.0"
author        = "jiro4989"
description   = "A note cli for you"
license       = "MIT"
srcDir        = "src"
bin           = @["note"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.0.6"
requires "cligen >= 0.9.32"
requires "parsetoml >= 0.5.0"
