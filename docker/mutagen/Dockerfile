# Use a minimal base image.
FROM alpine:latest

COPY app /var/www

# Run a no-op entry point and wait to host Mutagen agent processes.
ENTRYPOINT ["tail", "-f", "/dev/null"]