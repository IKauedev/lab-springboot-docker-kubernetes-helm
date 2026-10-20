package lab.employee;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
public class EmployeeController {

    private final EmployeeRepository repository;

    public EmployeeController(EmployeeRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/")
    public List<Employee> findAll() {
        return repository.findAll();
    }

    @PostMapping("/")
    public Employee add(@RequestBody Employee employee) {
        return repository.save(new Employee(null, employee.name(), employee.position(), employee.departmentId()));
    }

    @GetMapping("/{id}")
    public Employee findById(@PathVariable String id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "employee " + id));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String id) {
        repository.deleteById(id);
    }

    @GetMapping("/department/{departmentId}")
    public List<Employee> findByDepartment(@PathVariable Long departmentId) {
        return repository.findByDepartmentId(departmentId);
    }

    /** Mostra qual pod respondeu e qual versão está rodando: útil para ver réplicas e rollouts do Helm. */
    @GetMapping("/whoami")
    public Map<String, String> whoami() {
        return Map.of(
                "app", "employee",
                "pod", System.getenv().getOrDefault("POD_NAME", "local"),
                "version", System.getenv().getOrDefault("APP_VERSION", "dev"));
    }
}
