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
		client:    client,
		fooSynced: fooInformer.Informer().HasSynced,
		fLister:   fooInformer.Lister(),
		workqueue: workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
	}

	fooInformer.Informer().AddEventHandler(
		cache.ResourceEventHandlerFuncs{
			AddFunc:    c.handleAdd,
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
