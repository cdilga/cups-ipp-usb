# CUPS + ipp-usb in one container.
#
# Base: anujdatar/cups (Debian 13, CUPS 2.4, avahi). It already ships the
# ipp-usb package but never starts it. We add a supervisor that runs ipp-usb
# alongside cupsd so the printer's IPP-over-USB interface (driverless printing,
# real status, and the printer's own web admin pages) is reachable over USB.
#
# Pinned to the multi-arch index digest; bump deliberately.
FROM anujdatar/cups@sha256:504765d80c838be6a22f806bf8949ef74a40cdfd9f9c00c4389e18710511fd10

LABEL org.opencontainers.image.source="https://github.com/cdilga/cups-ipp-usb" \
      org.opencontainers.image.description="CUPS with ipp-usb supervised in the same container (IPP-over-USB printing + printer web admin over USB)" \
      org.opencontainers.image.licenses="GPL-3.0-only"

COPY rootfs/ /

RUN chmod 0755 /usr/local/bin/start.sh /usr/local/bin/ipp-usb-supervisor \
 && ipp-usb check >/dev/null 2>&1 || true

# 631: CUPS. 60000: first ipp-usb device (IPP + printer web UI).
EXPOSE 631/tcp 60000/tcp

HEALTHCHECK --interval=60s --timeout=5s --start-period=20s \
  CMD lpstat -r >/dev/null 2>&1 || exit 1

CMD ["/usr/local/bin/start.sh"]
