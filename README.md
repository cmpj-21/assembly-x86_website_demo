# x86 Assembly HTTP Server Demo - Windows & Linux

A high-performance (and high-suffering) HTTP server demo written in raw x86 assembly. Featuring a sleek, cyber-punk CRT frontend.

---

## 🏎️ Zero-Setup Experience (Recommended)

If you have **Docker** installed, you can skip the manual assembly "suffering" and jump straight into the machine. No NASM or Linker needed.

1.  **Clone the Repo**:
    ```bash
    git clone https://github.com/your-username/assembly-x86-website-demo.git
    cd assembly-x86-website-demo
    ```
2.  **Fire it up**:
    ```bash
    docker-compose up --build
    ```
3.  **Access the Experience**:
    *   **Frontend**: `http://localhost:8080`
    *   **Backend API**: `http://localhost:8083/hello`

---

## 🚀 Manual Build (Windows Only)

If you prefer to build it from source on Windows, you will need to install the prerequisites manually.

### Prerequisites

1.  **NASM (Netwide Assembler)**: 
    *   Download the **Win64** version from [nasm.us](https://www.nasm.us/).
    *   Ensure `nasm` is in your system `PATH`.
2.  **Microsoft Linker (`link.exe`)**:
    *   Part of **Visual Studio Development Tools** (C++ workload).
    *   Must be run from a **Developer Command Prompt** for VS.

### Build & Run Instructions

From your **Developer Command Prompt**:

1.  **Assemble**:
    ```cmd
    nasm -f win32 main.asm -o main.obj
    ```
2.  **Link**:
    ```cmd
    link main.obj /subsystem:console /entry:start kernel32.lib ws2_32.lib /nodefaultlib
    ```
3.  **Run**:
    ```cmd
    .\main.exe
    ```

---

*Made with zero frameworks and maximum pain.* 🍜
