.section .vectors, "ax"
B _start            // reset vector
B SERVICE_UND       // undefined instruction vector
B SERVICE_SVC       // software interrupt vector
B SERVICE_ABT_INST  // aborted prefetch vector
B SERVICE_ABT_DATA  // aborted data vector
.word 0             // unused vector
B SERVICE_IRQ       // IRQ interrupt vector
B SERVICE_FIQ       // FIQ interrupt vector

segments: 
.byte 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F
.byte 0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71

.equ HEX0, 0xFF200020
.equ PB_ADDR, 0xFF200050
.equ PB_ADDR_EC, 0xFF20005C // edge capture
.equ PB_ADDR_INT, 0xFF200058 // interrupt mask
.equ TIMER_ADDR, 0xFFFEC600
.equ TIMER_CTRL_ADDR, 0xFFFEC608
.equ TIMER_INT_ADDR, 0xFFFEC60C
.equ SLIDER_SWITCHES, 0xFF200040

.text
.global _start

_start:
    /* Set up stack pointers for IRQ and SVC processor modes */
    MOV R1, #0b11010010      // interrupts masked, MODE = IRQ
    MSR CPSR_c, R1           // change to IRQ mode
    LDR SP, =0xFFFFFFFF - 3  // set IRQ stack to A9 on-chip memory
    /* Change to SVC (supervisor) mode with interrupts disabled */
    MOV R1, #0b11010011      // interrupts masked, MODE = SVC
    MSR CPSR, R1             // change to supervisor mode
    LDR SP, =0x3FFFFFFF - 3  // set SVC stack to top of DDR3 memory
    BL CONFIG_GIC            // configure the ARM GIC

    // Enable interrupts for pushbuttons and timer
    LDR R0, =PB_ADDR_INT
    MOV R1, #0xF             // enable interrupts for all pushbuttons
    STR R1, [R0]             // write to interrupt mask register

    LDR R0, =TIMER_CTRL_ADDR
    MOV R1, #0x7             // enable timer, auto-reload, and interrupts
    STR R1, [R0]

    // Initialize message and display
    LDR R4, =message         // load address of the message
    LDR R5, =0xFF200020      // load HEX display base address
    BL DISPLAY_MESSAGE       // display initial message

    // Enable IRQ interrupts in the processor
    MOV R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0

IDLE:
    B IDLE // Main program loop (wait for interrupts)

// Display the current message on the HEX display
DISPLAY_MESSAGE:
    PUSH {R0-R3, LR}
    MOV R0, #0               // HEX display index
    MOV R1, R4               // message pointer
DISPLAY_LOOP:
    LDRB R2, [R1], #1        // load next character from message
    CMP R2, #0               // check for end of message
    BEQ DISPLAY_DONE
    LDR R3, =segments        // load segment table address
    LDRB R3, [R3, R2]        // get segment pattern for character
    STRB R3, [R5, R0]        // write to HEX display
    ADD R0, R0, #1           // move to next HEX display
    B DISPLAY_LOOP
DISPLAY_DONE:
    POP {R0-R3, PC}

// Rotate the message right to left
ROTATE_MESSAGE:
    PUSH {R0-R2, LR}
    LDRB R0, [R4]            // save first character
    MOV R1, R4               // message pointer
    MOV R2, #5               // number of characters to shift
ROTATE_LOOP:
    LDRB R3, [R1, #1]        // load next character
    STRB R3, [R1], #1        // store and increment pointer
    SUBS R2, R2, #1          // decrement counter
    BNE ROTATE_LOOP
    STRB R0, [R4, #5]        // move first character to end
    POP {R0-R2, PC}

// Pushbutton ISR
KEY_ISR:
    PUSH {R0-R2, LR}
    LDR R0, =PB_ADDR_EC      // load edge capture register address
    LDR R1, [R0]             // read edge capture register
    STR R1, [R0]             // clear edge capture register

    // Modify rotation speed or direction based on pushbutton
    TST R1, #0x1             // check KEY0
    BLNE MODIFY_SPEED
    TST R1, #0x2             // check KEY1
    BLNE MODIFY_DIRECTION
    POP {R0-R2, PC}

// Modify rotation speed
MODIFY_SPEED:
    PUSH {R0-R1, LR}
    LDR R0, =TIMER_ADDR
    LDR R1, [R0]             // read current timer count value
    LSR R1, R1, #1           // halve the count value (double speed)
    STR R1, [R0]             // write new count value
    POP {R0-R1, PC}

// Modify rotation direction
MODIFY_DIRECTION:
    PUSH {R0-R1, LR}
    LDR R0, =direction       // load direction flag address
    LDR R1, [R0]
    EOR R1, R1, #1           // toggle direction flag
    STR R1, [R0]
    POP {R0-R1, PC}

// Timer ISR
TIMER_ISR:
    PUSH {R0-R1, LR}
    LDR R0, =TIMER_INT_ADDR
    MOV R1, #0x1
    STR R1, [R0]             // clear timer interrupt

    BL ROTATE_MESSAGE        // rotate the message
    BL DISPLAY_MESSAGE       // update the HEX display
    POP {R0-R1, PC}

// GIC configuration (unchanged from your original code)
CONFIG_GIC:
    PUSH {LR}
    MOV R0, #73              // KEY port (Interrupt ID = 73)
    MOV R1, #1               // target CPU0
    BL CONFIG_INTERRUPT
    LDR R0, =0xFFFEC100      // base address of CPU Interface
    LDR R1, =0xFFFF          // enable interrupts of all priorities
    STR R1, [R0, #0x04]
    MOV R1, #1
    STR R1, [R0]             // enable CPU Interface
    LDR R0, =0xFFFED000
    STR R1, [R0]             // enable Distributor
    POP {PC}

CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
    LSR R4, R0, #3           // calculate reg_offset
    BIC R4, R4, #3           // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4           // R4 = address of ICDISER
    AND R2, R0, #0x1F        // N mod 32
    MOV R5, #1               // enable
    LSL R2, R5, R2           // R2 = value
    LDR R3, [R4]             // read current register value
    ORR R3, R3, R2           // set the enable bit
    STR R3, [R4]             // store the new register value
    BIC R4, R0, #3           // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4           // R4 = word address of ICDIPTR
    AND R2, R0, #0x3         // N mod 4
    ADD R4, R2, R4           // R4 = byte address in ICDIPTR
    STRB R1, [R4]            // write to ICDIPTR
    POP {R4-R5, PC}

// Data section
.data
message: .byte 0x40, 0x71, 0x71, 0x06, 0x39, 0x79 // "oFF1CE"
direction: .word 0 // 0 = right to left, 1 = left to rights