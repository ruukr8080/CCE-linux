    // Thymeleaf 변수를 JavaScript 변수로 변환
    const categorySecurityIndices = /*[[${categorySecurityIndicesJson}]]*/ '[]';
    const parsedData = JSON.parse(categorySecurityIndices);

    // 차트에 사용할 레이블과 데이터 값을 추출
    const labels = Object.keys(parsedData);
    const dataValues = Object.values(parsedData);

    // 캔버스 요소를 가져와서 차트를 생성
    const ctx = document.getElementById('securityChart').getContext('2d');
    const data = {
    labels: labels,
    datasets: [{
    label: '보안지수',
    data: dataValues,
    backgroundColor: 'rgba(54, 162, 235, 0.2)', // 차트의 배경색을 설정
    borderColor: 'rgba(54, 162, 235, 1)', // 차트의 테두리 색을 설정
    borderWidth: 1 // 차트의 테두리 두께를 설정
}]
};
    const config = {
    type: 'bar', // 차트 유형을 막대 차트로 설정
    data: data,
    options: {
    scales: {
    y: {
    beginAtZero: true // y축을 0부터 시작하도록 설정
}
}
}
};
    new Chart(ctx, config); // 차트를 생성
