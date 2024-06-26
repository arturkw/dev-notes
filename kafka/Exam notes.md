# Kafka Cheat Sheet

## Data Formats with Confluent REST Proxy
- Confluent REST Proxy natively supports various data formats. Which one?
- Production **Kafka** deployment should be run `XFS` or `ext4`

## Topic
- consumer of a given topic-partition will always read that partition's events in exactly the same order as they were written
- partitions do not need to have the same number of messages
- offsets only have a meaning for a specific partition
- messages are kept only for a limited time (one week by default)
- once the data is written to a partition, it can't be changed
- data is assigned randomly to a partition unless a key is provided
- messages in partition are segregated into multiple segments to ease finding a message by its offset. Each segment is composed of the following indexes: `offset to position index` that allows Kafka to find the starting position of a message and `timestamp to offset index` that allows Kafka to find messages for a timestamp
## Topic Log Compaction
- After cleanup, only one message per key is retained with the latest value. At least last update for each message key is retained.
- Log compaction is evaluated every time a segment is closed.
- Tombstone record is a record with `null` payload. It is a marker for record deletion
- log compaction is enabled via `log.cleanup.policy=compact` Default is `delete` - old segments will be discarded when their retention time or size has been reached

## Metrics
- `records-lag-max`: Current lag (number of messages behind the broker)
- `UnderReplicatedPartitions` means that data is not being replicated to enough number of brokers
- `bytes-consumed-rate` average number of bytes per second
- `request-latency-avg` the average request latency in ms
- `response-rate` measures the number of acknowledgments per second
- `records-consumed-rate` the average number of records consumed per second.

## Java API
- `producer.send()`: Returns `Future<RecordMetadata>`.
- five major APIs in Kafka: `Producer`, `Consumer`, `Streams`, `Connect`, `Admin`

## Windowing 
- `Tumbling time window` - time based, fixes size, non-overlapping, gap-less
- `Hopping time window` - time based, fixed size, overlapping
- `Sliding time window` - time based, fixed size, overlapping, work on differences between record timestamps
- `Session window` - session based, dynamically-sized, non-overlapping, data-drven windows

## Avro
- Avro provides a language for defining schemas and using them to serialize and deserialize data.
- `SpecificRecords` are generated from Avro Schema using Maven/Gradle plugin.
- Schema registry resides as a separate JVM component.
- primitive types: `bytes`, `string`, `null`, `boolean`, `int`, `long`, `float`, `double`
- required fields: `fields`, `name`
- following message schema formats are supported: `JSON`, `Avro`, `ProtoBuf`
- Schema Registry schemas are stored in the **__schemas** topic
- set serialization format by setting `ksql.format=avro,protobuff,json`

## Schemas compatibility types
- `BACKWARD` compatibility means that consumers using the new schema can read data produced with the last schema. Delete fields and add optional fields are possible. Update consumers firsts.
- `FORWARD` compatibility means that data produced with a new schema can be read by consumers using the last schema, even though they may not be able to use the full capabilities of the new schema. Add fields and delete optional fields are possible. Update producers first.

## Consumer
- when a `consumer` wants to join a group, it sends a `JoinGroup` request to the `group coordinator` 
- the first consumer to join the group becomes the `group leader`
- `group leader` receives a list of all consumers in the group from the group coordinator and is responsible for assigning a subset of partitions to each consumer
- `RangeAssignor` assignment strategy
- `RoundRobinAssignor` assignment strategy
- consumer is configured to `auto-commit offsets` by default
- it is possible to manually assign specific partition `assign(Collection)`
- it is possible to specify the position using `seek(TopicPartition, long)`
- Produce and consume requests can only be sent to the node hosting **partition leader**.
- In case the consumer has the wrong leader of a partition, it will issue a **metadata request**.
- parameter `auto.offset.reset` has following parameters:
	- **earliest:** Automatically reset the offset to the earliest offset.
	- **latest:** Automatically reset the offset to the latest offset.
	- **none:** Throw exception to the consumer if no previous offset is found for the consumer's group.
	- **anything else:** Throw exception to the consumer.
- `consumer offset` is stored in topic **__consumer_offsers** 
- consumer is not threadsafe

## Producers
- `acks`
	 - default `ack` is `all`
	 - `0` maximizes throughput, but you will have no guarantee that the message was successfully written to the broker’s log since the broker does not send a response.
	 - `1` ack is required from partition leader only
	 - `all` guarantees that not only will the partition leader accept the write, but it will be successfully replicated to all of the in-sync replicas
