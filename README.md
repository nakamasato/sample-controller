# Sample Controller

## Spec

- Group: example.com
- CR: `Foo`
- Version: `v1alpha1`

## Tools

- [controller-gen](https://github.com/kubernetes-sigs/controller-tools/tree/master/cmd/controller-gen)
- [code-generator](https://github.com/kubernetes/code-generator)

## 0. Init module

```
go mod init
```

## 1. Define CRD

```
mkdir -p pkg/apis/example.com/v1beta1
```

1. Create `pkg/apis/example.com/v1beta1/doc.go`

    ```go
    // +k8s:deepcopy-gen=package
    // +k8s:defaulter-gen=TypeMeta
    // +groupName=example.com

    package v1alpha1
    ```
1. Create `pkg/apis/example.com/v1beta1/types.go`
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

    // Foo describes a Foo custom resource.
    type Foo struct {
        metav1.TypeMeta   `json:",inline"`
        metav1.ObjectMeta `json:"metadata,omitempty"`

        Spec   FooSpec `json:"spec"`
        Status FooStatus  `json:"status,omitempty"`
    }

    // FooSpec specifies the 'spec' of Foo CRD.
    type FooSpec struct {
        DeploymentName        string `json:"deploymentName"`
        Replicas *int32 `json:"replicas"`
    }

    // FooStatus is the status for a Foo resource
    type FooStatus struct {
        AvailableReplicas int32 `json:"availableReplicas"`
    }

    // +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

    // FooList is a list of Foo resources.
    type FooList struct {
        metav1.TypeMeta `json:",inline"`
        metav1.ListMeta `json:"metadata"`

        Items []Foo `json:"items"`
    }
    ```
1. Create `pkg/apis/example.com/v1beta1/register.go`
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
        Group:   "foo",
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

## 2. Generate code

1. Set `execDir` env var for `code-generator`.

    ```
    execDir=~/repos/kubernetes/code-generator
    ```

1. Clone code-generator.

    ```
    git clone https://github.com/kubernetes/code-generator.git $execDir
    ```

    <details><summary>generate-groups.sh Usage</summary>

    ```
    "${execDir}"/generate-groups.sh
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

1. Generate codes.

    ```
    "${execDir}"/generate-groups.sh all github.com/nakamasato/sample-controller/pkg/client github.com/nakamasato/sample-controller/pkg/apis example.com:v1alpha1 --go-header-file "${execDir}"/hack/boilerplate.go.txt
    ```

    <details><summary>files</summary>

    ```
    tree .
    .
    ├── README.md
    ├── go.mod
    ├── go.sum
    ├── main.go
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

    21 directories, 30 files
    ```

    <details>

## 3. Generate CRD yaml files

```
controller-gen paths=github.com/nakamasato/sample-controller/pkg/apis/foo/v1alpha1 crd:trivialVersions=true crd:crdVersions=v1
```

will create `config/crd/example.com_foos.yaml`

## 4. Checkpoint: Custom Resource is ready

1. Create `main.go`.

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

1. Build

    ```
    go mod tidy
    go build
    ```
1. Test `main.go`.

    ```
    kubectl apply -f config/crd/example.com_foos.yaml
    ```

    ```
    ./sample-controller
    ```

    Result:

    ```
    &{0xc000498d20 0xc00048c480}
    length of foos is 0
    ```

    Create sample foo with `config/sample/foo.yaml`

    ```yaml
    apiVersion: example.com/v1alpha1
    kind: Foo
    metadata:
    name: foo-sample
    spec:
    deploymentName: foo-sample
    replicas: 1
    ```

    Run the controller again

    ```
    ./sample-controller
    &{0xc000496d20 0xc00048a480}
    length of foos is 1
    ```

## 4. Write controller

### 4.1. Create Controller

<details><summary>`pkg/controller/foo.go`</summary>

```go
package controller

import (
	"log"
	"time"

	clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
	finformer "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions/example.com/v1alpha1"
	flister "github.com/nakamasato/sample-controller/pkg/client/listers/example.com/v1alpha1"

	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/util/workqueue"
)

type Controller struct {
	// clientset for custom resource Foo
	client clientset.Interface
	// foo has synced
	fooSynced cache.InformerSynced
	// lister
	fLister flister.FooLister
	// queue
	workqueue workqueue.RateLimitingInterface
}

func NewController(client clientset.Interface, fooInformer finformer.FooInformer) *Controller {
	c := &Controller{
		client: client,
		fooSynced: fooInformer.Informer().HasSynced,
		fLister: fooInformer.Lister(),
		workqueue: workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
	}

	fooInformer.Informer().AddEventHandler(
		cache.ResourceEventHandlerFuncs{
			AddFunc: c.handleAdd,
			DeleteFunc: c.handleDelete,
		},
	)
	return c
}

func (c *Controller) Run(ch chan struct{}) error {
	if ok := cache.WaitForCacheSync(ch, c.fooSynced); !ok {
		log.Printf("cache is not synced")
	}

	go wait.Until(c.worker, time.Second, ch)

	<-ch
	return nil
}

func (c *Controller) worker() {
	c.processNextItem()
}

func (c *Controller) processNextItem() bool {
	return true
}

func (c *Controller) handleAdd(obj interface{}) {
	log.Println("handleAdd was called")
	c.workqueue.Add(obj)
}

func (c *Controller) handleDelete(obj interface{}) {
	log.Println("handleDelete was called")
	c.workqueue.Add(obj)
}

```

</details>

Update main.go


```diff
 package main

 import (
-       "context"
        "flag"
-       "fmt"
        "log"
        "path/filepath"
+       "time"

        "k8s.io/client-go/tools/clientcmd"
        "k8s.io/client-go/util/homedir"

        client "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
-       metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
+       finformer "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions"
+       "github.com/nakamasato/sample-controller/pkg/controller"
 )

...
-       fmt.Println(clientset)

-       foos, err := clientset.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
-       if err != nil {
-               log.Printf("listing foos %s\n", err.Error())
+       informerFactory := finformer.NewSharedInformerFactory(clientset, 20 * time.Minute)
+       ch := make(chan struct{})
+       c := controller.NewController(clientset, informerFactory.Example().V1alpha1().Foos())
+       informerFactory.Start(ch)
+       if err = c.Run(ch); err != nil {
+               log.Printf("error occurred when running controller %s\n", err.Error())
        }
-       fmt.Printf("length of foos is %d\n", len(foos.Items))
```

Build and run the controller.

```
go build
./sample-controller
```

Create and delete CR.

```
kubectl apply -f config/sample/foo.yaml
```

```
kubectl delete -f config/sample/foo.yaml
```

Check the controller logs.

```
2021/12/19 17:31:25 handleAdd was called
2021/12/19 17:31:47 handleDelete was called
2021/12/19 17:31:53 handleAdd was called
2021/12/19 17:31:57 handleDelete was called
```

### 4.2. Fetch foo object

Implement the following logic:
1. Get a workqueue item.
1. Get the key for the item from the cache.
1. Split the key into namespace and name.
1. Get the `Foo` resource with namespace and name from the lister.


```go
func (c *Controller) processNextItem() bool {
	item, shutdown := c.workqueue.Get()
	if shutdown {
		return false
	}

	key, err := cache.MetaNamespaceKeyFunc(item)
	if err != nil {
		log.Printf("failed to get key from the cache %s\n", err.Error())
		return false
	}

	ns, name, err := cache.SplitMetaNamespaceKey(key)
	if err != nil {
		log.Printf("failed to split key into namespace and name %s\n", err.Error())
		return false
	}

	foo, err := c.fLister.Foos(ns).Get(name)
	if err != nil {
		log.Printf("failed to get foo resource from lister %s\n", err.Error())
		return false
	}
	log.Printf("Got foo %+v\n", foo.Spec)

	return true
}
```

Build and run the controller.

```
go build
./sample-controller
```

Create and delete CR.

```
kubectl apply -f config/sample/foo.yaml
```

```
kubectl delete -f config/sample/foo.yaml
```

Check the controller logs.

```
./sample-controller
2021/12/20 05:53:10 handleAdd was called
2021/12/20 05:53:10 Got foo {DeploymentName:foo-sample Replicas:0xc0001a942c}
2021/12/20 05:53:16 handleDelete was called
2021/12/20 05:53:16 failed to get foo resource from lister foo.example.com "foo-sample" not found
```

## Reference
- [sample-controller](https://github.com/kubernetes/sample-controller)
- [Kubernetes Deep Dive: Code Generation for CustomResources](https://cloud.redhat.com/blog/kubernetes-deep-dive-code-generation-customresources)
- [Generating ClientSet/Informers/Lister and CRD for Custom Resources | Writing K8S Operator - Part 1](https://www.youtube.com/watch?v=89PdRvRUcPU)
- [Implementing add and del handler func and token field in Kluster CRD | Writing K8S Operator - Part 2](https://www.youtube.com/watch?v=MOutOgdXfnA)
