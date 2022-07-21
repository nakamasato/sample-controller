---
title: '4. Checkpoint'
date: 2019-02-11T19:27:37+10:00
draft: false
weight: 6
summary: Check the behavior at this point.
---

## [4. Checkpoint: Check custom resource and codes](https://github.com/nakamasato/sample-controller/commit/40b2f650a30fe71cd477575842987308480a7631)

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
        "fmt"
        "log"
        "path/filepath"

        "k8s.io/client-go/tools/clientcmd"
        "k8s.io/client-go/util/homedir"

        client "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    )

    func main() {
        var kubeconfig *string

        if home := homedir.HomeDir(); home != "" {
            kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional)")
        } else {
            kubeconfig = flag.String("kubeconfig", "", "absolute path to kubeconfig file")
        }
        flag.Parse()

        config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
        if err != nil {
            log.Printf("Building config from flags, %s", err.Error())
        }

        clientset, err := client.NewForConfig(config)
        if err != nil {
            log.Printf("getting client set %s\n", err.Error())
        }
        fmt.Println(clientset)

        foos, err := clientset.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
        if err != nil {
            log.Printf("listing foos %s\n", err.Error())
        }
        fmt.Printf("length of foos is %d\n", len(foos.Items))
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
