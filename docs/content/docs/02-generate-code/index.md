---
title: '2. Generate codes'
date: 2022-10-17T09:45:18+0900
draft: false
weight: 4
summary: Generate Go codes with code-generator.
---

## [2. Generate codes](https://github.com/nakamasato/sample-controller/commit/1adde64c0cca29700e40e72234f0eebce7ba584e)

### 2.1. Overview

[code-generator](https://github.com/kubernetes/code-generator) is Golang code-generators used to implement Kubernetes-style API types (generate deepcopy, clientset, informer, lister)

1. **DeepCopy** is necessary to implement [runtime.Object](https://pkg.go.dev/k8s.io/apimachinery/pkg/runtime#Object) interface.
1. **Clientset** is to access a (custom) resource in Kubernetes API.
1. **Lister** is to list custom resources in a in-memory `cache.Indexer` with List function.
1. **Informer** is used to capture changes of a target custom resource, which is usually used in a custom controller.

### 2.2. Prepare code-generator

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


### 2.3. Add markers

1. Mark the package `pkg/api/doc.go`.

    ```diff
    +// +k8s:deepcopy-gen=package
    +// +groupName=example.com

     package v1alpha1
    ```

    1. `// +k8s:deepcopy-gen=package`: generate DeepCopy for the entire package
    1. `// +groupName=example.com`: used in the fake client as the full group name (defaults to the package name) ([client-gen](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/generating-clientset.md))

1. Mark the types (`Foo` and `FooList`) in `pkg/api/types.go`.

    ```diff
    +// +genclient
    +// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

     // Foo is a specification for a Foo resource
     type Foo struct {
     ...
    ```

    ```diff
    +// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

     // FooList is a list of Foo resources
     type FooList struct {
    ```

    1. `// +genclient`: generate default client verb functions (create, update, delete, get, list, update, patch, watch and depending on the existence of .Status field in the type the client is generated for also updateStatus). (More details: [Generation and release cycle of clientset](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/generating-clientset.md))
    1. `+k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object`: generate DeepCopyObject with the given interfaces as return types.

1. For more about comment tags.
    1. [deepcopy-gen](https://pkg.go.dev/k8s.io/gengo/examples/deepcopy-gen)
    1. [client-gen](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/generating-clientset.md)

### 2.4. Generate codes

1. Generate codes (deepcopy, clientset, listers, and informers).

    ※ You need to replace `github.com/nakamasato/sample-controller` with your module name.

    ```
    module=github.com/nakamasato/sample-controller; "${codeGeneratorDir}"/generate-groups.sh all ${module}/pkg/generated ${module}/pkg/apis example.com:v1alpha1 --go-header-file "${codeGeneratorDir}"/hack/boilerplate.go.txt --trim-path-prefix $module --output-base ./
    ```

    - `--output-base ./` is necessary to generate the codes under the current directory
    - `--trim-path-prefix $module` is necessary to generate under the path `pkg/generated/...`

    The command above consists of the following commands:

    1. Set `gobin`

        ```
        GOBIN="$(go env GOBIN)"
        gobin="${GOBIN:-$(go env GOPATH)/bin}"
        ```
    1. **deepcopy-gen**:
        ```
        ${gobin}/deepcopy-gen --input-dirs github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 -O zz_generated.deepcopy --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
        ```
    1. **client-gen**:
        ```
        ${gobin}/client-gen --clientset-name versioned --input-base '' --input github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 --output-package github.com/nakamasato/sample-controller/pkg/generated/clientset --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
        ```
    1. **lister-gen**:
        ```
        ${gobin}/lister-gen --input-dirs github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 --output-package github.com/nakamasato/sample-controller/pkg/generated/listers --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
        ```
    1. **informer-gen**:
        ```
        ${gobin}/informer-gen --input-dirs github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1 --versioned-clientset-package github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned --listers-package github.com/nakamasato/sample-controller/pkg/generated/listers --output-package github.com/nakamasato/sample-controller/pkg/generated/informers --go-header-file /Users/m.naka/repos/kubernetes/code-generator/hack/boilerplate.go.txt --trim-path-prefix github.com/nakamasato/sample-controller
        ```

    The following files are generated:
    - `pkg/apis/example.com/v1alpha1/zz_generated.deepcopy.go`
    - `pkg/generated/`
        - `clientset`
        - `informers`
        - `listers`

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
        └── generated
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

    </details>

    As is mentioned in the previous section, `AddToScheme` is called in `pkg/generated/clientset/versioned/scheme/register.go` to register our new api version `example.com/v1alpha1`, which includes `Foo` kind.

    ```go
    var localSchemeBuilder = runtime.SchemeBuilder{
        examplev1alpha1.AddToScheme,
    }
    ...
    var AddToScheme = localSchemeBuilder.AddToScheme

    func init() {
        v1.AddToGroupVersion(Scheme, schema.GroupVersion{Version: "v1"})
        utilruntime.Must(AddToScheme(Scheme))
    }
    ```

1. Run `go mod tidy`.
