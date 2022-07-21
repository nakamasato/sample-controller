---
title: '2. Generate codes'
date: 2022-07-22T07:39:41+0900
draft: false
weight: 4
summary: Generate Go codes with code-generator.
---

## [2. Generate codes](https://github.com/nakamasato/sample-controller/commit/7edfe41cb8921e6d1d12a0f79f9a279172661cf9)

1. Set `codeGeneratorDir` env var for `code-generator`.

    ```
    codeGeneratorDir=~/repos/kubernetes/code-generator
    ```

    If you already cloned, you can specify the directory.

1. Clone code-generator if you haven't cloned.

    ```
    git clone https://github.com/kubernetes/code-generator.git $codeGeneratorDir
    ```

    <details><summary>generate-groups.sh Usage</summary>

    ```
    "${codeGeneratorDir}"/generate-groups.sh
    Usage: generate-groups.sh <generators> <output-package> <apis-package> <groups-versions> ...

      <generators>        the generators comma separated to run (deepcopy,defaulter,client,lister,informer) or "all".
      <output-package>    the output package name (e.g. github.com/example/project/pkg/generated).
      <apis-package>      the external types dir (e.g. github.com/example/api or github.com/example/project/pkg/apis).
      <groups-versions>   the groups and their versions in the format "groupA:v1,v2 groupB:v1 groupC:v2", relative
                          to <api-package>.
      ...                 arbitrary flags passed to all generator binaries.


    Examples:
      generate-groups.sh all             github.com/example/project/pkg/client github.com/example/project/pkg/apis "foo:v1 bar:v1alpha1,v1beta1"
      generate-groups.sh deepcopy,client github.com/example/project/pkg/client github.com/example/project/pkg/apis "foo:v1 bar:v1alpha1,v1beta1"
    ```

    </details>

1. Generate codes (deepcopy, clientset, listers, and informers).

    ※ You need to replace `github.com/nakamasato/sample-controller` with your module name.

    ```
    module=github.com/nakamasato/sample-controller; "${codeGeneratorDir}"/generate-groups.sh all ${module}/pkg/client ${module}/pkg/apis example.com:v1alpha1 --go-header-file "${codeGeneratorDir}"/hack/boilerplate.go.txt --trim-path-prefix $module
    ```

    <details>

    The actually executed commands are the followings:

    ```
    GOBIN="$(go env GOBIN)"
    gobin="${GOBIN:-$(go env GOPATH)/bin}"
    ${gobin}/deepcopy-gen --input-dirs github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 -O zz_generated.deepcopy --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
    ${gobin}/client-gen --clientset-name versioned --input-base '' --input github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 --output-package github.com/nakamasato/sample-controller/pkg/client/clientset --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
    ${gobin}/lister-gen --input-dirs github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 --output-package github.com/nakamasato/sample-controller/pkg/client/listers --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
    ${gobin}/informer-gen --input-dirs github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 --versioned-clientset-package github.com/nakamasato/sample-controller/pkg/client/clientset/versioned --listers-package github.com/nakamasato/sample-controller/pkg/client/listers --output-package github.com/nakamasato/sample-controller/pkg/client/informers --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
    ```

    </deitals>

    -> `pkg/apis/example.com/v1alpha1/zz_generated.deepcopy.go`

    ```
    go mod tidy
    ```

    <details><summary>files</summary>

    ```
    tree .
    .
    ├── README.md
    ├── go.mod
    ├── go.sum
    └── pkg
        ├── apis
        │   └── example.com
        │       └── v1alpha1
        │           ├── doc.go
        │           ├── register.go
        │           ├── types.go
        │           └── zz_generated.deepcopy.go
        └── client
            ├── clientset
            │   └── versioned
            │       ├── clientset.go
            │       ├── doc.go
            │       ├── fake
            │       │   ├── clientset_generated.go
            │       │   ├── doc.go
            │       │   └── register.go
            │       ├── scheme
            │       │   ├── doc.go
            │       │   └── register.go
            │       └── typed
            │           └── example.com
            │               └── v1alpha1
            │                   ├── doc.go
            │                   ├── example.com_client.go
            │                   ├── fake
            │                   │   ├── doc.go
            │                   │   ├── fake_example.com_client.go
            │                   │   └── fake_foo.go
            │                   ├── foo.go
            │                   └── generated_expansion.go
            ├── informers
            │   └── externalversions
            │       ├── example.com
            │       │   ├── interface.go
            │       │   └── v1alpha1
            │       │       ├── foo.go
            │       │       └── interface.go
            │       ├── factory.go
            │       ├── generic.go
            │       └── internalinterfaces
            │           └── factory_interfaces.go
            └── listers
                └── example.com
                    └── v1alpha1
                        ├── expansion_generated.go
                        └── foo.go

    21 directories, 29 files
    ```

    <details>

1. Run `go mod tidy`.
