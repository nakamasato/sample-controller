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

func (c *Controller) Run(stopCh <-chan struct{}) error {
	if ok := cache.WaitForCacheSync(stopCh, c.foosSynced); !ok {
		log.Printf("cache is not synced")
	}

	go wait.Until(c.worker, time.Second, stopCh)

	<-stopCh
	return nil
}

func (c *Controller) worker() {
	c.processNextItem()
}

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
