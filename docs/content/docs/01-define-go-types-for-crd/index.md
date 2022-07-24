---
title: '1. Define Go types for CRD'
date: 2022-07-25T05:52:30+0900
draft: false
weight: 3
summary: Define Go types for Custom Resource Definition `Foo`.
---

## [1. Define Go types for CRD](https://github.com/nakamasato/sample-controller/commit/8043cc51abc9e8884047bcda6ce6de02c8f16315)

1. Create a directory.

    ```
    mkdir -p pkg/apis/example.com/v1alpha1
    ```

1. Create `pkg/apis/example.com/v1alpha1/doc.go`.

    ```go
    // +k8s:deepcopy-gen=package
    // +groupName=example.com

    package v1alpha1
    ```
1. Create `pkg/apis/example.com/v1alpha1/types.go`.
    ```go
    package v1alpha1

    import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

    // These const variables are used in our custom controller.
    const (
        GroupName string = "example.com"
        Kind      string = "Foo"
        Version   string = "v1alpha1"
        Plural    string = "foos"
        Singluar  string = "foo"
        ShortName string = "foo"
        Name      string = Plural + "." + GroupName
    )

    // +genclient
    // +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

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

    // +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

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
        Group:   GroupName,
        Version: Version,
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

※ At this point, `pkg/apis/example.com/v1alpha1/register.go` would have an error `cannot use &(FooList literal) (value of type *FooList) as "k8s.io/apimachinery/pkg/runtime".Object value in argument to scheme.AddKnownTypes: missing method DeepCopyObject` as `DeepCopyObject` will be generated in the next step.
