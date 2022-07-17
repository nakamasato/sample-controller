---
title: '5. Implement reconciliation'
date: 2019-02-11T19:27:37+10:00
draft: false
weight: 7
summary: Implement controller.
---

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
    2022/07/18 06:36:35 handleAdd was called
    2022/07/18 06:36:40 handleDelete was called
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

### 5.3. Enable to Create/Delete Deployment for Foo resource

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

### 5.4. Check and update Deployment if necessary

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

### 5.5. Update Foo status

1. Create `updateFooStatus` function and add the logic at the end of `syncHandler`

    ```go
    func (c *Controller) updateFooStatus(foo *samplev1alpha1.Foo, deployment *appsv1.Deployment) error {
        // NEVER modify objects from the store. It's a read-only, local cache.
        // You can use DeepCopy() to make a deep copy of original object and modify this copy
        // Or create a copy manually for better performance
        fooCopy := foo.DeepCopy()
        fooCopy.Status.AvailableReplicas = deployment.Status.AvailableReplicas
        // If the CustomResourceSubresources feature gate is not enabled,
        // we must use Update instead of UpdateStatus to update the Status block of the Foo resource.
        // UpdateStatus will not allow changes to the Spec of the resource,
        // which is ideal for ensuring nothing other than resource status has been updated.
        _, err := c.sampleclientset.ExampleV1alpha1().Foos(foo.Namespace).UpdateStatus(context.TODO(), fooCopy, metav1.UpdateOptions{})
        return err
    }
    ```

    ```go
    func (c *Controller) syncHandler() {
        ...

        // Finally, we update the status block of the Foo resource to reflect the
        // current state of the world
        err = c.updateFooStatus(foo, deployment)
        if err != nil {
            log.Printf("failed to update Foo status for %s", foo.Name)
            return err
        }

        return nil
    }
    ```
