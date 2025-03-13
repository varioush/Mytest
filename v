import org.apache.catalina.LifecycleException;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Tomcat;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.inject.*;
import org.mindrot.jbcrypt.BCrypt;
io.jsonwebtoken.*;

import java.io.File;
import java.io.IOException;
import java.sql.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Date;

public class EmbeddedTomcat {
    private static final int PORT = 8080;
    private static final String CONTEXT_PATH = "/";
    private static final Set<String> PUBLIC_ENDPOINTS = Set.of("/api/login");

    public static void main(String[] args) throws LifecycleException, SQLException {
        Tomcat tomcat = new Tomcat();
        tomcat.setPort(PORT);
        tomcat.setBaseDir(System.getProperty("java.io.tmpdir"));

        // Create a default context (No webapp, only REST APIs)
        StandardContext ctx = (StandardContext) tomcat.addContext(CONTEXT_PATH, new File(".").getAbsolutePath());
        ctx.setReloadable(false);

        // Setup Guice Injector
        Injector injector = Guice.createInjector(new CommandModule());
        ApiServlet apiServlet = injector.getInstance(ApiServlet.class);

        // Add a single servlet to handle all API requests
        Tomcat.addServlet(ctx, "ApiServlet", apiServlet);
        ctx.addServletMappingDecoded("/api/*", "ApiServlet");

        // Initialize database
        injector.getInstance(UserService.class).initializeDatabase();

        // Start Tomcat
        tomcat.start();
        System.out.println("Embedded Tomcat started on port " + PORT);
        tomcat.getServer().await();
    }
}

class User {
    private String userId;
    private String passwordHash;
    private String ftl;
    private String mid;

    public User(String userId, String password, String ftl, String mid) {
        this.userId = userId;
        this.passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
        this.ftl = ftl;
        this.mid = mid;
    }

    public String getUserId() { return userId; }
    public String getPasswordHash() { return passwordHash; }
    public String getFtl() { return ftl; }
    public String getMid() { return mid; }

    public boolean verifyPassword(String password) {
        return BCrypt.checkpw(password, passwordHash);
    }
}

class UserService {
    private static final String JDBC_URL = "jdbc:h2:mem:testdb";
    private static final String JDBC_USER = "sa";
    private static final String JDBC_PASSWORD = "";

    public void initializeDatabase() throws SQLException {
        try (Connection conn = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASSWORD);
             Statement stmt = conn.createStatement()) {
            stmt.execute("CREATE TABLE users (userId VARCHAR(255) PRIMARY KEY, passwordHash VARCHAR(255), ftl VARCHAR(255), mid VARCHAR(255))");
        }
    }

    public void saveUser(User user) throws SQLException {
        try (Connection conn = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASSWORD);
             PreparedStatement stmt = conn.prepareStatement("INSERT INTO users (userId, passwordHash, ftl, mid) VALUES (?, ?, ?, ?)");) {
            stmt.setString(1, user.getUserId());
            stmt.setString(2, user.getPasswordHash());
            stmt.setString(3, user.getFtl());
            stmt.setString(4, user.getMid());
            stmt.executeUpdate();
        }
    }

    public List<User> listUsers() throws SQLException {
        List<User> users = new ArrayList<>();
        try (Connection conn = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASSWORD);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT * FROM users")) {
            while (rs.next()) {
                users.add(new User(rs.getString("userId"), rs.getString("passwordHash"), rs.getString("ftl"), rs.getString("mid")));
            }
        }
        return users;
    }

    public User authenticate(String userId, String password) throws SQLException {
        try (Connection conn = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASSWORD);
             PreparedStatement stmt = conn.prepareStatement("SELECT * FROM users WHERE userId = ?")) {
            stmt.setString(1, userId);
            ResultSet rs = stmt.executeQuery();
            if (rs.next()) {
                User user = new User(rs.getString("userId"), rs.getString("passwordHash"), rs.getString("ftl"), rs.getString("mid"));
                if (user.verifyPassword(password)) {
                    return user;
                }
            }
        }
        return null;
    }
}

class JwtUtil {
    private static final String SECRET_KEY = "mySecretKey";

    public static String generateToken(String userId) {
        return Jwts.builder()
                .setSubject(userId)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + 3600000))
                .signWith(SignatureAlgorithm.HS256, SECRET_KEY)
                .compact();
    }

    public static boolean validateToken(String token) {
        try {
            Jwts.parser().setSigningKey(SECRET_KEY).parseClaimsJws(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}

class CommandModule extends AbstractModule {
    @Override
    protected void configure() {
        bind(UserService.class).asEagerSingleton();
    }
}
