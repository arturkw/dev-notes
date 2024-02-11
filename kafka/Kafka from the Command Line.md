kafka-topics --botstrap-server <server> --create --topic <topicName> --partitions <noOfPartitions> --replication-factor <replicas>

kafka-topics --botstrap-server <server> --describe --topic <topicName> 

kafka-console-consumer --bootstrap-server <server> --topic <topicName> --group <groupName>

Show config:
kafka-configs --bootstrap-server <server> --entity-type brokers --entity-name 1 --describe

Ammend config:
kafka-configs --bootstrap-server <server> --entity-type brokers --entity-name 1 --alter --add-config paramName=value