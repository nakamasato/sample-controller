# Sample Controller

## Spec

Sample Controller manages a custom resource `Foo` and to keep a `Deployment` always running for a `Foo` instance.

- Group: example.com
- CR: `Foo`
- Version: `v1alpha1`

## Docs

https://nakamasato.github.io/sample-controller (by [Hugo](https://gohugo.io/))

## Quickstart

1. Install CRD. `kubectl apply -f config/crd/foos.yaml`
1. Start controller. `go run main.go`
1. Create CR. `kubectl apply -f config/sample/foo.yaml`
1. Check.

    ```
    kubectl get deploy
    NAME         READY   UP-TO-DATE   AVAILABLE   AGE
    foo-sample   1/1     1            1           103s
    ```
1. Clean up.
    1. Delete CR. `kubectl delete -f config/sample/foo.yaml`
    1. Stop controller
    1. Delete CRD. `kubectl delete -f config/crd/foos.yaml`

## Tools

- [code-generator](https://github.com/kubernetes/code-generator)

## Reference
- [sample-controller](https://github.com/kubernetes/sample-controller)
- [Kubernetes Deep Dive: Code Generation for CustomResources](https://cloud.redhat.com/blog/kubernetes-deep-dive-code-generation-customresources)
- [Generating ClientSet/Informers/Lister and CRD for Custom Resources | Writing K8S Operator - Part 1](https://www.youtube.com/watch?v=89PdRvRUcPU)
- [Implementing add and del handler func and token field in Kluster CRD | Writing K8S Operator - Part 2](https://www.youtube.com/watch?v=MOutOgdXfnA)
- [Calling DigitalOcean APIs on Kluster's add event | Writing K8S Operator - Part 3](https://www.youtube.com/watch?v=Wtyj0V4Inmg)
- [A deep dive into Kubernetes controllers](https://engineering.bitnami.com/articles/a-deep-dive-into-kubernetes-controllers.html)
- [Programming Kubernetes CRDs](https://insujang.github.io/2020-02-13/programming-kubernetes-crd/)