- no need for `group coordination`
- automatically know to which broker and partition to write to
- producer partitioner maps each message to a topic partition, and the producer sends a produce request to the `leader of that partition`
- partitioner guarantee that all messages with the same non-empty key will be sent to the same partition
- data without key will be send round-robin to all available brokers
- producer can choose to receive ack of data writes
- most important configs for producer are: `acks`, `batch size`, `compression`
- when `retries` greater than `0` (default) then message reordering may occur since the retry may occur after a following write succeeded. To enable retries without reordering, you can set `max.in.flight.requests.per.connection` to `1` to ensure that only one request can be sent to the broker at a time.
- `batch.size` - maximum size in bytes of each message batch
- To give more time for batches to fill, you can use `linger.ms`
- Compression can be enabled with the `compression.type: none, gzip, znappy, 1z4, zstd'
- If a `Kafka producer` produces messages faster than the broker can take, the records will be buffered in memory. The default buffer memory is 33554432 bytes (32 MB). The buffer will full up over time and fill back down when the throughput of the broker increases. If the buffer is full, then the **.send()** method will start to block and won't return right away. The configuration "**max.block.ms**" is the time the **.send()** method will block before throwing an exception. If an exception is thrown this usually means the brokers are down and cannot process any data.
- to produce messages with key-value delimeters set properties: `--property parse.key && --property key.separator`
- non-retriable callback exceptions: `InvalidTopicException`, `OffsetMetadataTooLargeException`, `RecordBatchTooLargeException`, `RecordTooLargeException`, `UnknownServerException`
- retriable exceptions: `CorruptRecordException`, `InvalidMetadataException`, `NotEnoughReplicasAfterAppendException`, `NotEnoughReplicasException`, `OffsetOutOfRangeException`, `TimeoutException`, `UnknownTopicOrPartitionException`
- **Producer configurations** to achieve a high throughput application are:
	- **compression.type:** Producers usually send data that is text-based, for example with JSON data. In this case, it is important to apply compression to optimize for throughput. Compression is more effective the bigger the batch of messages being sent to Kafka. Possible values are: `lz4` (recommended for performance),`snappy`, `zstd`, `gzip`.
	- **batch.size:** With batching strategy of Kafka producers, you can batch messages going to the same partition, which means they collect multiple messages to send together in a single request. The most important step you can take to **optimize throughput** is to tune the producer batching to increase the batch size and the time spent waiting for the batch to populate with messages. Larger batch sizes result in fewer requests, which reduces load on producers and the broker CPU overhead to process each request.
	- **linger.ms:** It's the number of milliseconds a producer is willing to wait before sending a batch out (defaults to 0). By introducing some lag, we increase the changes of messages being sent together in a batch. If the batch is full (batch.size) before the end of linger.ms period, it will be sent to Kafka right away.
- to prevent records from being committed to the log in a different order than the order in which the producer intended to send them:
	- set `max.in.flight.requests.per.connection=1`
	- set `retries` to 0
- methods of sending messages:
	- fire and forget - we do not really care if it arrives successfully or not
	- synchronous send, **send()** methods returns a **Future** object and we use **get()** to wait on the future 
	- asynchronous - **send()** with a callback function
- producer is thread-safe

## Streams
- User topics: created manually. Do not rely on auto-creation (may be disabled, default settings may not be what you want)
- Internal topics are prefixed by `application.id`.
- It is crucial to close each `iterator`. Failure to close an `iterator` can lead to `Out-Of-Memory` issues.
- `Streams` scales by allowing multiple thread of executions within one instance  of the application and by supporting load balancing between distributed instances
- `Stream` engine parallelizes execution of a topology by splitting it into tasks. Number of tasks depends on the number of partitions. Each task is responsible for a subset of the partitions
- To split a stream into different branches use `split()` method. Method `branch()` is deprecated. 
- method `to` send the output to the specified topic: `stream.to("output_topic")`
- to combine two streams into one stream `merge` transformation should be used

## Joins
- When joining streams or tables input data **must be co-partitioned**. This ensures that input records with the same key, from both sides of the join, are delivered to the same stream task during processing. **It is the responsibility of the user to ensure data co-partitioning when joining**.
- **The requirements for data co-partitioning are:**
	 - The input topics of the join (left side and right side) must have the **same number of partitions**.
	- All applications that write to the input topics must have the **same partitioning strategy** so that records with the same key are delivered to same partition number.
	- `GlobalKTable` do not require data co-partitioning
- You are performing a join, and you only want to join two records if their timestamps are within five minutes of one another. Which windowing strategy should you use? Sliding Time Windows are used for joins and are tied to the timestamps of records.
- You have a topic containing records of each click on your website. Which windowing strategy would you use to dynamically create windows for an aggregation around click activity, with no windows created when there are no clicks? Session Windows are dynamically managed based upon record activity.
## Confluent Control Center
`CCC` is a self-hosted GUI with dashboards to centrilized management and monitoring of key components of the platform, including clusters, brokers, schemas, topics, messages, connectors, ksqlDB queries, security, replication and more

## Confluent Schema Registry
- `Confluent Schema Registry` allows evolution of schemas according to the configured settings and expanded support for these schema types
- `Confluent Schema Registry` is a distributed storage layer for schemas which uses Kafka as its underlying storage mechanism
- `Confluent Schema Registry` provides a serving layer for your metadata. It provides a RESTful interface for storing and retrieving your **Avro**, **JSON** Schema, and **Protobuf** schemas.

## Message Delivery Guarantees
- `At-most once` - message loss is possible if the producer doesn't retry on failures
- `At-least once` - every message is guaranteed to be persisted in Kafka at least once. There is no chance of message loss but the message can be duplicated if the producer retries when the message is already persisted
- `Exactly once` - message is guaranteed to be persisted in Kafka exactly once without any duplicates and data loss even there is a broker failure or producer retry

## Zookeeper
- used to store persistent cluster metadata
- Majority for Zookeeper ensemble `ensemble`.
- default client port: `2181`
- `ensemble` is a multiple nodes Zookeeper deployment. It  is a set of `2n + 1` nodes.
- Number `QN = (N + 1) / 2` defines the size of `quorum` (majority rule) where `n` is the total number of servers.  `Quorum` is minimal number of server required to run the Zookeeper. It is always have an odd number of servers (1, 3, 5, ...)
- each node is called `zNode`
- each `zNode` has a `path`
- `zNodes` can be persisten or ephemeral
- each `zNode` can store data
- you can not rename a `zNode`
- each `zNode` can be watched for changes
- responsible for broker registration with heartbeat mechanism
- elects leader in case some brokers go down
- stores data like: `ACL`, broker registration information, controller registration
- **tickTime:** The length of a single tick, which is the basic time unit used by ZooKeeper, as measured in milliseconds. It is used to regulate heartbeats, and timeouts.
- **initLimit:** Amount of time, in ticks, to allow followers to **connect** and sync to a leader.
- **syncLimit:** Amount of time, in ticks, to allow followers to sync with ZooKeeper. If followers fall too far behind a leader, they will be dropped.
- to monitor cluster use `bin/zookeeper-shell.sh` command
- minimum configuration defined for Zookeeper: `clientPort`, `dataDir`, `tickTime`

## Kafka Cluster
Kafka Broker configurations such as `background.threads` can be updated in such a way that will automatically roll out the change to the entire cluster, without requiring broker restarts. Cluster-wide configurations can be updated dynamically across the whole cluster.

## KRaft
 - ZooKeeper is a separate system which makes deploying Kafka more complicated for system administrators
 - Metadata failover is near-instantaneous with KRaft

## Kafka Controller
- In a `Kafka cluster`, **one (and only one)** of the brokers serves as the `controller`, which is responsible for managing the states of partitions and replicas and for performing administrative tasks like **reassigning partitions**. The election of that broker happens thanks to `Zookeeper`.
- `Kafka Controller` registers handlers to be notified about changes in Zookeeper and propagate them across brokers in a Kafka cluster.

## Kafka Connect
- by default any error encountered during conversion or transformation will cause connector to fail
- connector configuration can also enable tolerating such errors by skipping them
- it is possible to report errors to `dead letter queue`. Use `errors.deadletterqueue.topic.name` and optionally `errors.deadletterqueue.context.headers.enable=true`
- Kafka Connect can provide `exactly-once semantics` for both sink connectors and source connectors, but achieving this support requires configuring the correct worker properties in the cluster. The ability to achieve exactly-once semantics is highly dependent on the type of connector and its design. Connectors must be designed to take advantage of the capabilities of the Kafka Connect framework for exactly-once processing.
- **Kafka Connect** supports two modes of execution: **standalone (single process)** and **distributed**. In standalone mode, all work is performed in a single process, making it simpler to set up. However, standalone mode lacks some features such as fault tolerance.
- required configurations include `bootstrap.servers`, `key.converter`, `value.converter`. The `plugin.path` configuration specifies the location of Kafka Connect plugins and is essential for quick setups
- Distributed vs Standalone mode??

## Kafka CLI commands
- kafka-topics.sh
	- **--topics-with-overrides:** If set when describing topics, only show topics that have overridden configs.
	- **--unavailable-partitions:** If set when describing topics, only show partitions whose **leader is not available**.
	- **--under-min-isr-partitions:** If set when describing topics, only show partitions whose ISR count is less than the configured minimum.
	- **--under-replicated-partitions:** If set when describing topics, only show under replicated partitions.
- to list all topics use command `./bin/kafka-topics.sh --bootstrap-server localhost:9092 --list`
- `kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 --add --allow-principal User:kafkauser --operation read --topic pageviews` - allow the user `kafkauser` to read from, but not to write to `pageviews` topic
- `bin/kafka-configs.sh --zookeeper localhost:2181 --alter --add-config 'producer_byte_rate=10485760,consumer_byte_rate=20971520' --entity-name test_client --entity-type clients` - prodicer quota = 10MB, consumer quota = 20MB

## Sending Messages with Null
- Value: Message is deleted.
- Key: Stored with round-robin algorithm.

## Finding Partitions without Leader
- Command: `kafka-topics.sh --zookeeper localhost:2181 --describe --unavailable-partitions`.

## High Water Mark
- HWM is the offset value of the last message that has been successfully replicated to all replicas of a partition.
- Is maintained by the leader replica of a partition
- Is used by consumer to detetmine the latest available message

## Offset
- offset can be commited manually via `commitSync()` method

## ksqlDB
- `DESCRIBE EXTENDED` is used to provide detailed information about a stream or table, including the serialization format. 
- `SHOW STREAMS` and `EXPLAIN <query>` statements do not interact with KAfkaa but directly communicate with `ksqlDB` server. 
- `ksqlDB` supports exactly-once processing - see `processing.guarantees` setting
- when running a query against `topic` with multiple partitions, only the `ksqlDB` servers corresponding to the number of partitions perform the work, while the idle servers have minimal resource impact
- `ksqlDB` has a limitation in that it **doesn't support structured keys**, preventing the creation of a stream from a windowed aggregate
- use `ksql> exit` command and then `confluent stop ksql` (if Confluent CLI is in use) to to exit `ksqlDB`
- following queries read/write data to Kafka `CREATE TABLE AS SELECT`, `COUNT`, `CREATE STREAM AS SELECT`
- securing the `ksqlDB` **command topic ensures that sensitive metadata related to DDL statements and query termination is protected**. This is particularly important for managing and controlling access to ksqlDB operations.

## Controller
- Elected by Zookeeper ensemble.
- Responsible for partition leader election.

## Security
- `Zero Copy Data Transfer` consist on removing the second and third data copies, making the data being transfered directly from the read buffer to the socket buffer. This feature is disabled when `SSL` is enabled.
- security protocol of each listener is defined in the `listener.security.protocol.map` configuration. Possible options are `PLAINTEXT`, `SSL`, `SASL_PLAINTEXT`, `SASL_SSL`
- to connect to a Kafka cluster over SSL you set `security.protocol=SSL`
- available auth. mchanisms: `mTLS`, `HTTP Basic Auth`, `SASL/PLAIN` 
- `ACL` is used for authorization, not for authentication!

## Testing
- `ConsumerRecordFactory` converts test data into the format accepted by `TopologyTestDriver`
- `MockProducer` would allow you to simulate the interactions between your code and KafkaProducer.

## Consumer Group
- Explanation of `group.id`.

## Callback for Broken Response
- Invoked when a broken response is received.

## Partition Rebalance
- Triggered by events like consumer shutdown, new consumer addition, or increasing partitions of a topic.

## Partition Hashing
- Increasing partitions causes new message keys to be hashed differently.

## Automatic Topic Creation
- Kafka creates topics automatically under certain conditions.

## Offset Committing
- Explanation of how consumers commit offsets.

## Data Transformation with Kafka Streams
- Usage of Kafka Streams for data transformation.

## Graceful Consumer Shutdown
- Steps for stopping a consumer gracefully.

## Kafka Streams Joins
- Description of windowed joins.

## Message Delivery Guarantees
- Explanation of different delivery guarantees.

## GlobalKtable
- Definition of GlobalKtable and co-partitioning.

## Configuration Parameters
1. `log.cleanup.policy=delete(default), cleanup, both`
2. `records-lag-max` maximum lag in terms of number of records for any partition
3. `auto.offset.rest`
4. `max.tasks` for Kafka Connect.
5. `key.converter.schemas.enable` and `value.converter.schemas.enable`.
6. `enable.idempotence`.
7. `log.retention.hours`, `log.retention.minutes`, `log.retention.ms`.
8. `errors.log.enable`, `errors.deadletterqueue.topic.name`, `errors.deadletterqueue.context.headers.enable`
9. The `offsets.retention.minutes` configuration in `Kafka` determines how long `Kafka` remembers offsets in a special topic. The default value is 10,080 minutes (7 days), and it affects the behavior when an application is restarted after being stopped for a while. Increasing this value is **recommended** to avoid reprocessing data on application restart due to offsets being deleted by the broker(s).
10. `unclean.leader.election.enable=false` unclear leader election is disabled, the topic will not accept new messages until an **In-Sync Replica** becomes available for leader election. 
11. `unclean.leader.election.enable=true` one of the out-of sync replicas can be elected as a new leader.

## Broker configuration
1. `broker.id` every Kafka broker must have an integer identifier.
2. `port` if port lower than 1024 broker must be run as root
3. `zookeeper.connect` Zookeeper  host
4. `log.dirs` list of paths to store messages
5. `auto.create.topics.enable` create topics when producer starts write messages, consumer starts read messages, client request topic metadata

## Topic configuration
1. `num.partitions` determines how many partitions a new topic is created with
2. `log.retention.ms` how long retain messages
3. `log.retention.minutes`
4. `log.retention.hours` default value is 168 (one week), the smaler value from all `log.retention.` is choosen
5. `log.retention.bytes` applied per partition
6. `log.segment.bytes` default is 1GB
7. `log.segment.ms`
8. `message.max.bytes` defeault is 1MB

## Producer
`fire-and-forget` we send a message to the server and don't really care it it arrives or not. Some messages will get lost.
`synchronous send` we send a message, the `send()` method returns `Future` amd we use `get()` to wait on the future ans see it it was successful or not
`asynchronous send` we call the `send()` method with a callback function which gets triggered when it receives a response from the Kafka broker. Callback function must implement `org.apache.kafka.clients.producer.Callback` interface which has a single function `onCompletion(RecordMetadata rm, Exception e)`

## Producer configuration
1. `bootstrap.servers` list of `host:port` pairs of brokers. MANDATORY
2. `key.serializer` name of class that will be used to serialize keys. Commons are `ByteArraySerializer`, `IntegerSerializer`, `StringSerializer`. Custom serializer must implement `org.apache.kafka.common.serialization.Serializer` interface. MANDATORY
3. `value.serializer` name of the class that will be used to serialize the values of the record. MANDATORY
4. `acks=0,1,all`
5. `buffer.memory` this sets the amount of memory the producer will use to buffer messages waiting to be sent to brokers
6. `compression.type` By default, messages are sent uncompressed. This parameter can be set to snappy, gzip, or lz4, in which case the corresponding compression algorithms will be used to compress the data before sending it to the brokers.
7. `retries`
8. `batch.size`
9. `linger.ms` linger.ms controls the amount of time to wait for additional messages before sending the current batch
10. `client.id` any string, used in logs,metrics and for quota
11. `max.in.flight.requests.per.connection` how many resposnes can be send to the server without receiving responses. If set to 1 will guarantee that messages will be written in order.
12. `timeout.ms, request.timeout.ms, and metadata.fetch.timeout.ms`
13. `max.block.ms` how long the producer will block when calling `send()`
14. `max.request.size`

## Consumer configuration
1. `fetch.min.bytes`
2. `fetch.max.wait.ms`
3. `fetch.max.wait.ms`
4. `max.partition.fetch.bytes`
5. `session.timeout.ms`
6. `auto.offset.reset`
7. `enable.auto.commit`
8. `partition.assignment.strategy`
9. `client.id`
10. `max.poll.records`
11. `receiver.buffer.bytes.`, `send.buffer.bytes`