# Kafka Cheat Sheet

## Data Formats with Confluent REST Proxy
- Confluent REST Proxy natively supports various data formats.

## Topic Log Compaction
- After cleanup, only one message per key is retained with the latest value.
- Log compaction is evaluated every time a segment is closed.

## Topic Metrics
- `records-lag-max`: Current lag (number of messages behind the broker).

## Java API
- `producer.send()`: Returns `Future<RecordMetadata>`.

## Avro
- `SpecificRecords` are generated from Avro Schema using Maven/Gradle plugin.
- Schema evolution: `forward`, `backward`, `breaking.
- Schema registry resides as a separate JVM component.

## Streams
- Internal topics are prefixed by `application.id`.

## Zookeeper
- Majority for Zookeeper ensemble `ensemble`.

## Sending Messages with Null
- Value: Message is deleted.
- Key: Stored with round-robin algorithm.

## Finding Partitions without Leader
- Command: `kafka-topics.sh --zookeeper localhost:2181 --describe --unavailable-partitions`.

## High Watermark
- Definition of high watermark.

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
