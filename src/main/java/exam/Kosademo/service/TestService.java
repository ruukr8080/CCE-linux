package exam.Kosademo.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jcraft.jsch.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

@Slf4j
@Service
@RequiredArgsConstructor
public class TestService {

    @Value("${result.json.path}")
    private String resultJsonPath;

    private final S3Service s3;
    public void connecting(String username, String password, String host, int port) throws JSchException {
        JSch jsch = new JSch();
        Session session = jsch.getSession(username, host, port);
        try {
            session.setPassword(password);
            session.setConfig("StrictHostKeyChecking", "no");
            session.connect();
            Channel channel = session.openChannel("exec");
            channel.connect();
            log.info("커넥성공");
        }catch (JSchException e ){
            e.getCause();
        }
    }
    public void test(String username, String password, int port, String host,
                             String centosScriptPath, String resultJsonPath) throws JSchException, SftpException {
        JSch jsch = new JSch();
        Session s = jsch.getSession(username, host, port);
        try {
            s.setPassword(password);
            s.setConfig("StrictHostKeyChecking", "no");
            s.connect();
            Channel channel = s.openChannel("exec");
            channel.connect();
            s3.executeCommand(s, "sudo bash CentOS6.sh");
            s3.executeCommand(s, "cd ~");
            s3.executeCommand(s, "sudo bash agent.sh");
            Thread.sleep(20000);
            s3.executeCommand(s, "rm agent.sh");
            s3.executeCommand(s, "rm result.json");
            Thread.sleep(2000);
            s3.executeCommand(s, "y");
        } catch (InterruptedException | IOException e) {
            Thread.currentThread().interrupt();
        } finally {
            if (s != null) {
                s.disconnect();
            }
        }
    }
    public void renameJsonFile(String jsonFilePath) throws IOException {
        Path filePath = Paths.get(jsonFilePath);
        ObjectMapper objectMapper = new ObjectMapper();
        JsonNode jsonNode = objectMapper.readTree(filePath.toFile());

        JsonNode serverInfo = jsonNode.get("Server_Info");
        String uniqId = serverInfo.get("UNIQ_ID").asText();

        String newFileName = "result_" + uniqId + ".json";
        Path newFilePath = filePath.resolveSibling(newFileName);

        Files.move(filePath, newFilePath, StandardCopyOption.REPLACE_EXISTING);
    }
}


