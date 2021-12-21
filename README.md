# Sample Controller

## Spec

- Group: example.com
- CR: `Foo`
- Version: `v1alpha1`

## Tools

- [code-generator](https://github.com/kubernetes/code-generator)

## 0. Init module

```
go mod init
```

## 1. Define CRD

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

## 2. Generate code

1. Set `execDir` env var for `code-generator`.

    ```
    execDir=~/repos/kubernetes/code-generator
    ```

    If you already cloned, you can specify the directory.

1. Clone code-generator if you haven't cloned.

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

1. Generate codes (deepcopy, clientset, listers, and informers).

    ※ You need to replace `github.com/nakamasato/sample-controller` with your package name.

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

## 3. Create CRD yaml file

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

## 4. Checkpoint: Check custom resource and codes

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

## 5. Write controller

### 5.1. Create Controller

1. Create controller.

    What's inside the controller:
    1. Define `Controller` struct with `sampleclientset`, `foosLister`, `foosSynced`, and `workqueue`.
    1. Define `NewController` function
        1. Create `Controller` with the arguments `sampleclientset` and `fooInformer`, which will be passed in `main.go`.
        1. Add event handlers for `addFunc` and `DeleteFunc` to the informer.
        1. Return the controller.
    1. Define `Run`, which will be called in `main.go`.
        1. Wait until the cache is synced.
        1. Run `c.worker` repeatedly every second until the stop channel is closed.
    1. Define `worker`: just call `processNextItem`.
    1. Define `processNextItem`: always return true for now.

    <details><summary>pkg/controller/foo.go</summary>

    ```go
    package controller

    import (
    	"log"
    	"time"

    	clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
    	informers "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions/example.com/v1alpha1"
    	listers "github.com/nakamasato/sample-controller/pkg/client/listers/example.com/v1alpha1"

    	"k8s.io/apimachinery/pkg/util/wait"
    	"k8s.io/client-go/tools/cache"
    	"k8s.io/client-go/util/workqueue"
    )

    type Controller struct {
    	// sampleclientset is a clientset for our own API group
    	sampleclientset clientset.Interface

    	foosLister listers.FooLister    // lister for foo
    	foosSynced cache.InformerSynced // cache is synced for foo

    	// queue
    	workqueue workqueue.RateLimitingInterface
    }

    func NewController(sampleclientset clientset.Interface, fooInformer informers.FooInformer) *Controller {
    	controller := &Controller{
    		sampleclientset: sampleclientset,
    		foosSynced:      fooInformer.Informer().HasSynced,
    		foosLister:      fooInformer.Lister(),
    		workqueue:       workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
    	}

    	fooInformer.Informer().AddEventHandler(
    		cache.ResourceEventHandlerFuncs{
    			AddFunc:    controller.handleAdd,
    			DeleteFunc: controller.handleDelete,
    		},
    	)
    	return controller
    }

    func (c *Controller) Run(ch chan struct{}) error {
    	if ok := cache.WaitForCacheSync(ch, c.foosSynced); !ok {
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

    Although `controller.go` is under the root directory in [sample-controller](https://github.com/kubernetes/sample-controller/blob/master/controller.go), here creates controller under `pkg/controller` directory in this repo. You can also move it to `main` package if you want.


1. Update `main.go` to initialize a controller and run it.

    ```diff
     import (
    -       "context"
            "flag"
    -       "fmt"
            "log"
            "path/filepath"
    +       "time"

            "k8s.io/client-go/tools/clientcmd"
            "k8s.io/client-go/util/homedir"

    -       client "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
    -       metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    +       clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
    +       informers "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions"
    +       "github.com/nakamasato/sample-controller/pkg/controller"
     )

     func main() {
    @@ -29,15 +29,16 @@ func main() {
                    log.Printf("Building config from flags, %s", err.Error())
            }

    -       clientset, err := client.NewForConfig(config)
    +       exampleClient, err := clientset.NewForConfig(config)
            if err != nil {
                    log.Printf("getting client set %s\n", err.Error())
            }
    -       fmt.Println(clientset)

    -       foos, err := clientset.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
    -       if err != nil {
    -               log.Printf("listing foos %s\n", err.Error())
    +       exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, 20*time.Minute)
    +       ch := make(chan struct{})
    +       controller := controller.NewController(exampleClient, informerFactory.Example().V1alpha1().Foos())
    +       exampleInformerFactory.Start(ch)
    +       if err = controller.Run(ch); err != nil {
    +               log.Printf("error occurred when running controller %s\n", err.Error())
            }
    -       fmt.Printf("length of foos is %d\n", len(foos.Items))
     }
    ```

    At the line of `exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, 20*time.Minute)`, the second argument specifies ***ResyncPeriod***, which defines the interval of ***resync*** (*The resync operation consists of delivering to the handler an update notification for every object in the informer's local cache*). For more detail, please read [NewSharedIndexInformer](https://pkg.go.dev/k8s.io/client-go@v0.23.1/tools/cache#NewSharedIndexInformer)

    I'm not exactly sure why [here](https://github.com/kubernetes/sample-controller/blob/0da864e270013aff1b6604a83b19356333d85ce9/main.go#L62-L63) specifies 30 seconds for **ResyncPeriod**.

    <details><summary>main.go</summary>

    ```go
    package main

    import (
    	"flag"
    	"log"
    	"path/filepath"
    	"time"

    	"k8s.io/client-go/tools/clientcmd"
    	"k8s.io/client-go/util/homedir"

    	clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
    	informers "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions"
    	"github.com/nakamasato/sample-controller/pkg/controller"
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

    	exampleClient, err := clientset.NewForConfig(config)
    	if err != nil {
    		log.Printf("getting client set %s\n", err.Error())
    	}

    	exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, 20*time.Minute)
    	ch := make(chan struct{})
    	controller := controller.NewController(exampleClient, exampleInformerFactory.Example().V1alpha1().Foos())
    	exampleInformerFactory.Start(ch)
    	if err = controller.Run(ch); err != nil {
    		log.Printf("error occurred when running controller %s\n", err.Error())
    	}
    }
    ```

    </details>

1. Build and run the controller.

    ```
    go build
    ./sample-controller
    ```

1. Create and delete CR.

    ```
    kubectl apply -f config/sample/foo.yaml
    ```

    ```
    kubectl delete -f config/sample/foo.yaml
    ```

1. Check the controller logs.

    ```
    2021/12/19 17:31:25 handleAdd was called
    2021/12/19 17:31:47 handleDelete was called
    ```

### 5.2. Fetch foo object

Implement the following logic:
1. Get a workqueue item.
1. Get the key for the item from the cache.
1. Split the key into namespace and name.
1. Get the `Foo` resource with namespace and name from the lister.

Steps:
1. Define `enqueueFoo` to convert Foo resource into namespace/name string before putting into the workqueue.

    ```go
    func (c *Controller) handleAdd(obj interface{}) {
        log.Println("handleAdd was called")
        c.enqueueFoo(obj)
    }

    func (c *Controller) handleDelete(obj interface{}) {
        log.Println("handleDelete was called")
        c.enqueueFoo(obj)
    }

    // enqueueFoo takes a Foo resource and converts it into a namespace/name
    // string which is then put onto the work queue. This method should *not* be
    // passed resources of any type other than Foo.
    func (c *Controller) enqueueFoo(obj interface{}) {
        var key string
        var err error
        if key, err = cache.MetaNamespaceKeyFunc(obj); err != nil {
            log.Printf("failed to get key from the cache %s\n", err.Error())
            return
        }
        c.workqueue.Add(key)
    }
    ```
1. Update `processNextItem`.

    ```go
    func (c *Controller) processNextItem() bool {
        obj, shutdown := c.workqueue.Get()
        if shutdown {
            return false
        }

        // wrap this block in a func to use defer c.workqueue.Done
        err := func(obj interface{}) error {
            // call Done to tell workqueue that the item was finished processing
            defer c.workqueue.Done(obj)
            var key string
            var ok bool

            if key, ok = obj.(string); !ok {
                // As the item in the workqueue is actually invalid, we call
                // Forget here else we'd go into a loop of attempting to
                // process a work item that is invalid.
                c.workqueue.Forget(obj)
                return nil
            }

            ns, name, err := cache.SplitMetaNamespaceKey(key)
            if err != nil {
                log.Printf("failed to split key into namespace and name %s\n", err.Error())
                return err
            }

            // temporary main logic
            foo, err := c.foosLister.Foos(ns).Get(name)
            if err != nil {
                log.Printf("failed to get foo resource from lister %s\n", err.Error())
                return err
            }
            log.Printf("Got foo %+v\n", foo.Spec)

            // Forget the queue item as it's successfully processed and
            // the item will not be requeued.
            c.workqueue.Forget(obj)
            return nil
        }(obj)

        if err != nil {
            return true
        }

        return true
    }
    ```

1. Build and run the controller.

    ```
    go build
    ./sample-controller
    ```

1. Create and delete CR.

    ```
    kubectl apply -f config/sample/foo.yaml
    ```

    ```
    kubectl delete -f config/sample/foo.yaml
    ```

1. Check the controller logs.

    ```
    ./sample-controller
    2021/12/20 05:53:10 handleAdd was called
    2021/12/20 05:53:10 Got foo {DeploymentName:foo-sample Replicas:0xc0001a942c}
    2021/12/20 05:53:16 handleDelete was called
    2021/12/20 05:53:16 failed to get foo resource from lister foo.example.com "foo-sample" not found
    ```

### 5.3. Implement reconciliation logic - Enable to Create/Delete Deployment for Foo resource

At the end of this step, we'll be able to create `Deployment` for `Foo` resource.

1. Add fields (`kubeclientset`, `deploymentsLister`, and `deploymentsSynced`) to `Controller`.
    ```diff
     type Controller struct {
    +       // kubeclientset is a standard kubernetes clientset
    +       kubeclientset kubernetes.Interface
            // sampleclientset is a clientset for our own API group
            sampleclientset clientset.Interface

    +       deploymentsLister appslisters.DeploymentLister
    +       deploymentsSynced cache.InformerSynced
    +
            foosLister listers.FooLister    // lister for foo
            foosSynced cache.InformerSynced // cache is synced for foo

    @@ -24,12 +39,19 @@ type Controller struct {
            workqueue workqueue.RateLimitingInterface
     }
    ```
1. Update `NewController` as follows:
    ```diff
    -func NewController(sampleclientset clientset.Interface, fooInformer informers.FooInformer) *Controller {
    +func NewController(
    +       kubeclientset kubernetes.Interface,
    +       sampleclientset clientset.Interface,
    +       deploymentInformer appsinformers.DeploymentInformer,
    +       fooInformer informers.FooInformer) *Controller {
            controller := &Controller{
    -               sampleclientset: sampleclientset,
    -               foosSynced:      fooInformer.Informer().HasSynced,
    -               foosLister:      fooInformer.Lister(),
    -               workqueue:       workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
    +               kubeclientset:     kubeclientset,
    +               sampleclientset:   sampleclientset,
    +               deploymentsLister: deploymentInformer.Lister(),
    +               deploymentsSynced: deploymentInformer.Informer().HasSynced,
    +               foosLister:        fooInformer.Lister(),
    +               foosSynced:        fooInformer.Informer().HasSynced,
    +               workqueue:         workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
            }
    ```
1. Update `main.go` to pass the added arguments to `NewController`.
    ```diff
    import (
    ...
    +       kubeinformers "k8s.io/client-go/informers"
    +       "k8s.io/client-go/kubernetes"
    ...
    )
    ```

    ```diff
    func main() {
        ...
    +       kubeClient, err := kubernetes.NewForConfig(config)
    +       if err != nil {
    +               log.Printf("getting kubernetes client set %s\n", err.Error())
    +       }
    +
            exampleClient, err := clientset.NewForConfig(config)
            if err != nil {
                    log.Printf("getting client set %s\n", err.Error())
            }

    -       exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, 20*time.Minute)
    +       kubeInformerFactory := kubeinformers.NewSharedInformerFactory(kubeClient, time.Second*30)
    +       exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, time.Second*30)
            ch := make(chan struct{})
    -       controller := controller.NewController(exampleClient, exampleInformerFactory.Example().V1alpha1().Foos())
    +       controller := controller.NewController(
    +               kubeClient,
    +               exampleClient,
    +               kubeInformerFactory.Apps().V1().Deployments(),
    +               exampleInformerFactory.Example().V1alpha1().Foos(),
    +       )
    +       kubeInformerFactory.Start(ch)
        ...
    }
    ```
1. Create `syncHandler` and `newDeployment`.

    ```go
    func (c *Controller) syncHandler(key string) error {
    	ns, name, err := cache.SplitMetaNamespaceKey(key)
    	if err != nil {
    		log.Printf("failed to split key into namespace and name %s\n", err.Error())
    		return err
    	}

    	foo, err := c.foosLister.Foos(ns).Get(name)
    	if err != nil {
    		log.Printf("failed to get foo resource from lister %s\n", err.Error())
    		if errors.IsNotFound(err) {
    			return nil
    		}
    		return err
    	}

    	deploymentName := foo.Spec.DeploymentName
    	if deploymentName == "" {
    		log.Printf("deploymentName must be specified %s\n", key)
    		return nil
    	}
    	deployment, err := c.deploymentsLister.Deployments(foo.Namespace).Get(deploymentName)
    	if errors.IsNotFound(err) {
    		deployment, err = c.kubeclientset.AppsV1().Deployments(foo.Namespace).Create(context.TODO(), newDeployment(foo), metav1.CreateOptions{})
    	}

    	if err != nil {
    		return err
    	}

    	log.Printf("deployment %+v", deployment)

    	return nil
    }

    func newDeployment(foo *samplev1alpha1.Foo) *appsv1.Deployment {
    	labels := map[string]string{
    		"app":        "nginx",
    		"controller": foo.Name,
    	}
    	return &appsv1.Deployment{
    		ObjectMeta: metav1.ObjectMeta{
    			Name:            foo.Spec.DeploymentName,
    			Namespace:       foo.Namespace,
    			OwnerReferences: []metav1.OwnerReference{*metav1.NewControllerRef(foo, samplev1alpha1.SchemeGroupVersion.WithKind("Foo"))},
    		},
    		Spec: appsv1.DeploymentSpec{
    			Replicas: foo.Spec.Replicas,
    			Selector: &metav1.LabelSelector{
    				MatchLabels: labels,
    			},
    			Template: corev1.PodTemplateSpec{
    				ObjectMeta: metav1.ObjectMeta{
    					Labels: labels,
    				},
    				Spec: corev1.PodSpec{
    					Containers: []corev1.Container{
    						{
    							Name:  "nginx",
    							Image: "nginx:latest",
    						},
    					},
    				},
    			},
    		},
    	}
    }
    ```

1. Update `processNextItem` to call `syncHandler` for main logic.

    ```diff
    @@ -77,20 +99,12 @@ func (c *Controller) processNextItem() bool {
                            return nil
                    }

    -               ns, name, err := cache.SplitMetaNamespaceKey(key)
    -               if err != nil {
    -                       log.Printf("failed to split key into namespace and name %s\n", err.Error())
    -                       return err
    +               if err := c.syncHandler(key); err != nil {
    +                       // Put the item back on the workqueue to handle any transient errors.
    +                       c.workqueue.AddRateLimited(key)
    +                       return fmt.Errorf("error syncing '%s': %s, requeuing", key, err.Error())
                    }

    -               // temporary main logic
    -               foo, err := c.foosLister.Foos(ns).Get(name)
    -               if err != nil {
    -                       log.Printf("failed to get foo resource from lister %s\n", err.Error())
    -                       return err
    -               }
    -               log.Printf("Got foo %+v\n", foo.Spec)
    -
                    // Forget the queue item as it's successfully processed and
                    // the item will not be requeued.
                    c.workqueue.Forget(obj)
    ```
1. Delete `handleDelete` function as it's covered by `ownerReferences` (details mentioned in the next step) for delete action.

    ```diff
            fooInformer.Informer().AddEventHandler(
                    cache.ResourceEventHandlerFuncs{
                            AddFunc:    controller.handleAdd,
    -                       DeleteFunc: controller.handleDelete,
                    },
            )
    ```
    ```diff
    -func (c *Controller) handleDelete(obj interface{}) {
    -       log.Println("handleDelete was called")
    -       c.enqueueFoo(obj)
    -}
    ```


1. Test `sample-controller`.
    1. Build and run the controller.
        ```
        go build
        ./sample-controller
        ```
    1. Create `Foo` resource.
        ```
        kubectl apply -f config/sample/foo.yaml
        ```

        Check `Deployment`:
        ```
        kubectl get deploy
        NAME         READY   UP-TO-DATE   AVAILABLE   AGE
        foo-sample   0/1     1            0           3s
        ```
        Check `sample-controller`'s logs:
        ```
        2021/12/20 19:58:30 handleAdd was called
        2021/12/20 19:58:30 deployment foo-sample exists
        ```
    1. Delete `Foo` resource.
        ```
        kubectl delete -f config/sample/foo.yaml
        ```
        Check `Deployment`:
        ```
        kubectl get deploy
        No resources found in default namespace.
        ```
        Check `sample-controller`'s logs:
        ```
        2021/12/20 19:59:14 handleDelete was called
        2021/12/20 19:59:14 failed to get foo resource from lister foo.example.com "foo-sample" not found
        ```
        `Deployment` is deleted when the corresponding `Foo` is deleted thanks to `OwnerReference`'s [cascading deletion](https://kubernetes.io/docs/concepts/architecture/garbage-collection/#cascading-deletion) feature:

        > Kubernetes checks for and deletes objects that no longer have owner references, like the pods left behind when you delete a ReplicaSet. When you delete an object, you can control whether Kubernetes deletes the object's dependents automatically, in a process called cascading deletion.

### 5.4. Implement reconciliation logic - Check and update Deployment if necessary

What needs to be done:
- In `syncHandler`
    - [x] Check if the found `Deployment` is managed by the `sample-controller`.
    - [x] Check if the found `Deployment`'s `replicas` is same as the specified `replica` in `Foo` resource.
- In `NewController`
    - [x] Set `UpdateFunc` as an event handler for the informer in order to call `syncHandler` when `Foo` resource is updated.

Steps:
1. Update `syncHandler`:
    1. Check if the `Deployment` is managed by the controller.

        ```go
            // If the Deployment is not controlled by this Foo resource, we should log
            // a warning to the event recorder and return error msg.
            if !metav1.IsControlledBy(deployment, foo) {
                msg := fmt.Sprintf(MessageResourceExists, deployment.Name)
                log.Println(msg)
                return fmt.Errorf("%s", msg)
            }
        ```
    1. Check the replica and update `Deployment` object if replicas in `Deployment` and `Foo` differ.

        ```go
            // If this number of the replicas on the Foo resource is specified, and the
            // number does not equal the current desired replicas on the Deployment, we
            // should update the Deployment resource.
            if foo.Spec.Replicas != nil && *foo.Spec.Replicas != *deployment.Spec.Replicas {
                log.Printf("Foo %s replicas: %d, deployment replicas: %d\n", name, *foo.Spec.Replicas, *deployment.Spec.Replicas)
                deployment, err = c.kubeclientset.AppsV1().Deployments(foo.Namespace).Update(context.TODO(), newDeployment(foo), metav1.UpdateOptions{})
            }
            // If an error occurs during Update, we'll requeue the item so we can
            // attempt processing again later. This could have been caused by a
            // temporary network failure, or any other transient reason.
            if err != nil {
                return err
            }
        ```
1. Update event handlers in `NewController`:
    ```diff
            fooInformer.Informer().AddEventHandler(
                    cache.ResourceEventHandlerFuncs{
    -                       AddFunc: controller.handleAdd,
    +                       AddFunc: controller.enqueueFoo,
    +                       UpdateFunc: func(old, new interface{}) {
    +                               controller.enqueueFoo(new)
    +                       },
                    },
            )
    ```
1. Remove unused `handleAdd` function.
    ```diff
    -func (c *Controller) handleAdd(obj interface{}) {
    -       log.Println("handleAdd was called")
    -       c.enqueueFoo(obj)
    -}
    ```
1. Test if `sample-controller` updates replicas.
    1. Apply `Foo` resource.
        ```
        kubectl apply -f config/sample/foo.yaml
        ```

        ```
        kubectl get deploy
        NAME         READY   UP-TO-DATE   AVAILABLE   AGE
        foo-sample   1/1     1            1           3h41m
        ```
    1. Increase replica to 2.
        ```
        kubectl patch foo foo-sample -p '{"spec":{"replicas": 2}}' --type=merge
        ```

        logs:

        ```
        2021/12/21 10:08:19 Foo foo-sample replicas: 2, deployment replicas: 1
        ```

        Replicas of Deployment increased.
        ```
        kubectl get deploy
        NAME         READY   UP-TO-DATE   AVAILABLE   AGE
        foo-sample   2/2     2            2           3h42m
        ```
    1. Delete `Foo` resource.
        ```
        kubectl delete -f config/sample/foo.yaml
        ```
1. Test if `sample-controller` wouldn't touch `Deployment` that is not managed by the controller.
    1. Apply `Deployment` with name `foo-sample`.
        ```
        kubectl create deployment foo-sample --image=nginx
        ```

    1. Apply `Foo` resource with name `foo-sample`.
        ```
        kubectl apply -f config/sample/foo.yaml
        ```
    1. Log:
        ```
        2021/12/21 10:14:50 deployment foo-sample found
        2021/12/21 10:14:50 Resource "foo-sample" already exists and is not managed by Foo
        ```

    1. Clean up.
        ```
        kubectl delete -f config/sample/foo.yaml
        kubectl delete deploy foo-sample
        ```

## Reference
- [sample-controller](https://github.com/kubernetes/sample-controller)
- [Kubernetes Deep Dive: Code Generation for CustomResources](https://cloud.redhat.com/blog/kubernetes-deep-dive-code-generation-customresources)
- [Generating ClientSet/Informers/Lister and CRD for Custom Resources | Writing K8S Operator - Part 1](https://www.youtube.com/watch?v=89PdRvRUcPU)
- [Implementing add and del handler func and token field in Kluster CRD | Writing K8S Operator - Part 2](https://www.youtube.com/watch?v=MOutOgdXfnA)
- [Calling DigitalOcean APIs on Kluster's add event | Writing K8S Operator - Part 3](https://www.youtube.com/watch?v=Wtyj0V4Inmg)
- [A deep dive into Kubernetes controllers](https://engineering.bitnami.com/articles/a-deep-dive-into-kubernetes-controllers.html)
