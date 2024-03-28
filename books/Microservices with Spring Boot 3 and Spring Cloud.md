
## Introduction to microservices

Benefits:
- independent components are interchangeable 
- each component in the platform can be delivered and upgraded separately
- each component can be scaled out to multiple servers (instances)
- components can be deployed across different servers

Challenges:
- chain of failures (one component crashing can lead to cascading failures)
- keeping the configuration in consistent state is challenging 
- monitoring the state of the platform is more complicated
- collecting and correlating related log events is more difficult

**The 8 fallacies of distributed computing by Peter Deutsch**
- network is reliable
- latency is zero
- bandwidth is infinite
- network is secure
- the topology doesn't change
- there is one administrator
- the transport cost is zero
- the network is homogeneus

Microservice characteristic:
- autonomous component that is independently upgradeable, replaceable and scalable
- shared nothing architecture - microservices don't share data with each other
- communicates through well-defined interfaces (API)
- is deployed as separate process
- instances are stateless - incoming requests can be handled by any of its instances

### Microservices patterns
#### Service discovery
Service discovery keeps track of currently available microservices and the IP addresses of its instances. 
- automatically register/unregister microservices instances
- requests to a microservice must be load balanced over the available instances
- detect unhealthy instances 

#### Edge server
Edge Server exposes some of the services to the external consumer (client) and hide the remaining ones from external access. 
- hides internal services that should not be exposed
- exposes external services and protects them from malicious requests

#### Reactive microservices
Blocking I/O operations in request chain drain system threads. Use non-blocking I/O.
- use an async programming model whenever possible
- use reactive frameworks for sync programming

#### Central Configuration
Configuration Server stores the configuration of all the microservices.

#### Centralized log analysis
Centralized logging detects new microservices instances, collects log events, interprets and stores log events in a structured and searchable way in a central database and provides api and graphical tool for querying and analyzing log events. 

#### Distributed tracing
Distributed tracing allows to track requests and messages that flow between microservices while processing external request. All related requests must be marked with a common `correlationId`. All log events must include `correlationId`. 

#### Circuit breaker
Circuit breaker prevents new outgoing requests from a caller if it detects a problem with the service it calls. 
- open the circuit and fail fast (without waiting for timeout) if problems with service are detected
- probe for failure correction
- close the circuit if the probe detects that the service is operating normally again

#### Control loop
The control loop will constantly observe the actual state of the system landscape, comparing it with a desired state specified by operators. If the two states differ it will take action to make the actual state equal to the desired state.

#### Centralized monitoring and alarms
Monitor service collects metrics about hardware resource usage for each microservice instance. 
- it must be able to collect metrics from all the servers 
- must be able to detect new microservice instances
- provides APIs and UI for querying and analyzing the collected metrics
- it must be possible to define alerts that are triggered when a specific metric exceeds a threshold value

## Docker vs VMs
Containers:
- processed in a Linux host that uses Linux namespaces to provide isolation between containers
- Linux Control Groups are used to limit the amount of CPU and memory that a container is allowed to consume
VMs:
- uses a hypervisor to run a complete copy of an operating system in each virtual machine
- overhead in a container is a fraction of the overhead in a virtual machine
- slower startup and higher footprint 
- safer than containers

## Adding an API description using OpenAPI
1. Good and easily accessible documentation is an important part of whether an API is useful.
2. Many of the leading API gateways have native support for the OpenAPI Specification.
3. 

