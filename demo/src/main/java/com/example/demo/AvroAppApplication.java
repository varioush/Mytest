package com.example.demo;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.confluent.kafka.schemaregistry.client.CachedSchemaRegistryClient;
import io.confluent.kafka.schemaregistry.client.SchemaRegistryClient;
import io.confluent.kafka.schemaregistry.client.rest.exceptions.RestClientException;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericDatumReader;
import org.apache.avro.generic.GenericRecord;
import org.apache.avro.io.DatumReader;
import org.apache.avro.io.Decoder;
import org.apache.avro.io.DecoderFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@SpringBootApplication
public class AvroAppApplication {

    public static void main(String[] args) {
        SpringApplication.run(AvroAppApplication.class, args);
    }
}

@Configuration
class KafkaConfig {

    @Bean
    public ProducerFactory<String, GenericRecord> producerFactory() {
        Map<String, Object> configProps = new HashMap<>();
        configProps.put("bootstrap.servers", "localhost:9092");
        configProps.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        configProps.put("value.serializer", "io.confluent.kafka.serializers.KafkaAvroSerializer");
        configProps.put("schema.registry.url", "http://localhost:8081");
        return new DefaultKafkaProducerFactory<>(configProps);
    }

    @Bean
    public KafkaTemplate<String, GenericRecord> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }

    @Bean
    public SchemaRegistryClient schemaRegistryClient() {
        return new CachedSchemaRegistryClient("http://localhost:8081", 100);
    }
}

@RestController
@RequestMapping("/produce")
class ProducerController {

    private final KafkaTemplate<String, GenericRecord> kafkaTemplate;
    private final SchemaRegistryClient schemaRegistryClient;

    public ProducerController(KafkaTemplate<String, GenericRecord> kafkaTemplate, SchemaRegistryClient schemaRegistryClient) {
        this.kafkaTemplate = kafkaTemplate;
        this.schemaRegistryClient = schemaRegistryClient;
    }

    @PostMapping("/send")
    public String sendMessage(@RequestBody Map<String, Object> message, @RequestParam String topic) throws IOException, RestClientException {
        String subject = topic + "-value";
        Schema schema = new Schema.Parser().parse(schemaRegistryClient.getLatestSchemaMetadata(subject).getSchema());
        GenericRecord record = AvroUtils.createGenericRecord(schema, message);
        kafkaTemplate.send(topic, record);
        return "Message sent successfully";
    }
}

class AvroUtils {

    public static GenericRecord createGenericRecord(Schema schema, Map<String, Object> data) {
        GenericRecord record = new org.apache.avro.generic.GenericData.Record(schema);
        schema.getFields().forEach(field -> {
            if (data.containsKey(field.name())) {
                record.put(field.name(), data.get(field.name()));
            } else if (field.defaultVal() != null) {
                record.put(field.name(), field.defaultVal());
            }
        });
        return record;
    }
}

@Service
class KafkaConsumerService {

    private final SchemaRegistryClient schemaRegistryClient;

    public KafkaConsumerService(SchemaRegistryClient schemaRegistryClient) {
        this.schemaRegistryClient = schemaRegistryClient;
    }

    @KafkaListener(topics = "avro-topic", groupId = "avro-consumer-group")
    public void consumeMessage(GenericRecord record) {
        try {
            ObjectMapper objectMapper = new ObjectMapper();
            Map<String, Object> recordMap = new HashMap<>();
            record.getSchema().getFields().forEach(field -> recordMap.put(field.name(), record.get(field.name())));
            String json = objectMapper.writeValueAsString(recordMap);
            System.out.println("Received message: " + json);
        } catch (Exception e) {
            System.err.println("Error processing message: " + e.getMessage());
        }
    }
}
