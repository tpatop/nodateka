FROM lscr.io/linuxserver/chromium:latest

# Установка proxychains4
RUN apt-get update && \
    apt-get install -y proxychains4 && \
    rm -rf /var/lib/apt/lists/*

# Копирование настроек proxychains4
COPY proxychains.conf /etc/proxychains.conf

# Обертка для запуска Chromium через proxychains4
CMD ["proxychains4", "chromium-browser", "--no-sandbox"]
