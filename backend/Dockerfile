FROM alpine:3.22

# PocketBase henüz v1.0 değil → sürüm burada pinli; yükseltme bilinçli bir adımdır.
ARG PB_VERSION=0.40.4

# tzdata: "bugün" hesabı TZ ortam değişkeniyle yerel saate göre yapılır.
RUN apk add --no-cache ca-certificates tzdata unzip wget

# Mimari imajın içinden okunur (Mac: arm64, sunucu: amd64) — builder'a bağımlı değil.
RUN cd /tmp \
    && case "$(uname -m)" in aarch64) ARCH=arm64 ;; x86_64) ARCH=amd64 ;; *) echo "desteklenmeyen mimari" && exit 1 ;; esac \
    && ZIP="pocketbase_${PB_VERSION}_linux_${ARCH}.zip" \
    && BASE="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}" \
    && wget -q "${BASE}/${ZIP}" "${BASE}/checksums.txt" \
    && grep "${ZIP}" checksums.txt | sha256sum -c - \
    && mkdir -p /pb \
    && unzip -q "${ZIP}" pocketbase -d /pb \
    && rm -rf /tmp/*

COPY entrypoint.sh /pb/entrypoint.sh
RUN chmod +x /pb/entrypoint.sh

EXPOSE 8090
ENTRYPOINT ["/pb/entrypoint.sh"]
