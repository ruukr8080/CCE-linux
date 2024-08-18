package exam.Kosademo.controller;

import com.jcraft.jsch.*;
;
import exam.Kosademo.service.S3Service;
import exam.Kosademo.service.TestService;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import org.springframework.web.servlet.view.RedirectView;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Slf4j
@Controller
@RequiredArgsConstructor
public class S3Controller {

    private final S3Service s3;
    private final S3Client s3Client;

    @Value("${aws.s3.bucket.name}")
    private String bucketName;
    @Value("${centos.script.path}")
    private String centosScriptPath;
    @Value("${result.json.path}")
    private String resultJsonPath;
    @Value("${ssh.script.path}")
    private String scriptPath;
    @Value("${ssh.json.path}")
    private String jsonPath;
    @PostMapping("/run")
    public RedirectView start(@RequestParam("username") String username,
                              @RequestParam("password") String password,
                              @RequestParam("ipAddress") String ipAddress,
                              @RequestParam("port") int port,
                              RedirectAttributes redirectAttributes) {
        try {
            s3.runCheck(username, password, ipAddress, port, scriptPath, jsonPath);
            if (s3.findLatestJsonFile().isEmpty()) {
                log.info("json파일 없음 {}");
                return new RedirectView();
            }
            File file = s3.findLatestJsonFile().get();
            log.info("json파일 찾음 절대 경로 : {}", file.getAbsolutePath());
            log.info("json파일 찾음 상대 경로 : {}", file.getCanonicalPath());
            s3Client.putObject(PutObjectRequest.builder()
                            .bucket(bucketName)
                            .key(file.getName())
                            .build(),
                    file.toPath());
            log.info("버켓에 업로드" + bucketName);
            redirectAttributes.addFlashAttribute("successMessage", "에이전트 작업 성공");
            return new RedirectView("/result");
        } catch (JSchException | SftpException | IOException e) {
            log.error("에이전트 실행 또는 S3 업로드 중 에러 발생", e);
            redirectAttributes.addFlashAttribute("errorMessage", "에러: " + e.getMessage());
            return new RedirectView();
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
    }
}



