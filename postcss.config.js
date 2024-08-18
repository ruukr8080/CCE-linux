// tailwind.config.js
module.exports = {
    content: [
        './src/main/resources/templates/**/*.{html,js}', // Thymeleaf 템플릿 경로
        './src/main/resources/static/**/*.{html,js}', // Static 파일 경로
        // 'C:/Kosa/out/resources/templates/**/*.{html,js}', // Thymeleaf 템플릿 경로
        "./node_modules/flowbite/**/*.js",
        "../resources/templates/**/*.{html,js}"
    ],
    theme: {
        colors:{
            gray:{
                50: '#e8e6e6',
                55: '#b35151'
            }

        },
        extend: {},
    },
    plugins: [
        require('tailwindcss'),
        require('autoprefixer'),
        require('flowbite/plugin')
    ],
}
