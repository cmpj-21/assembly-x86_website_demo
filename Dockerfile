# Build stage
FROM alpine:latest AS builder
RUN apk add --no-cache nasm binutils
COPY main_linux.asm /src/main_linux.asm
WORKDIR /src
RUN nasm -f elf64 main_linux.asm -o main_linux.o
RUN ld main_linux.o -o main_linux

# Final stage
FROM scratch
COPY --from=builder /src/main_linux /main_linux
EXPOSE 8083
CMD ["/main_linux"]
