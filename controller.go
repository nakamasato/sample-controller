package main

import (
	"fmt"
	"time"

	clientset "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
	informers "github.com/nakamasato/sample-controller/pkg/generated/informers/externalversions/example.com/v1alpha1"
	listers "github.com/nakamasato/sample-controller/pkg/generated/listers/example.com/v1alpha1"

	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/util/workqueue"
	"k8s.io/klog/v2"
)

type Controller struct {
	// sampleclientset is a clientset for our own API group
	sampleclientset clientset.Interface

	foosLister listers.FooLister
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

	_, err := fooInformer.Informer().AddEventHandler(
		cache.ResourceEventHandlerFuncs{
			AddFunc:    controller.handleAdd,
			DeleteFunc: controller.handleDelete,
		},
	)
	if err != nil {
		klog.Fatalf("error adding event handler to fooInformer %s", err.Error())
		klog.FlushAndExit(klog.ExitFlushTimeout, 1)
	}
	return controller
}

func (c *Controller) Run(stopCh chan struct{}) error {
	defer c.workqueue.ShutDown()
	if ok := cache.WaitForCacheSync(stopCh, c.foosSynced); !ok {
		return fmt.Errorf("failed to wait for caches to sync")
	}

	go wait.Until(c.runWorker, time.Second, stopCh)

	<-stopCh
	return nil
}

func (c *Controller) runWorker() {
	for c.processNextWorkItem() {
	}
}

func (c *Controller) processNextWorkItem() bool {
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
			klog.Errorf("expected string in workqueue but got %#v", obj)
			return nil
		}

		ns, name, err := cache.SplitMetaNamespaceKey(key)
		if err != nil {
			klog.Errorf("failed to split key into namespace and name %s", err.Error())
			return err
		}

		// temporary main logic
		foo, err := c.foosLister.Foos(ns).Get(name)
		if err != nil {
			klog.Errorf("failed to get foo resource from lister %s", err.Error())
			return err
		}
		klog.Infof("Got foo %+v", foo.Spec)

		// Forget the queue item as it's successfully processed and
		// the item will not be requeued.
		c.workqueue.Forget(obj)
		klog.Infof("Successfully synced '%s'", key)
		return nil
	}(obj)

	if err != nil {
		return true
	}

	return true
}

func (c *Controller) handleAdd(obj interface{}) {
	klog.Info("handleAdd is called")
	c.enqueueFoo(obj)
}

func (c *Controller) handleDelete(obj interface{}) {
	klog.Info("handleDelete is called")
	c.enqueueFoo(obj)
}

// enqueueFoo takes a Foo resource and converts it into a namespace/name
// string which is then put onto the work queue. This method should *not* be
// passed resources of any type other than Foo.
func (c *Controller) enqueueFoo(obj interface{}) {
	var key string
	var err error
	if key, err = cache.MetaNamespaceKeyFunc(obj); err != nil {
		klog.Errorf("failed to get key from the cache %s", err.Error())
		return
	}
	c.workqueue.Add(key)
}
