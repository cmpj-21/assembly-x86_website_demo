; ============================================================
; x86 Assembly HTTP Server - Windows (NASM + Winsock2)
; "Hello World! From Assembly x86!"
;
; Assemble: nasm -f win32 main.asm -o main.obj
; Link:     link main.obj /subsystem:console /entry:start ^
;               kernel32.lib ws2_32.lib /nodefaultlib
; Run:      main.exe
;
; Requirements:
;   - NASM (https://www.nasm.us/)
;   - Microsoft Linker (comes with Visual Studio / Build Tools)
;   - ws2_32.lib and kernel32.lib (come with Windows SDK)
; ============================================================

bits 32

; ============================================================
; IMPORTS - Windows API functions we need
; ============================================================
; --- Win32 stdcall name decoration ---
; In 32-bit assembly, the linker expects _FuncName@N decoration for stdcall.
extern _WSAStartup@8
extern _WSACleanup@0
extern _socket@12
extern _bind@12
extern _listen@8
extern _accept@12
extern _recv@16
extern _send@16
extern _closesocket@4
extern _GetStdHandle@4
extern _WriteConsoleA@20
extern _ExitProcess@4

; Aliases for readability
%define WSAStartup    _WSAStartup@8
%define WSACleanup    _WSACleanup@0
%define socket        _socket@12
%define bind          _bind@12
%define listen        _listen@8
%define accept        _accept@12
%define recv          _recv@16
%define send          _send@16
%define closesocket   _closesocket@4
%define GetStdHandle  _GetStdHandle@4
%define WriteConsoleA _WriteConsoleA@20
%define ExitProcess   _ExitProcess@4

; ============================================================
; DATA SECTION - all strings and variables
; ============================================================
section .data

    ; --- Winsock startup ---
    wsaData         times 400 db 0      ; WSADATA struct (we just need it big enough)

    ; --- Socket address struct (sockaddr_in) ---
    ; sin_family: AF_INET = 2
    ; sin_port:   8083 in big-endian = 0x871F... wait, let's compute:
    ;             8083 decimal = 0x1F93, big-endian bytes: 0x1F, 0x93
    ; sin_addr:   INADDR_ANY = 0.0.0.0
    serverAddr:
        dw 2                ; sin_family = AF_INET
        db 0x1F, 0x93       ; sin_port = 8083 in network byte order (big-endian)
        dd 0                ; sin_addr = INADDR_ANY (0.0.0.0)
        times 8 db 0        ; padding (sin_zero)

    serverAddrLen   dd 16   ; sizeof(sockaddr_in)

    ; --- HTTP response ---
    httpResponse    db "HTTP/1.1 200 OK", 0x0D, 0x0A
                    db "Content-Type: application/json", 0x0D, 0x0A
                    db "Access-Control-Allow-Origin: *", 0x0D, 0x0A
                    db "Connection: close", 0x0D, 0x0A
                    db 0x0D, 0x0A
                    db '{"message": "Hello World! From Assembly x86!"}'
                    db 0x0D, 0x0A
    httpResponseLen equ $ - httpResponse

    ; --- HTTP 404 response (for unknown routes) ---
    http404         db "HTTP/1.1 404 Not Found", 0x0D, 0x0A
                    db "Content-Type: application/json", 0x0D, 0x0A
                    db "Access-Control-Allow-Origin: *", 0x0D, 0x0A
                    db "Connection: close", 0x0D, 0x0A
                    db 0x0D, 0x0A
                    db '{"error": "not found"}'
                    db 0x0D, 0x0A
    http404Len      equ $ - http404

    ; --- Console messages ---
    msgStarting     db "Assembly x86 server starting on http://localhost:8083", 0x0D, 0x0A
    msgStartingLen  equ $ - msgStarting

    msgWaiting      db "Waiting for connection...", 0x0D, 0x0A
    msgWaitingLen   equ $ - msgWaiting

    msgGotConn      db "Connection received! Sending response...", 0x0D, 0x0A
    msgGotConnLen   equ $ - msgGotConn

    msgDone         db "Response sent. Closing client socket.", 0x0D, 0x0A
    msgDoneLen      equ $ - msgDone

    msgError        db "ERROR occurred. Exiting.", 0x0D, 0x0A
    msgErrorLen     equ $ - msgError

    ; String to search for GET /hello in request
    helloRoute      db "GET /hello"
    helloRouteLen   equ $ - helloRoute

; ============================================================
; BSS SECTION - uninitialized variables
; ============================================================
section .bss

    serverSocket    resd 1          ; server socket handle
    clientSocket    resd 1          ; client socket handle
    stdoutHandle    resd 1          ; console output handle
    bytesWritten    resd 1          ; for WriteConsoleA
    recvBuffer      resb 4096       ; buffer to hold incoming HTTP request
    bytesReceived   resd 1          ; number of bytes received

; ============================================================
; CODE SECTION
; ============================================================
section .text

global start

; ------------------------------------------------------------
; MACRO: print a message to console
; Usage: PRINT label, length
; ------------------------------------------------------------
%macro PRINT 2
    push    0
    push    bytesWritten
    push    %2
    push    %1
    push    dword [stdoutHandle]
    call    WriteConsoleA
%endmacro

; ------------------------------------------------------------
; ENTRY POINT
; ------------------------------------------------------------
start:

    ; --- Get console handle for output ---
    push    -11                         ; STD_OUTPUT_HANDLE = -11
    call    GetStdHandle
    mov     [stdoutHandle], eax

    ; --- Initialize Winsock ---
    push    wsaData
    push    0x0202                      ; version 2.2 (MAKEWORD(2,2))
    call    WSAStartup
    test    eax, eax
    jnz     .error                      ; if eax != 0, WSAStartup failed

    ; --- Create TCP socket ---
    ; socket(AF_INET=2, SOCK_STREAM=1, IPPROTO_TCP=6)
    push    6                           ; protocol = TCP
    push    1                           ; type = SOCK_STREAM
    push    2                           ; family = AF_INET
    call    socket
    cmp     eax, -1                     ; INVALID_SOCKET = -1
    je      .error
    mov     [serverSocket], eax

    ; --- Bind socket to address and port ---
    push    dword [serverAddrLen]
    push    serverAddr
    push    dword [serverSocket]
    call    bind
    test    eax, eax
    jnz     .error

    ; --- Listen for incoming connections ---
    push    5                           ; backlog = 5
    push    dword [serverSocket]
    call    listen
    test    eax, eax
    jnz     .error

    ; --- Print startup message ---
    PRINT   msgStarting, msgStartingLen

; ------------------------------------------------------------
; MAIN ACCEPT LOOP - keep accepting connections forever
; ------------------------------------------------------------
.acceptLoop:

    PRINT   msgWaiting, msgWaitingLen

    ; --- Accept a client connection ---
    push    0                           ; addrlen ptr = NULL (we don't need client addr)
    push    0                           ; addr ptr = NULL
    push    dword [serverSocket]
    call    accept
    cmp     eax, -1
    je      .error
    mov     [clientSocket], eax

    PRINT   msgGotConn, msgGotConnLen

    ; --- Receive the HTTP request ---
    push    0                           ; flags = 0
    push    4096                        ; buffer size
    push    recvBuffer                  ; buffer
    push    dword [clientSocket]
    call    recv
    mov     [bytesReceived], eax

    ; --- Check if request contains "GET /hello" ---
    ; We do a simple search: scan recvBuffer for the bytes in helloRoute
    mov     esi, recvBuffer             ; esi = pointer into receive buffer
    mov     ecx, [bytesReceived]        ; ecx = number of bytes received

.searchLoop:
    ; Compare byte at [esi] with first byte of "GET /hello"
    mov     al, [esi]
    cmp     al, byte [helloRoute]
    jne     .nextByte

    ; First byte matched — now compare the rest
    push    esi
    push    ecx
    mov     edi, helloRoute
    mov     ecx, helloRouteLen
    repe    cmpsb                       ; compare ecx bytes: [esi...] vs [edi...]
    pop     ecx
    pop     esi
    je      .sendHello                  ; all bytes matched — send hello response

.nextByte:
    inc     esi
    dec     ecx
    jnz     .searchLoop
    jmp     .send404                    ; no match found — send 404

.sendHello:
    ; --- Send HTTP 200 response with our message ---
    push    0                           ; flags = 0
    push    httpResponseLen
    push    httpResponse
    push    dword [clientSocket]
    call    send

    jmp     .closeClient

.send404:
    ; --- Send HTTP 404 response ---
    push    0
    push    http404Len
    push    http404
    push    dword [clientSocket]
    call    send

.closeClient:
    PRINT   msgDone, msgDoneLen

    ; --- Close the client socket ---
    push    dword [clientSocket]
    call    closesocket

    ; --- Loop back to accept next connection ---
    jmp     .acceptLoop

; ------------------------------------------------------------
; ERROR HANDLER
; ------------------------------------------------------------
.error:
    PRINT   msgError, msgErrorLen

    ; Cleanup Winsock
    call    WSACleanup

    ; Exit with code 1
    push    1
    call    ExitProcess