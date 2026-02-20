# x86 Assembly HTTP Server - Windows

A high-performance (and high-suffering) HTTP server written in raw x86 assembly using NASM and Winsock2. Featuring a sleek, cyber-punk CRT frontend.

## 🚀 Prerequisites

To build and run this project, you need:

1.  **NASM (Netwide Assembler)**: 
    *   Download the **Win64** version from [nasm.us](https://www.nasm.us/).
    *   Ensure `nasm` is in your system `PATH`.
2.  **Microsoft Linker (`link.exe`)**:
    *   Part of **Visual Studio Development Tools** (C++ workload).
    *   Must be run from a **Developer Command Prompt** or **Developer PowerShell** (e.g., VS 2022).

## 🛠️ Build & Run Instructions

Open your **Developer Command Prompt** and follow these steps:

1.  **Assemble the code**:
    ```cmd
    nasm -f win32 main.asm -o main.obj
    ```
    *This generates a 32-bit object file using the properly decorated Win32 stdcall symbols.*

2.  **Link the object file**:
    ```cmd
    link main.obj /subsystem:console /entry:start kernel32.lib ws2_32.lib /nodefaultlib
    ```
    *This links the required Windows system and network libraries.*

3.  **Run the server**:
    ```cmd
    .\main.exe
    ```
    *The server will start listening on `http://localhost:8083`.*

## 🌐 Usage

1.  Keep the `main.exe` terminal running.
2.  Open `index.html` in any web browser.
3.  Click the **EXECUTE** button to fetch data directly from the assembly-powered backend.

---

*Made with zero frameworks and maximum pain.* 🍜
