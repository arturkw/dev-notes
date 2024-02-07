kafka-topics --botstrap-server <server> --create --topic <topicName> --partitions <noOfPartitions> --replication-factor <replicas>

kafka-topics --botstrap-server <server> --describe --topic <topicName> 

kafka-console-consumer --bootstrap-server <server> --topic <topicName> --group <groupName>