1. Data formats natively available with Confluent REST Proxy
2. Topic log compaction:
 - after cleanup, only one message per key is retained with the latest value
 - how often log compaction is evaluated: every time a segment is closed
3. Topic metrics:
 - records-lag-max - this metric shows the current lag (number of messages behind the broker)
 4. Java API
 - what is returned by a `producer.send()`: `Future<RecordMetadata>`
5. Avro
- `SpecificRecords` are generated from `Avro Schema` and `Maven/Gradle` plugin
- `forward`, `backward`, `breaking` schema evolutions
- schema registry resides as a separate JVM component
1. Streams
- internal topics are prefixed by `application.id`
2. Zookeeper
- majority for Zookeper ensamble `ensamble`
3. Sending a message with `null` as:
-  value: message is deleted 
- key: will be stored with round-robin algorithm
4. How to find all partitions without leader: `kafka-topics.sh --zookeeper localhost:2181 --describe --unavailable-partitions`
5. What is a `high watermark`
6. Controller:
- is elected by Zookeeper ensemble
- is responsible for partition leader election
7. Consumer group
- explain `group.id`
8. Callback is invoked when a broken response is received.
9. Partition rebalance for a consumer group is triggered by:
- a consumer in a consumer group shuts down
- add a new consumer to consumer group
- increase partitions of a topic
10. Increasing the number of partition causes new messages keys to get hashed differently, and breaks the guarantee "same keys goes to the same partition". Kafka logs are immutable and the previous messages are not re-shuffled
11. Kafka creates topic automatically when:
- `auto.create.topics=true`
- producer sends message to a topic
- consumer reads message from a topic
- client requests metadata for a topic
12. How does a consumer commit offsets in Kafka: consumers do not directly write to `__consumer_offsets` topic. They instead interact with a broker that has been elected to manag that topic, which is a `Group Coordinator` broker
13. To transform data from a Kafka topic to another one Kafkta Streams should be used.
14. To stop consumer gracefully: call `consumer.wakeUp()` and try-catch `WakeUpException`
15. Kafka Streams joins that are always windowed joins: `KStream-KStream` join
16. `At-most-once`, `Exactly-once`, `At-least-once`
17. `GlobalKtable`, co-partition









Config parameters:
1. `log.cleanup.policy`
2. `auto.offset.rest`
3. `max.tasks` for Kafa Connect
4. `key.converter.schemas.enable` and `value.converter.schemas.enable`
5. `enable.idempotence`
6. `log.retention.hours`, `log.retention.minutes`, `log.retention.ms`