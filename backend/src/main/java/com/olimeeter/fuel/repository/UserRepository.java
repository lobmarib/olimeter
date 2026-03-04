package com.olimeeter.fuel.repository;

import com.olimeeter.fuel.models.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, String> {

    Optional<User> findByKeycloakSub(String keycloakSub);

    Optional<User> findByKeycloakUsername(String keycloakUsername);

    Optional<User> findByKeycloakEmail(String keycloakEmail);

    java.util.List<User> findByFacilityId(UUID facilityId);

    boolean existsByKeycloakSub(String keycloakSub);
}
