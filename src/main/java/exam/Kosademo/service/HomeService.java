package exam.Kosademo.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.IOException;
import java.util.*;

@Service
@RequiredArgsConstructor
public class HomeService {

    private final S3Service s3Service;
    public Map<String, Object> getCheckResultData() throws IOException {
        File jsonFile = s3Service.downloadLatestJsonFile();
        Map<String, Object> jsonMap = s3Service.parseJsonFile(jsonFile);
        Map<String, Object> serverInfoMap = (Map<String, Object>) jsonMap.get("Server_Info");
        List<Map<String, Object>> checkResults = (List<Map<String, Object>>) jsonMap.get("Check_Results");

        Map<String, Map<String, Integer>> categorizedResults = getCategorizedResults(checkResults);
        Map<String, Double> categorySecurity = getCategorySecurity(categorizedResults);
        double allSecurity = getAllSecurity(categorizedResults);
        Map<String, Object> section1 = getSection1(serverInfoMap, allSecurity);
        Map<String, Object> section2 = getSection2(serverInfoMap);
        List<Map<String, Object>> section3 = getSection3(serverInfoMap, checkResults);
        String report = "업로드 공간";

        Map<String, Object> resultData = new HashMap<>();
        resultData.put("section1", section1);
        resultData.put("section2", section2);
        resultData.put("section3", section3);
        resultData.put("checkResults", checkResults);
        resultData.put("categorizedResults", categorizedResults);
        resultData.put("categorySecurity", categorySecurity);
        resultData.put("allSecurity", allSecurity);
        resultData.put("report", report);
        return resultData;
    }
    private Map<String, Map<String, Integer>> getCategorizedResults(List<Map<String, Object>> checkResults) {
        Map<String, Map<String, Integer>> categorizedResults = new TreeMap<>();
        for (Map<String, Object> item : checkResults) {
            String category = (String) item.get("Category");
            String status = (String) item.get("status");
            categorizedResults.computeIfAbsent(category, k -> new HashMap<>()).merge(status, 1, Integer::sum);
        }
        return categorizedResults;
    }
    private Map<String, Double> getCategorySecurity(Map<String, Map<String, Integer>> categorizedResults) {
        Map<String, Double> categorySecurity = new TreeMap<>();
        for (Map.Entry<String, Map<String, Integer>> entry : categorizedResults.entrySet()) {
            String category = entry.getKey();
            Map<String, Integer> stats = entry.getValue();
            int safe = stats.getOrDefault("[양호]", 0);
            int vulnerable = stats.getOrDefault("[취약]", 0);
            int na = stats.getOrDefault("[N/A]", 0);
            int total = safe + vulnerable + na;
            double securityIndex = total == 0 ? 0.0 : (double) safe / total * 100;
            categorySecurity.put(category, Double.parseDouble(String.format("%.2f", securityIndex)));
        }
        return categorySecurity;
    }
    private double getAllSecurity(Map<String, Map<String, Integer>> categorizedResults) {
        int totalSafe = 0, totalVulnerable = 0, totalNA = 0;
        for (Map<String, Integer> stats : categorizedResults.values()) {
            totalSafe += stats.getOrDefault("[양호]", 0);
            totalVulnerable += stats.getOrDefault("[취약]", 0);
            totalNA += stats.getOrDefault("[N/A]", 0);
        }
        int overallTotal = totalSafe + totalVulnerable + totalNA;
        return overallTotal == 0 ? 0.0 : Double.parseDouble(String.format("%.2f", (double) totalSafe / overallTotal * 100));
    }
    private Map<String, Object> getChart(List<Map<String, Object>> checkResults) {
        Map<String, Object> chartData = new HashMap<>();
        Map<String, Map<String, Integer>> importanceStatusChart = new HashMap<>();
        for (Map<String, Object> result : checkResults) {
            String importance = (String) result.get("Importance");
            String status = (String) result.get("status");
            importanceStatusChart.computeIfAbsent(importance, k -> new HashMap<>())
                    .merge(status, 1, Integer::sum);
        }
        chartData.put("chart", importanceStatusChart);
        Map<String, Map<String, Integer>> categorizedResults = getCategorizedResults(checkResults);
        Map<String, Double> categorySecurity = getCategorySecurity(categorizedResults);
        chartData.put("categorySecurity", categorySecurity);
        double allSecurity = getAllSecurity(categorizedResults);
        chartData.put("allSecurity", allSecurity);
        return chartData;
    }
    private Map<String, Object> getSection1(Map<String, Object> serverInfoMap, double allSecurity) {
        Map<String, Object> section1 = new HashMap<>();
        section1.put("DATE", serverInfoMap.get("DATE"));
        section1.put("SW_INFO", serverInfoMap.get("SW_INFO"));
        section1.put("allSecurity", allSecurity);
        return section1;
    }
    private Map<String, Object> getSection2(Map<String, Object> serverInfoMap) {
        Map<String, Object> section2 = new HashMap<>();
        section2.put("Category", serverInfoMap.get("Category"));
        section2.put("Importance", serverInfoMap.get("Importance"));
        section2.put("status", serverInfoMap.get("status"));
        section2.put("Sub_Category", serverInfoMap.get("Sub_Category"));
        return section2;
    }
    private List<Map<String, Object>> getSection3(Map<String, Object> serverInfoMap, List<Map<String, Object>> checkResults) {
        List<Map<String, Object>> section3 = new ArrayList<>();
        for (Map<String, Object> result : checkResults) {
            Map<String, Object> data = new HashMap<>();
            data.put("OS", serverInfoMap.get("SW_NM"));
            data.put("Host", serverInfoMap.get("HOST_NM"));
            data.put("IP", serverInfoMap.get("IP_ADDRESS"));
            data.put("Category", result.get("Category"));
            data.put("Importance", result.get("Importance"));
            data.put("Status", result.get("status"));
            data.put("Sub_Category", result.get("Sub_Category"));
            section3.add(data);
        }
        return section3;
    }
}