1. Add `subresources` to `CustomResourceDefinition`.

    ```yaml
          subresources:
            status: {}
            scale:
              specReplicasPath: .spec.replicas
              statusReplicasPath: .status.replicas
              labelSelectorPath: .status.labelSelector
    ```

    For more details, see [subresources](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#subresources)
1. Test status
    1. Apply `Foo`
        ```
        kubectl apply -f config/sample/foo.yaml
        ```
    1. Check status (not updated immediately -> will be fixed in the next section.)
        ```
        kubectl get foo foo-sample -o jsonpath='{.status}'
        {"availableReplicas":0}%
        ```
        Currently, the informer just monitors `Foo` resource, which cannot capture the update of `Deployment.status.availableReplicas`.
    1. Check status after a while
        ```
        kubectl get foo foo-sample -o jsonpath='{.status}'
        {"availableReplicas":1}%
        ```
1. Test scale
    1. Scale.
        ```
        kubectl scale --replicas=3 foo foo-sample
        ```

        ```
        kubectl get deploy
        NAME         READY   UP-TO-DATE   AVAILABLE   AGE
        foo-sample   3/3     3            3           95s
        ```

        ```
        kubectl scale --replicas=1 foo foo-sample
        ```

        ```
        kubectl get deploy
        NAME         READY   UP-TO-DATE   AVAILABLE   AGE
        foo-sample   1/1     1            1           9m10s
        ```

### 5.6. Capture the update of Deployment

1. Add handleObject function.

    ```go
    // handleObject will take any resource implementing metav1.Object and attempt
    // to find the Foo resource that 'owns' it. It does this by looking at the
    // objects metadata.ownerReferences field for an appropriate OwnerReference.
    // It then enqueues that Foo resource to be processed. If the object does not
    // have an appropriate OwnerReference, it will simply be skipped.
    func (c *Controller) handleObject(obj interface{}) {
        var object metav1.Object
        var ok bool
        if object, ok = obj.(metav1.Object); !ok {
            tombstone, ok := obj.(cache.DeletedFinalStateUnknown)
            if !ok {
                return
            }
            object, ok = tombstone.Obj.(metav1.Object)
            if !ok {
                return
            }
            log.Printf("Recovered deleted object '%s' from tombstone", object.GetName())
        }
        log.Printf("Processing object: %s", object.GetName())
        if ownerRef := metav1.GetControllerOf(object); ownerRef != nil {
            // If this object is not owned by a Foo, we should not do anything more
            // with it.
            if ownerRef.Kind != "Foo" {
                return
            }

            foo, err := c.foosLister.Foos(object.GetNamespace()).Get(ownerRef.Name)
            if err != nil {
                log.Printf("ignoring orphaned object '%s' of foo '%s'", object.GetSelfLink(), ownerRef.Name)
                return
            }

            c.enqueueFoo(foo)
            return
        }
    }
    ```
    When `Deployment` managed by `Foo` is added/updated/deleted, get the corresponding `Foo` and put the key (`naemspace/name`) to the workqueue.

1. Add event handlers to `deploymentInformer` in `NewController`.

    ```go
        // Set up an event handler for when Deployment resources change. This
        // handler will lookup the owner of the given Deployment, and if it is
        // owned by a Foo resource then the handler will enqueue that Foo resource for
        // processing. This way, we don't need to implement custom logic for
        // handling Deployment resources. More info on this pattern:
        // https://github.com/kubernetes/community/blob/8cafef897a22026d42f5e5bb3f104febe7e29830/contributors/devel/controllers.md
        deploymentInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
            AddFunc: controller.handleObject,
            UpdateFunc: func(old, new interface{}) {
                newDepl := new.(*appsv1.Deployment)
                oldDepl := old.(*appsv1.Deployment)
                if newDepl.ResourceVersion == oldDepl.ResourceVersion {
                    // Periodic resync will send update events for all known Deployments.
                    // Two different versions of the same Deployment will always have different RVs.
                    return
                }
                controller.handleObject(new)
            },
            DeleteFunc: controller.handleObject,
        })
    ```
1. Test the Foo's status after Deployment is updated.
    1. Create Foo resource.
        ```
        kubectl apply -f config/sample/foo.yaml
        ```
    1. Check Foo's status (will be immediately updated.)
        ```
        kubectl get foo foo-sample -o jsonpath='{.status}'
        {"availableReplicas":1}
        ```


### 5.7. Create events for Foo resource

1. Add necessary packages.
    ```diff
    @@ -13,20 +13,34 @@ import (
            "k8s.io/apimachinery/pkg/util/wait"
            appsinformers "k8s.io/client-go/informers/apps/v1"
            "k8s.io/client-go/kubernetes"
    +       typedcorev1 "k8s.io/client-go/kubernetes/typed/core/v1"
            appslisters "k8s.io/client-go/listers/apps/v1"
            "k8s.io/client-go/tools/cache"
    +       "k8s.io/client-go/tools/record"
            "k8s.io/client-go/util/workqueue"

            samplev1alpha1 "github.com/nakamasato/sample-controller/pkg/apis/example.com/v
    1alpha1"
            clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versio
    ned"
    +       "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned/scheme
    "
            informers "github.com/nakamasato/sample-controller/pkg/client/informers/extern
    alversions/example.com/v1alpha1"
            listers "github.com/nakamasato/sample-controller/pkg/client/listers/example.com/v1alpha1"
    ```
1. Add eventRecorder to Controller.
    ```diff
     type Controller struct {
    @@ -43,6 +57,10 @@ type Controller struct {

            // queue
            workqueue workqueue.RateLimitingInterface
    +
    +       // recorder is an event recorder for recording Event resources to the
    +       // Kubernetes API.
    +       recorder record.EventRecorder
     }
    ```
1. Initialize `eventBroadcaster`.
    ```diff
     func NewController(
    @@ -50,6 +68,11 @@ func NewController(
            sampleclientset clientset.Interface,
            deploymentInformer appsinformers.DeploymentInformer,
            fooInformer informers.FooInformer) *Controller {
    +
    +       eventBroadcaster := record.NewBroadcaster()
    +       eventBroadcaster.StartStructuredLogging(0)
    +       eventBroadcaster.StartRecordingToSink(&typedcorev1.EventSinkImpl{Interface:     kubeclientset.CoreV1().Events("")})
    +       recorder := eventBroadcaster.NewRecorder(scheme.Scheme, corev1.EventSource{Component:     controllerAgentName})
            controller := &Controller{
                    kubeclientset:     kubeclientset,
                    sampleclientset:   sampleclientset,
    @@ -58,6 +81,7 @@ func NewController(
                    foosLister:        fooInformer.Lister(),
                    foosSynced:        fooInformer.Informer().HasSynced,
                    workqueue:         workqueue.NewNamedRateLimitingQueue(workqueue.    DefaultControllerRateLimiter(), "foo"),
    +               recorder:          recorder,
            }
    ```
1. Define constants.
    ```diff
     const (
    +       // SuccessSynced is used as part of the Event 'reason' when a Foo is synced
    +       SuccessSynced = "Synced"
    +       // ErrResourceExists is used as part of the Event 'reason' when a Foo fails
    +       // to sync due to a Deployment of the same name already existing.
    +       ErrResourceExists = "ErrResourceExists"
    +
            // MessageResourceExists is the message used for Events when a resource
            // fails to sync due to a Deployment already existing
            MessageResourceExists = "Resource %q already exists and is not managed by Foo"
    +       // MessageResourceSynced is the message used for an Event fired when a Foo
    +       // is synced successfully
    +       MessageResourceSynced = "Foo synced successfully"
    +
    +       controllerAgentName = "sample-controller"
     )
    ```
1. Record events.
    ```diff
    @@ -199,6 +223,7 @@ func (c *Controller) syncHandler(key string) error {
            // a warning to the event recorder and return error msg.
            if !metav1.IsControlledBy(deployment, foo) {
                    msg := fmt.Sprintf(MessageResourceExists, deployment.Name)
    +               c.recorder.Event(foo, corev1.EventTypeWarning, ErrResourceExists, msg)
                    log.Println(msg)
                    return fmt.Errorf("%s", msg)
            }
    @@ -228,6 +253,7 @@ func (c *Controller) syncHandler(key string) error {
                    return err
            }

    +       c.recorder.Event(foo, corev1.EventTypeNormal, SuccessSynced, MessageResourceSynced)
            return nil
     }
    ```
1. Test event.
    1. Apply `Foo`.
    1. Check `event`.
        ```
        kubectl get event --field-selector involvedObject.kind=Foo
        LAST SEEN   TYPE     REASON   OBJECT           MESSAGE
        22s         Normal   Synced   foo/foo-sample   Foo synced successfully
        ```