package exam.Kosademo.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jcraft.jsch.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.ResourceUtils;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.*;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Map;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class S3Service {
    private final S3Client s3Client;
    private final ObjectMapper objectMapper;

    @Value("${aws.s3.bucket.name}")
    private String bucketName;

    @Value("${json.directory}")
    private String jsonFileDirectory;

    @Value("${result.json.path}")
    private String resultJsonPath;

    @Value("${centos.script.path}")
    private String centosScriptPath;

    public void runCheck(String username, String password, String host, int port, String scriptPath, String jsonPath) throws JSchException, SftpException, IOException, InterruptedException {
        JSch jsch = new JSch();
        Session session = jsch.getSession(username, host, port);
        session.setPassword(password);
        session.setConfig("StrictHostKeyChecking", "no");
        session.connect();
        log.info("커넥 성공");
        ChannelSftp sftp = (ChannelSftp) session.openChannel("sftp");
        sftp.connect();
        sftp.put(getPath("CentOS6.sh"), "agent.sh");
        log.info("업로드 성공.");
        ChannelExec exec = (ChannelExec) session.openChannel("exec");
        String output = executeCommand(session, "sudo bash agent.sh");
        exec.setCommand(output);
        log.info("커맨드 실행.  output: {}", output);
        exec.setErrStream(System.err);
        InputStream is = exec.getInputStream();
        exec.connect();
        log.info("exec 실행. {}",exec);
        StringBuilder sb = new StringBuilder();
        BufferedReader bfr = new BufferedReader((new InputStreamReader(is)));
        String line;
        while ((line = bfr.readLine()) != null) {
            sb.append(line).append("\n");}
        log.info("작성 완료하고 exec채널 종료");
        exec.disconnect();
        sftp.get("result.json", getPath("result.json"));
        log.info("result 다운로드");
        exec = (ChannelExec) session.openChannel("exec");
        exec.connect();
        exec.setCommand("rm agent.sh result.json");
        exec.disconnect();
        sftp.disconnect();
        session.disconnect();
        log.info("exec sftop session 종료.");
        downloadLatestJsonFile();
    }
    public Optional<File> findLatestJsonFile() {
        File dir = new File(jsonFileDirectory);
        File[] jsonFiles = dir.listFiles((d, name) -> name.endsWith(".json"));
        File latestFile = jsonFiles[0];
        if (!dir.exists() || !dir.isDirectory()) {
            log.error("result.json파일 없음. : {}", jsonFileDirectory);
            return Optional.empty();
        }
        if (jsonFiles == null || jsonFiles.length == 0) {
            log.warn(".josn파일이 디렉토리에 없음 : {}", jsonFileDirectory);
            return Optional.empty();
        }
        for (File file : jsonFiles) {
            if (file.lastModified() > latestFile.lastModified()) {
                latestFile = file;
            }
        }
        return Optional.of(latestFile);
    }
    public String getPath(String fileName) {
        String ec2Path = "/root/.ssh/kosapro/src/main/resources";
        String resultPath = "result/";
        String localPath = "C:\\새 폴더 (2)\\kosapro\\src\\main\\resources";
        String classPath = "script/";
        if (fileName == "CentOS6.sh") {
            log.info("call CentOS6");
            return Paths.get(localPath, fileName).toString();
        } else if (fileName == "result.json") {
            log.info("call localPath");
            return Paths.get(localPath, fileName).toString();
        }
        Paths.get(localPath, fileName).toString();
        return localPath;
    }
    public String executeCommand(Session session, String command) throws JSchException, IOException {
        ChannelExec channel = (ChannelExec) session.openChannel("exec");
        channel.setCommand(command);
        channel.setInputStream(null);
        channel.setErrStream(System.err);
        InputStream in = channel.getInputStream();
        channel.connect();
        StringBuilder output = new StringBuilder();

        byte[] tmp = new byte[1024];
        while (true) {
            while (in.available() > 0) {
                int i = in.read(tmp, 0, 1024);
                if (i < 0) break;
                output.append(new String(tmp, 0, i));
            }
            if (channel.isClosed()) {
                if (in.available() > 0) continue;
                output.append("exit-status: ").append(channel.getExitStatus());
                break;
            }
            try {
                Thread.sleep(1000);
            } catch (Exception e) {
            }
        }
        channel.disconnect();
        return output.toString();
    }
    private void cleanupFiles(Session session, String... fileNames) throws JSchException, IOException {
        StringBuilder command = new StringBuilder("rm");
        for (String fileName : fileNames) {
            command.append(" ").append(fileName);
        }
        executeCommand(session, command.toString());
    }
    public void uploadJsonFile(File jsonFile) {
        try {
            s3Client.putObject(PutObjectRequest.builder()
                            .bucket(bucketName)
                            .key(jsonFile.getName())
                            .build(),
                    jsonFile.toPath());
            log.info("버켓 : [{}] 으로 업로드 됨 ", bucketName);
        }catch (Exception e){
            log.error("업로드 실패: {}", e.getMessage());
        }
    }

    public File downloadLatestJsonFile() throws IOException {
        Optional<File> jsonFile = findLatestJsonFile();
        if (jsonFile.isEmpty()) {
            throw new FileNotFoundException("No JSON file found in directory: " + jsonFileDirectory);
        }
        return jsonFile.get();
    }
    public Map<String, Object> parseJsonFile(File jsonFile) throws IOException {
        try (InputStream inputStream = new FileInputStream(jsonFile)) {
            return objectMapper.readValue(inputStream, new TypeReference<>() {
            });
        }
    }
}