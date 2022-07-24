package controller

import (
	"log"
	"time"

	clientset "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
	informers "github.com/nakamasato/sample-controller/pkg/generated/informers/externalversions/example.com/v1alpha1"
	listers "github.com/nakamasato/sample-controller/pkg/generated/listers/example.com/v1alpha1"

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
