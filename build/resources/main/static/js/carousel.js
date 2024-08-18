    function carousel() {
        return {
            currentIndex: 0,
            slides: [
                { id: 1, image: '/image/c1.png', link: '#', text: '1' },
                { id: 2, image: '/image/c2.png', link: '#', text: '2' },
                { id: 3, image: '/image/c3.png', link: '#', text: '3' }
            ],
            prev() {
                this.currentIndex = (this.currentIndex - 1 + this.slides.length) % this.slides.length;
            },
            next() {
                this.currentIndex = (this.currentIndex + 1) % this.slides.length;
            }
        }
    }