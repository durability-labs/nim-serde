# Package

version = "2.0.0"
author = "nim-serde authors"
description = "Easy-to-use serialization capabilities (currently json only)."
license = "MIT"
skipDirs = @["tests"]

# Dependencies
requires "questionable >= 0.10.13 & < 0.11.0"
requires "stint"
requires "stew"
requires "asynctest >= 0.5.1 & < 0.6.0"
