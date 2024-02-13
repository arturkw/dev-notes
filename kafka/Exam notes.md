# Kafka Cheat Sheet

## Data Formats with Confluent REST Proxy
- Confluent REST Proxy natively supports various data formats.

## Topic Log Compaction
- After cleanup, only one message per key is retained with the latest value. At least last update for each message key is retained.
- Log compaction is evaluated every time a segment is closed.
- Tombstone record is a record with `null` payload. It is a marker for record deletion
- log compaction is enabled via `log.cleanup.policy=compact` Default is `delete` - old segments will be discarded when their retention time or size has been reached

## Topic Metrics
- `records-lag-max`: Current lag (number of messages behind the broker).

## Java API
- `producer.send()`: Returns `Future<RecordMetadata>`.

## Avro
- `SpecificRecords` are generated from Avro Schema using Maven/Gradle plugin.
- Schema evolution: `forward`, `backward`, `breaking.
- Schema registry resides as a separate JVM component.

## Streams
- User topics: created manually. Do not rely on auto-creation (may be disabled, default settings may not be what you want)
- Internal topics are prefixed by `application.id`.

## Zookeeper
- used to store persistent cluster metadata
- Majority for Zookeeper ensemble `ensemble`.
- default client port: `2181`
- `ensemble` is a multiple nodes Zookeeper deployment. It  is a set of `2n + 1` nodes.
- Number `QN = (N + 1) / 2` defines the size of `quorum` (majority rule) where `n` is the total number of servers.  `Quorum` is minimal number of server required to run the Zookeeper

## KRaft
 - ZooKeeper is a separate system which makes deploying Kafka more complicated for system administrators
 - Metadata failover is near-instantaneous with KRaft
 
## Sending Messages with Null
- Value: Message is deleted.
- Key: Stored with round-robin algorithm.

## Finding Partitions without Leader
- Command: `kafka-topics.sh --zookeeper localhost:2181 --describe --unavailable-partitions`.

## High Water Mark
- HWM is the offset value of the last message that has been successfully replicated to all replicas of a partition.
- Is maintained by the leader replica of a partition
- Is used by consumer to detetmine the latest available message

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
