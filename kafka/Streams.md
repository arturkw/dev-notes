A **stream** is the most important abstraction provided by Kafka Streams: it represents an unbounded, continuously updating data set. A stream is an ordered, replayable, and fault-tolerant sequence of immutable data records, where a **data record** is defined as a key-value pair.

A [**stream processor**](https://kafka.apache.org/23/documentation/streams/developer-guide/processor-api#defining-a-stream-processor) is a node in the processor topology; it represents a processing step to transform data in streams by receiving one input record at a time from its upstream processors in the topology, applying its operation to it, and may subsequently produce one or more output records to its downstream processors. There are two special processors in the topology:
- **Source Processor**: A source processor is a special type of stream processor that does not have any upstream processors. It produces an input stream to its topology from one or multiple Kafka topics by consuming records from these topics and forwarding them to its down-stream processors.
- **Sink Processor**: A sink processor is a special type of stream processor that does not have down-stream processors. It sends any received records from its up-stream processors to a specified Kafka topic.

An **aggregation** operation takes one input stream or table, and yields a new table by combining multiple input records into a single output record. Examples of aggregations are computing counts or sum. In the `Kafka Streams DSL`, an input stream of an `aggregation` can be a KStream or a KTable, but the output stream will always be a KTable.






https://kafka.apache.org/23/documentation/streams/
https://kafka.apache.org/23/documentation/streams/developer-guide/dsl-api.html#stateless-transformations
https://docs.confluent.io/platform/current/streams/concepts.html#duality-of-streams-and-tables
