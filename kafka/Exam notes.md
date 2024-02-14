# Kafka Cheat Sheet

## Data Formats with Confluent REST Proxy
- Confluent REST Proxy natively supports various data formats.

## Topic Log Compaction
- After cleanup, only one message per key is retained with the latest value. At least last update for each message key is retained.
- Log compaction is evaluated every time a segment is closed.
- Tombstone record is a record with `null` payload. It is a marker for record deletion
- log compaction is enabled via `log.cleanup.policy=compact` Default is `delete` - old segments will be discarded when their retention time or size has been reached

## Metrics
- `records-lag-max`: Current lag (number of messages behind the broker)
- `UnderReplicatedPartitions` means that data is not being replicated to enough number of brokers

## Java API
- `producer.send()`: Returns `Future<RecordMetadata>`.
- five major APIs in Kafka: `Producer`, `Consumer`, `Streams`, `Connect`, `Admin`

## Windowing 
- `Tumbling time window` - time based, fixes size, non-overlapping, gap-less
- `Hopping time window` - time based, fixed size, overlapping
- `Sliding time window` - time based, fixed size, overlapping, work on differences between record timestamps
- `Session window` - session based, dynamically-sized, non-overlapping, data-drven windows

## Avro
- `SpecificRecords` are generated from Avro Schema using Maven/Gradle plugin.
- Schema evolution: `forward`, `backward`, `breaking.
- Schema registry resides as a separate JVM component.
- primitive types: `bytes`, `string`, `null`, `boolean`, `int`, `long`, `float`, `double`

## Consumer
- when a `consumer` wants to join a group, it sends a `JoinGroup` request to the `group coordinator` 
- the first consumer to join the group becomes the `group leader`
- `group leader` receives a list of all consumers in the group from the group coordinator and is responsible for assigning a subset of partitions to each consumer
- `RangeAssignor` assignment strategy
- `RoundRobinAssignor` assignment strategy
## Streams
- User topics: created manually. Do not rely on auto-creation (may be disabled, default settings may not be what you want)
- Internal topics are prefixed by `application.id`.
- It is crucial to close each `iterator`. Failure to close an `iterator` can lead to `Out-Of-Memory` issues.
- `Streams` scales by allowing multiple thread of executions within one instance  of the application and by supporting load balancing between distributed instances
- `Stream` engine parallelizes execution of a topology by splitting it into tasks. Number of tasks depends on the number of partitions. Each task is responsible for a subset of the partitions

## Confluent Control Center
`CCC` is a self-hosted GUI with dashboards to centrilized management and monitoring of key components of the platform, including clusters, brokers, schemas, topics, messages, connectors, ksqlDB queries, security, replication and more

## Message Delivery Guarantees
- `At-most once` - message loss is possible if the producer doesn't retry on failures
- `At-least once` - every message is guaranteed to be persisted in Kafka at least once. There is no chance of message loss but the message can be duplicated if the producer retries when the message is already persisted
- `Exactly once` - message is guaranteed to be persisted in Kafka exactly once without any duplicates and data loss even there is a broker failure or producer retry

## Zookeeper
- used to store persistent cluster metadata
- Majority for Zookeeper ensemble `ensemble`.
- default client port: `2181`
- `ensemble` is a multiple nodes Zookeeper deployment. It  is a set of `2n + 1` nodes.
- Number `QN = (N + 1) / 2` defines the size of `quorum` (majority rule) where `n` is the total number of servers.  `Quorum` is minimal number of server required to run the Zookeeper
- each node is called `zNode`
- each `zNode` has a `path`
- `zNodes` can be persisten or ephemeral
- each `zNode` can store data
- you can not rename a `zNode`
- each `zNode` can be watched for changes

## KRaft
 - ZooKeeper is a separate system which makes deploying Kafka more complicated for system administrators
 - Metadata failover is near-instantaneous with KRaft

## Kafka Connect
- by default any error encountered during conversion or transformation will cause connector to fail
- connector configuration can also enable tolerating such errors by skipping them
- it is possible to report errors to `dead letter queue`. Use `errors.deadletterqueue.topic.name` and optionally `errors.deadletterqueue.context.headers.enable=true`
- Distributed vs Standalone mode??
 
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

## Controller
- Elected by Zookeeper ensemble.
- Responsible for partition leader election.

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
1. `log.cleanup.policy`
2. `auto.offset.rest`
3. `max.tasks` for Kafka Connect.
4. `key.converter.schemas.enable` and `value.converter.schemas.enable`.
5. `enable.idempotence`.
6. `log.retention.hours`, `log.retention.minutes`, `log.retention.ms`.
7. `errors.log.enable`, `errors.deadletterqueue.topic.name`, `errors.deadletterqueue.context.headers.enable`
9. 
