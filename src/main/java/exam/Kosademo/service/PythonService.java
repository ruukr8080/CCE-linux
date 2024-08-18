package exam.Kosademo.service;

import org.springframework.stereotype.Service;

import java.io.*;
import java.util.Arrays;
import java.util.Comparator;

@Service
public class PythonService {

    public void executePythonScript(String scriptPath) throws IOException, InterruptedException {
        ProcessBuilder processBuilder = new ProcessBuilder("python", scriptPath);
        processBuilder.redirectErrorStream(true);
        Process process = processBuilder.start();

        BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
        String line;
        while ((line = reader.readLine()) != null) {
            System.out.println(line);
        }

        int exitCode = process.waitFor();
        if (exitCode != 0) {
            throw new RuntimeException("Python script execution failed with exit code " + exitCode);
        }
    }
    public File getLatestExcelFile(String dirPath) throws FileNotFoundException {
        File dir = new File(dirPath);
        if (!dir.exists() || !dir.isDirectory()) {
            throw new FileNotFoundException("Directory not found: " + dirPath);
        }

        File[] files = dir.listFiles((dir1, name) -> name.endsWith(".xlsx"));
        if (files == null || files.length == 0) {
            throw new FileNotFoundException("No Excel file found in directory: " + dirPath);
        }

        return Arrays.stream(files)
                .max(Comparator.comparingLong(File::lastModified))
                .orElseThrow(() -> new FileNotFoundException("No Excel file found in directory: " + dirPath));
    }
}