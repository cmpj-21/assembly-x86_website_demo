; ============================================================
; x86_64 Assembly HTTP Server - Linux (NASM)
; "Hello World! From Assembly x86!"
;
; Assemble: nasm -f elf64 main_linux.asm -o main_linux.o
; Link:     ld main_linux.o -o main_linux
; Run:      ./main_linux
; ============================================================

section .data
    ; --- Socket setup ---
    ; sockaddr_in struct (16 bytes)
    ; sin_family (AF_INET = 2) - 2 bytes
    ; sin_port (8083 in big-endian, 0x1F93 -> 0x931F) - 2 bytes
    ; sin_addr (INADDR_ANY = 0) - 4 bytes
    ; sin_zero - 8 bytes padding
    serverAddr:
        dw 2                ; AF_INET
        db 0x1F, 0x93       ; port 8083 (big-endian 0x1F93)
        dd 0                ; INADDR_ANY
        dq 0                ; padding

    serverAddrLen equ 16

    ; --- HTTP responses ---
    httpResponse    db "HTTP/1.1 200 OK", 0x0D, 0x0A
                    db "Content-Type: application/json", 0x0D, 0x0A
                    db "Access-Control-Allow-Origin: *", 0x0D, 0x0A
                    db "Connection: close", 0x0D, 0x0A
                    db 0x0D, 0x0A
                    db '{"message": "Hello World! From Assembly x86!"}', 0x0D, 0x0A
    httpResponseLen equ $ - httpResponse

    http404         db "HTTP/1.1 404 Not Found", 0x0D, 0x0A
                    db "Content-Type: application/json", 0x0D, 0x0A
                    db "Access-Control-Allow-Origin: *", 0x0D, 0x0A
                    db "Connection: close", 0x0D, 0x0A
                    db 0x0D, 0x0A
                    db '{"error": "not found"}', 0x0D, 0x0A
    http404Len      equ $ - http404

    ; --- Console messages ---
    msgStarting     db "Assembly x86 Linux server starting on http://localhost:8083", 0x0A
    msgStartingLen  equ $ - msgStarting

    msgWaiting      db "Waiting for connection...", 0x0A
    msgWaitingLen   equ $ - msgWaiting

    msgGotConn      db "Connection received! Sending response...", 0x0A
    msgGotConnLen   equ $ - msgGotConn

    msgDone         db "Response sent. Closing client socket.", 0x0A
    msgDoneLen      equ $ - msgDone

    msgError        db "ERROR occurred. Exiting.", 0x0A
    msgErrorLen     equ $ - msgError

    ; Route search
    helloRoute      db "GET /hello"
    helloRouteLen   equ $ - helloRoute

section .bss
    serverSocket    resq 1          ; socket file descriptor
    clientSocket    resq 1
    recvBuffer      resb 4096

section .text
    global _start

_start:
    ; --- Print startup message ---
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, msgStarting
    mov rdx, msgStartingLen
    syscall

    ; --- Create socket ---
    ; socket(AF_INET=2, SOCK_STREAM=1, IPPROTO_TCP=6)
    mov rax, 41             ; sys_socket
    mov rdi, 2              ; AF_INET
    mov rsi, 1              ; SOCK_STREAM
    mov rdx, 6              ; IPPROTO_TCP
    syscall
    test rax, rax
    js .error
    mov [serverSocket], rax

    ; --- Bind socket ---
    mov rax, 49             ; sys_bind
    mov rdi, [serverSocket]
    mov rsi, serverAddr
    mov rdx, serverAddrLen
    syscall
    test rax, rax
    jnz .error

    ; --- Listen ---
    mov rax, 50             ; sys_listen
    mov rdi, [serverSocket]
    mov rsi, 5              ; backlog
    syscall
    test rax, rax
    jnz .error

.acceptLoop:
    ; Print waiting message
    mov rax, 1
    mov rdi, 1
    mov rsi, msgWaiting
    mov rdx, msgWaitingLen
    syscall

    ; --- Accept ---
    mov rax, 43             ; sys_accept
    mov rdi, [serverSocket]
    xor rsi, rsi            ; NULL
    xor rdx, rdx            ; NULL
    syscall
    test rax, rax
    js .error
    mov [clientSocket], rax

    ; Print got connection
    mov rax, 1
    mov rdi, 1
    mov rsi, msgGotConn
    mov rdx, msgGotConnLen
    syscall

    ; --- Receive request ---
    mov rax, 0              ; sys_read (socket is a file descriptor)
    mov rdi, [clientSocket]
    mov rsi, recvBuffer
    mov rdx, 4096
    syscall
    mov r12, rax            ; save bytes received

    ; --- Simple route checking (search for "GET /hello") ---
    mov rsi, recvBuffer
    mov rcx, r12
.searchLoop:
    cmp rcx, helloRouteLen
    jb .send404
    
    mov rdi, helloRoute
    push rcx
    push rsi
    mov rcx, helloRouteLen
    repe cmpsb
    pop rsi
    pop rcx
    je .sendHello

    inc rsi
    dec rcx
    jnz .searchLoop
    jmp .send404

.sendHello:
    mov rax, 1              ; sys_write
    mov rdi, [clientSocket]
    mov rsi, httpResponse
    mov rdx, httpResponseLen
    syscall
    jmp .closeClient

.send404:
    mov rax, 1
    mov rdi, [clientSocket]
    mov rsi, http404
    mov rdx, http404Len
    syscall

.closeClient:
    ; Print closing message
    mov rax, 1
    mov rdi, 1
    mov rsi, msgDone
    mov rdx, msgDoneLen
    syscall

    ; Close client socket
    mov rax, 3              ; sys_close
    mov rdi, [clientSocket]
    syscall

    jmp .acceptLoop

.error:
    mov rax, 1
    mov rdi, 1
    mov rsi, msgError
    mov rdx, msgErrorLen
    syscall

    mov rax, 60             ; sys_exit
    mov rdi, 1
    syscall
