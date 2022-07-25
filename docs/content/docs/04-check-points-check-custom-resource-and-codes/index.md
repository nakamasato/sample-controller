---
title: '4. Checkpoint'
date: 2022-07-25T09:58:52+0900
draft: false
weight: 6
summary: Check the behavior at this point.
---

## [4. Checkpoint: Check custom resource and codes](https://github.com/nakamasato/sample-controller/commit/4f5a6c0fa2502ea7704c5d4e22cc6c84493593c6)

What to check:
- [x] Create CRD
- [x] Create CR
- [x] Read the CR from `sample-controller`

Steps:

1. Create `main.go` to retrieve custom resource `Foo`.

    <details><summary>main.go</summary>

    ```go
    package main

    import (
        "context"
        "flag"
        "path/filepath"

        "k8s.io/client-go/tools/clientcmd"
        "k8s.io/client-go/util/homedir"
        "k8s.io/klog/v2"

        clientset "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    )

    func main() {
        klog.InitFlags(nil)
        var kubeconfig *string

        if home := homedir.HomeDir(); home != "" {
            kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional)")
        } else {
            kubeconfig = flag.String("kubeconfig", "", "absolute path to kubeconfig file")
        }
        flag.Parse()

        config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
        if err != nil {
            klog.Fatalf("Error building kubeconfig: %s", err.Error())
        }

        exampleClient, err := clientset.NewForConfig(config)
        if err != nil {
            klog.Fatalf("Error building kubernetes clientset: %s", err.Error())
        }
        klog.Info(exampleClient)

        foos, err := exampleClient.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
        if err != nil {
            klog.Fatalf("listing foos %s %s", err.Error())
        }
        klog.Infof("length of foos is %d", len(foos.Items))
    }
    ```

    </details>

1. Build `sample-controller`

    ```
    go mod tidy
    go build
    ```

1. Test `sample-controller` (`main.go`).

    1. Register the CRD.

        ```
        kubectl apply -f config/crd/foos.yaml
        ```
    1. Run sample-controller.

        ```
        ./sample-controller
        ```

        Result: no `Foo` exists

        ```
        &{0xc000498d20 0xc00048c480}
        length of foos is 0
        ```

    1. Create sample foo (custom resource) with `config/sample/foo.yaml`.

        ```yaml
        apiVersion: example.com/v1alpha1
        kind: Foo
        metadata:
          name: foo-sample
        spec:
          deploymentName: foo-sample
          replicas: 1
        ```

        ```
        kubectl apply -f config/sample/foo.yaml
        ```

    1. Run the controller again.

        ```
        ./sample-controller
        &{0xc000496d20 0xc00048a480}
        length of foos is 1
        ```

    1. Clean up foo (custom resource).

        ```
        kubectl delete -f config/sample/foo.yaml
        ```
