package lab.department;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "department")
public record Department(@Id Long id, String name) {
}
