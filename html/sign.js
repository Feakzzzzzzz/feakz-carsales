(function () {
    const params = new URLSearchParams(window.location.search);
    const isDui = params.get('dui') === '1';

    if (!isDui) return;

    document.body.classList.add('dui');

    const fitText = (el) => {
        if (!el) return;

        el.style.fontSize = '';
        const baseSize = Number.parseFloat(window.getComputedStyle(el).fontSize);
        let size = baseSize;

        el.style.fontSize = `${size}px`;
        while (el.scrollWidth > el.clientWidth && size > 18) {
            size -= 2;
            el.style.fontSize = `${size}px`;
        }
    };

    const setText = (id, value) => {
        const el = document.getElementById(id);
        if (!el) return;
        el.textContent = value || 'Unknown';
        fitText(el);
    };

    const setSignData = (data) => {
        const name = data.name || 'Unknown';
        const phone = data.phone || 'Unknown';

        setText('price', data.price || '$0');
        setText('contact-line', `${name} - ${phone}`);
    };

    window.addEventListener('message', (event) => {
        let data = event.data;
        if (typeof data === 'string') {
            try {
                data = JSON.parse(data);
            } catch {
                return;
            }
        }

        if (!data || data.type !== 'update') return;
        setSignData(data);
    });

    setSignData({
        price: params.get('price') || '$0',
        name: params.get('name') || 'Unknown',
        phone: params.get('phone') || 'Unknown'
    });

    window.addEventListener('resize', () => {
        fitText(document.getElementById('price'));
        fitText(document.getElementById('contact-line'));
    });
})();
