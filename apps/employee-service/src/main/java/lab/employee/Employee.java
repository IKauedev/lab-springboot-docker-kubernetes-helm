package lab.employee;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "employee")
public record Employee(@Id String id, String name, String position, Long departmentId) {
}
