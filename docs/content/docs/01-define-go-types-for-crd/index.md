---
title: '1. Define Go types for CRD'
date: 2023-11-23T15:50:42+0900
draft: false
weight: 3
summary: Define Go types for Custom Resource Definition `Foo`.
---

## [1. Define Go types for CRD](https://github.com/nakamasato/sample-controller/commit/f760278fedc0203f140e931a0e9a311eff75abfe)

1. Create a directory.

    ```
    mkdir -p pkg/apis/example.com/v1alpha1
    ```

1. Create `pkg/apis/example.com/v1alpha1/doc.go`.

    ```go
    package v1alpha1
    ```

1. Create `pkg/apis/example.com/v1alpha1/types.go`.

    ```go
    package v1alpha1

    import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

    // Foo is a specification for a Foo resource
    type Foo struct {
        metav1.TypeMeta   `json:",inline"`
        metav1.ObjectMeta `json:"metadata,omitempty"`

        Spec   FooSpec   `json:"spec"`
        Status FooStatus `json:"status"`
    }

    // FooSpec is the spec for a Foo resource
    type FooSpec struct {
        DeploymentName string `json:"deploymentName"`
        Replicas       *int32 `json:"replicas"`
    }

    // FooStatus is the status for a Foo resource
    type FooStatus struct {
        AvailableReplicas int32 `json:"availableReplicas"`
    }

    // FooList is a list of Foo resources
    type FooList struct {
        metav1.TypeMeta `json:",inline"`
        metav1.ListMeta `json:"metadata"`

        Items []Foo `json:"items"`
    }
    ```

1. Create `pkg/apis/example.com/v1alpha1/register.go`.

    ```go
    package v1alpha1

    import (
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
        "k8s.io/apimachinery/pkg/runtime"
        "k8s.io/apimachinery/pkg/runtime/schema"
    )

    var (
        // SchemeBuilder initializes a scheme builder
        SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
        // AddToScheme is a global function that registers this API group & version to a scheme
        AddToScheme = SchemeBuilder.AddToScheme
    )

    // SchemeGroupVersion is group version used to register these objects.
    var SchemeGroupVersion = schema.GroupVersion{
        Group:   "example.com",
        Version: "v1alpha1",
    }

    func Resource(resource string) schema.GroupResource {
        return SchemeGroupVersion.WithResource(resource).GroupResource()
    }

    func addKnownTypes(scheme *runtime.Scheme) error {
        scheme.AddKnownTypes(SchemeGroupVersion,
            &Foo{},
            &FooList{},
        )
        metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
        return nil
    }
    ```

    - clientset, which we'll generate in the next section, will uses `AddToScheme` to register our custom resource `Foo`.
    - `Scheme` defines methods for serializing and deserializing API objects, a type registry for converting group, version, and kind information to and from Go schemas, and mappings between Go schemas of different versions.

1. Run `go mod tidy`.

    > go mod tidy ensures that the go.mod file matches the source code in the module. It adds any missing module requirements necessary to build the current module’s packages and dependencies, and it removes requirements on modules that don’t provide any relevant packages. It also adds any missing entries to go.sum and removes unnecessary entries.

    [go mod tidy](https://go.dev/ref/mod#go-mod-tidy)

※ At this point, `pkg/apis/example.com/v1alpha1/register.go` would have an error `cannot use &(FooList literal) (value of type *FooList) as "k8s.io/apimachinery/pkg/runtime".Object value in argument to scheme.AddKnownTypes: missing method DeepCopyObject` as `DeepCopyObject` will be generated in the next step.
