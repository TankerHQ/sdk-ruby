<a href="#readme"><img src="https://raw.githubusercontent.com/TankerHQ/spec/master/img/tanker-logotype-blue-nomargin-350.png" alt="Tanker logo" width="175" /></a>

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

# Tanker Ruby SDK

## Overview

The Tanker SDK provides an easy-to-use SDK allowing you to protect your users' data.

This repository only contains Ruby bindings. The core library can be found in the [TankerHQ/sdk-native GitHub project](https://github.com/TankerHQ/sdk-native).

## Known issues

- Deadlock at exit: thread, processes, mutexes and FFI have a complex interaction which can cause deadlocks if a mutex is acquired before a fork.
  In issue `E2EE-162`, some ruby callbacks were never called, find [here](https://github.com/ffi/ffi/compare/master...blastrock:ffi:stop-deadlock) a potential FFI fix.

## Contributing

We are actively working to allow external developers to build and test this project
from source. That being said, we welcome feedback of any kind. Feel free to
open issues on the GitHub bug tracker.

Running the tests: `bundle exec rake spec`

Checking vulnerabilities in the dependencies: `bundle exec bundle-audit check --update`

## Documentation

See the [API documentation](https://docs.tanker.io/latest/api/core/ruby).
