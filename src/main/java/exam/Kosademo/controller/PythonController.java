package exam.Kosademo.controller;

import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

import java.io.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Controller
public class PythonController {

    @GetMapping("/run-python")
    public ResponseEntity<InputStreamResource> runPythonScript() {
        try {
            // Python 스크립트 실행
            //ProcessBuilder processBuilder = new ProcessBuilder("python3", "/root/.ssh/kosapro/src/main/resources/static/make_result.py");
            ProcessBuilder processBuilder = new ProcessBuilder("python", "C:\\Users\\Leesumin\\3D Objects\\Downloads\\kosapro-han.featt\\kosapro-han.featt\\src\\main\\resources\\static\\make_result.py");
            processBuilder.redirectErrorStream(true);
            Process process = processBuilder.start();

            // Python 스크립트의 출력 읽기
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new RuntimeException("Python script execution failed with exit code " + exitCode + "\n" + output);
            }

            // 생성된 엑셀 파일 이름
            String excelFileName = "result_" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd")) + ".xlsx";
            File file = new File("C:/Users/Leesumin/3D Objects/Downloads/kosapro-han.featt/kosapro-han.featt/src/main/resources/static/" + excelFileName);
            //File file = new File("/root/.ssh/kosapro/src/main/resources/static/" + excelFileName);
            if (!file.exists()) {
                throw new FileNotFoundException("Generated Excel file not found: " + excelFileName);
            }

            InputStreamResource resource = new InputStreamResource(new FileInputStream(file));

            // 파일 다운로드 응답 반환
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + excelFileName)
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .body(resource);

        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
            return ResponseEntity.status(500).body(new InputStreamResource(new ByteArrayInputStream(e.getMessage().getBytes())));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(500).body(new InputStreamResource(new ByteArrayInputStream(e.getMessage().getBytes())));
        }
    }
}
