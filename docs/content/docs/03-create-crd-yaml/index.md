---
title: '3. Create CRD yaml file'
date: 2022-07-25T05:45:49+0900
draft: false
weight: 5
summary: Create CustomResourceDefinition yaml file manually.
---

## [3. Create CRD yaml file](https://github.com/nakamasato/sample-controller/commit/6e4cb9586f82747632a0c5e48e86100b1370cf95)

`config/crd/example.com_foos.yaml`:
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: foos.example.com
spec:
  group: example.com
  names:
    kind: Foo
    listKind: FooList
    plural: foos
    singular: foo
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
                deploymentName:
                  type: string
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 10
            status:
              type: object
              properties:
                availableReplicas:
                  type: integer
```

※ You can also use [controller-gen](https://github.com/kubernetes-sigs/controller-tools/tree/master/cmd/controller-gen), which is a subproject of the kubebuilder project, to generate CRD yaml.
