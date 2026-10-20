package lab.department;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
public class DepartmentController {

    private final DepartmentRepository repository;
    private final RestClient employees;

    public DepartmentController(DepartmentRepository repository, @Value("${employee.url}") String employeeUrl) {
        this.repository = repository;
        this.employees = RestClient.builder().baseUrl(employeeUrl).build();
    }

    @GetMapping("/")
    public List<Department> findAll() {
        return repository.findAll();
    }

    @PostMapping("/")
    public Department add(@RequestBody Department department) {
        return repository.save(department);
    }

    @GetMapping("/{id}")
    public Department findById(@PathVariable Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "department " + id));
    }

    /** Chamada entre serviços: department -> employee, via o Service criado pelo chart. */
    @GetMapping("/{id}/employees")
    public Map<String, Object> withEmployees(@PathVariable Long id) {
        Department department = findById(id);
        List<Map<String, Object>> list = employees.get()
                .uri("/department/{id}", id)
                .retrieve()
                .body(new ParameterizedTypeReference<>() {});
        return Map.of("department", department, "employees", list);
    }

    @GetMapping("/whoami")
    public Map<String, String> whoami() {
        return Map.of(
                "app", "department",
                "pod", System.getenv().getOrDefault("POD_NAME", "local"),
                "version", System.getenv().getOrDefault("APP_VERSION", "dev"));
    }
}
