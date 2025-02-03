[![Local](https://github.com/FallenPhoenix8/vapor-comments/actions/workflows/swift.yml/badge.svg)](https://github.com/FallenPhoenix8/vapor-comments/actions/workflows/swift.yml)
## Running dev scripts

In order to run the dev scripts, you need to have `watchexec` installed on your system.
If you are using brew package manager, it can be installed with following command:

```zsh
brew install watchexec
```

It's not possible to run both backend and frontend in a live development version. There are 2 dev scripts.
In order to run backend development script, execute the following script:

```zsh
sh ./dev-backend.sh
```

And in order to run frontend development script, execute this script:

```zsh
sh ./dev-frontend.sh
```

## Building for production

You can build the project using `build.sh` script.

```zsh
sh ./build.sh
```
