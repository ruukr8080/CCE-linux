document.addEventListener('DOMContentLoaded', function () {
    // 기존의 DOM 조작 코드
    const importanceElements = document.querySelectorAll('.importance');
    const statusElements = document.querySelectorAll('.status');
    const checkResults = /*[[${checkResults}]]*/ [];
    const categorySecurity = /*[[${categorySecurity}]]*/ {};


    createImportanceStatusChart(processImportanceStatusData(checkResults));
    createCategorySecurityChart(categorySecurity);


    function processImportanceStatusData(checkResults) {
        const chart = {};
        checkResults.forEach(result => {
            const {Importance, status} = result;
            if (!chart[Importance]) chart[Importance] = {};
            chart[Importance][status] = (chart[Importance][status] || 0) + 1;
        });
        return chart;
    }
    function createImportanceStatusChart(chartData) {
        const ctx = document.getElementById('importanceStatusChart').getContext('2d');
        const importanceLevels = Object.keys(chartData);
        const statusTypes = ['[양호]', '[취약]', '[N/A]'];

        const datasets = statusTypes.map(status => ({
            label: status,
            data: importanceLevels.map(importance => chartData[importance][status] || 0),
            backgroundColor: getColor(status)
        }));

        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: importanceLevels,
                datasets: datasets
            },
            options: {
                responsive: true,
                scales: {
                    x: {stacked: true},
                    y: {stacked: true, beginAtZero: true}
                }
            }
        });
    }

    function createCategorySecurityChart(categorySecurity) {
        const ctx = document.getElementById('categorySecurityChart').getContext('2d');
        const categories = Object.keys(categorySecurity);
        const scores = Object.values(categorySecurity);

        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: categories,
                datasets: [{
                    data: scores,
                    backgroundColor: categories.map((_, index) =>
                        `hsl(${index * 360 / categories.length}, 70%, 60%)`)
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {position: 'right'},
                    tooltip: {
                        callbacks: {
                            label: function (context) {
                                return `${context.label}: ${context.formattedValue}%`;
                            }
                        }
                    }
                }
            }
        });
    }
    function getColor(status) {
        switch (status) {
            case '[양호]':
                return '#4BC0C0';
            case '[취약]':
                return '#FF6384';
            case '[N/A]':
                return '#FFCE56';
            default:
                return '#36A2EB';
        }
    }

    function getScoreColor(score) {
        score = parseFloat(score);
        if (score >= 90) return '#4BC0C0';
        if (score >= 70) return '#36A2EB';
        if (score >= 50) return '#FFCE56';
        return '#FF6384';
    }

    importanceElements.forEach(element => {
        const importance = element.textContent;
        let textColor;
        let transformText;
        let textStyle = "text-bold";

        if (importance === '(상)') {
            textColor = 'text-red-500';
            transformText = "상";

        } else if (importance === '(중)') {
            textColor = 'text-yellow-500';
            transformText = "중";

        } else if (importance === '(하)') {
            textColor = 'text-gray-500';
            transformText = "하"
        }
        element.parentElement.classList.add(textStyle,transformText, textColor);
        element.textContent = transformText;
    });
    statusElements.forEach(element => {
        const status = element.textContent;
        let textColor = '';
        let transformText = '';

        if (status === '[취약]') {
            textColor = 'text-red-500';
            transformText = '취약';
        } else if (status === '[인터뷰]') {
            textColor = 'text-yellow-500';
            transformText = '양호';
        } else {
            textColor = 'text-green-500';
            transformText = '우수';
        }

        element.parentElement.classList.add(transformText,textColor);
        element.textContent = transformText;
    });

    // 차트 생성


});






