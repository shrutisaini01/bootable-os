#include <stdint.h>
#include <string.h>

volatile uint16_t* const VGA_BUFFER = (uint16_t*)0xB8000;
const int VGA_COLS = 80;
const int VGA_ROWS = 25;

int term_col = 0;
int term_row = 0;
uint8_t term_color = 0x0F;

char cmd_buffer[256];
int cmd_pos = 0;

void clear_screen();
void print_char(char c);
void print_string(const char* str);
void process_command();
void new_line();

int strcmp(const char* s1, const char* s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

int strncmp(const char* s1, const char* s2, size_t n) {
    while (n && *s1 && (*s1 == *s2)) {
        s1++;
        s2++;
        n--;
    }
    if (n == 0) return 0;
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    asm volatile("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

static inline void outb(uint16_t port, uint8_t val) {
    asm volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

extern "C" void kernel_main() {
    clear_screen();
    print_string("MinimalOS v0.1\n");
    print_string("Available commands: clear, help, echo, reboot, halt\n");
    print_string("> ");

    while(true) {
        asm volatile(
            "int $0x16"
            : "=a"(*(uint16_t*)0)
        );
        char c = *(char*)0;

        if (c == '\r') {
            new_line();
            process_command();
            cmd_pos = 0;
            print_string("> ");
        } else if (c == '\b') {
            if (cmd_pos > 0) {
                cmd_pos--;
                term_col--;
                print_char(' ');
                term_col--;
            }
        } else if (cmd_pos < 255) {
            cmd_buffer[cmd_pos++] = c;
            print_char(c);
        }
    }
}

void clear_screen() {
    for(int i = 0; i < VGA_COLS * VGA_ROWS; i++) {
        VGA_BUFFER[i] = (uint16_t)(' ' | (term_color << 8));
    }
    term_col = 0;
    term_row = 0;
}

void print_char(char c) {
    if (c == '\n') {
        new_line();
        return;
    }

    if (term_col >= VGA_COLS) {
        new_line();
    }

    const size_t index = (VGA_COLS * term_row) + term_col;
    VGA_BUFFER[index] = ((uint16_t)term_color << 8) | c;
    term_col++;
}

void print_string(const char* str) {
    for (size_t i = 0; str[i] != '\0'; i++) {
        print_char(str[i]);
    }
}

void new_line() {
    term_col = 0;
    if (++term_row >= VGA_ROWS) {
        term_row = 0;
    }
}

void process_command() {
    cmd_buffer[cmd_pos] = '\0';
    
    if (strcmp(cmd_buffer, "clear") == 0) {
        clear_screen();
    }
    else if (strcmp(cmd_buffer, "help") == 0) {
        print_string("Available commands:\n");
        print_string("  clear  - Clear the screen\n");
        print_string("  help   - Show this help message\n");
        print_string("  echo   - Echo the following text\n");
        print_string("  reboot - Restart the system\n");
        print_string("  halt   - Stop the system\n");
    }
    else if (strncmp(cmd_buffer, "echo ", 5) == 0) {
        print_string(cmd_buffer + 5);
        print_char('\n');
    }
    else if (strcmp(cmd_buffer, "reboot") == 0) {
        uint8_t good = 0x02;
        while (good & 0x02)
            good = inb(0x64);
        outb(0x64, 0xFE);
        asm volatile("hlt");
    }
    else if (strcmp(cmd_buffer, "halt") == 0) {
        print_string("System halted.\n");
        asm volatile("hlt");
    }
    else if (cmd_pos > 0) {
        print_string("Unknown command. Type 'help' for available commands.\n");
    }
}
