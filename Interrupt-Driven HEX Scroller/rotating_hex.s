.section .vectors, "ax"
B _start            // reset vector
B SERVICE_UND       // undefined instruction vector
B SERVICE_SVC       // software interrupt vector
B SERVICE_ABT_INST  // aborted prefetch vector
B SERVICE_ABT_DATA  // aborted data vector
.word 0             // unused vector
B SERVICE_IRQ       // IRQ interrupt vector
B SERVICE_FIQ       // FIQ interrupt vector

.data
office: 
.byte 0x5c, 0x71, 0x71, 0x06, 0x39, 0x79

ecse324: 
.byte 0x79, 0x39, 0x6D, 0x79, 0x00, 0x4F,0x5B,0x66

ecse325: 
.byte 0x79, 0x39, 0x6D, 0x79, 0x00, 0x4F,0x5B,0x6D

code:
.byte 0x39, 0x5c, 0x5E, 0x79

cafe:
.byte 0x39, 0x77, 0x71,0x79

.align 4
message_buffer: .space 32

.align 4
office_size: .word 6

.align 4
ecse_size: .word 8

.align 4
code_cafe_size: .word 4

.align 4
total_size: .space 4

.align 4
timer_configs: .word 0x03938700, 0x05F5E100, 0x0BEBC200

.align 4
PB_int_flag: .word 0x0

.align 4
tim_int_flag: .word 0x0

.align 4
is_reversed: .word 0

.align 4
current_config: .word 0

.align 4
previous_sw_state: .word 0

.align 4
was_paused: .word 0

.align 4
previous_dir_state: .word 0

.equ HEX0, 0xFF200020
.equ PB_ADDR, 0xFF200050
.equ PB_ADDR_EC, 0xFF20005C //edge capture
.equ PB_ADDR_INT, 0xFF200058 //interrupt mask
.equ TIMER_ADDR, 0xFFFEC600
.equ TIMER_CTRL_ADDR, 0xFFFEC608
.equ TIMER_INT_ADDR, 0xFFFEC60C
.equ LED_ADDR, 0xFF200000
.equ SW_ADDR, 0xFF200040 



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
    BL  CONFIG_GIC           // configure the ARM GIC
    // NOTE: write to the pushbutton KEY interrupt mask register
    // Or, you can call enable_PB_INT_ASM subroutine from previous task
    // to enable interrupt for ARM A9 private timer, 
    // use ARM_TIM_config_ASM subroutine
    LDR R0, =0xFF200050      // pushbutton KEY base address
    MOV R1, #0xF             // set interrupt mask bits
    STR R1, [R0, #0x8]       // interrupt mask register (base + 8)

    LDR V5, =is_reversed
    LDR V6, =timer_configs 
    LDR V7, =current_config

    LDR A1, =0x03938700 //initial config speed to 0.3s
    LDR A2, =0x7
    PUSH {LR}
    BL ARM_TIM_config_ASM
    POP {LR}

    PUSH {LR}
    BL get_office
    POP {LR}

    MOV A4, #0
    PUSH {LR}
    BL  display_message
    POP {LR}

    // enable IRQ interrupts in the processor
    MOV R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0
IDLE:
    LDR A1, =tim_int_flag
    LDR A2, [A1]
    CMP A2, #1
    BEQ timer_action

    LDR A1, =PB_int_flag
    LDR A2, [A1]
    CMP A2, #0
    BNE pushbutton_action

    B slider_switches

    B IDLE // This is where you write your main program task(s)


timer_action:
    LDR A1, =tim_int_flag
    MOV A2, #0 //reset timer flag
    STR A2, [A1]
    
    PUSH {LR}
    BL display_message
    POP {LR}

    PUSH {LR}
    BL rotate_message
    POP {LR}

    B IDLE

display_message:
    PUSH {V1, V2}
    MOV V2, #5
    MOV V1, #0b000001 //write to hex 0

loop_message:
    CMP V2, #0
    BLT return_display

    MOV A1, V1  // set hex display
    MOV A2, V2
    PUSH {LR}
    BL HEX_write_ASM
    POP {LR}

    LSL V1, V1, #1 //shift A1 to next hex display
    SUB V2, V2, #1

    B loop_message

return_display:
    POP {V1, V2}
    BX LR

rotate_message:
    LDR A1, =is_reversed
    LDR A1, [A1]
    CMP A1, #0
    PUSH {LR}
    BLEQ rotate_message_left
    BLNE rotate_message_right
    POP {LR}

    BX LR

rotate_message_left:
    PUSH {V1-V3}
    LDR V1, =message_buffer
    LDR V2, =total_size
    LDR V2, [V2] //get total size
    SUB V2, V2, #1 //get last index

    LDRB V3, [V1] //load first character

rotate_left_loop:
    LDRB A1, [V1, #1] //load next character
    STRB A1, [V1] //store next character to current

    ADD V1, V1, #1 // next character
    SUB V2, V2, #1 //decrement index

    CMP V2, #0 //if reached end of message
    BNE rotate_left_loop

    STRB V3, [V1] //store first character to last
    POP {V1-V3}
    BX LR

rotate_message_right:
    PUSH {V1-V3}
    LDR V1, =message_buffer
    LDR V2, =total_size
    LDR V2, [V2] //get total size
    SUB V2, V2, #1 //get last index
    LDRB V3, [V1, V2] //load last character
rotate_right_loop:
    SUB V2, V2, #1
    LDRB A1, [V1, V2] //load current character
    ADD V2, V2, #1
    STRB A1, [V1, V2] //store it in next position and increment index
    SUB V2, V2, #1 //decrement index

    CMP V2, #0 //if reached end of message
    BNE rotate_right_loop

    STRB V3, [V1] //store last character to first
    POP {V1-V3}
    BX LR


pushbutton_action:
    CMP A2, #0x1
    PUSH {LR}
    BLEQ decrease_speed
    POP {LR}

    CMP A2, #0x2
    PUSH {LR}
    BLEQ increase_speed
    POP {LR}

    CMP A2, #0x4
    PUSH {LR}
    BLEQ change_direction
    POP {LR}
    
    CMP A2, #0x8
    PUSH {LR}
    BLEQ pause_or_resume //always check for pause resume
    POP {LR}
end_push_button_action:
    LDR A1, =PB_int_flag
    MOV A2, #0
    STR A2, [A1]

    B IDLE

decrease_speed:
    LDR A1, [V7]
    CMP A1, #2 //if min speed 1s do nothing
    BEQ END_KEY_ISR

    ADD A1, A1, #1 // slower speed
    STR A1, [V7] // store current speed

    LDR A2, =TIMER_CTRL_ADDR
    LDR A2, [A2] //if paused then continue being paused

    LDR A1, [V6, A1, LSL #2] // load new speed (curr * 4)
    //LDR A2, =0x7
    PUSH {LR}
    BL ARM_TIM_config_ASM
    POP {LR}
    BX LR

increase_speed:
    LDR A1, [V7]
    CMP A1, #0 //if max speed 0.3s do nothing
    BEQ END_KEY_ISR

    SUB A1, A1, #1 // slower speed
    STR A1, [V7] // store current speed

    LDR A2, =TIMER_CTRL_ADDR
    LDR A2, [A2] //if paused then continue being paused

    LDR A1, [V6, A1, LSL #2] // load new speed (curr * 4)
    //LDR A2, =0x7
    PUSH {LR}
    BL ARM_TIM_config_ASM
    POP {LR}
    BX LR

change_direction:
    LDR A1, [V5] //load current direction

    LDR A2, =previous_dir_state
    STR A1, [A2] //store current direction

    EOR A1, A1, #0x1 // reverse bit
    STR A1, [V5] // reverse direction

    LDR A2, =previous_sw_state
    LDR A3, [A2]
    PUSH {LR}
    BL read_slider_switches_ASM
    POP {LR}
    CMP A1, A3 //if changed slider switches
    MOVNE A4, #1 
    MOVEQ A4, #0

    LDR A1, =was_paused
    LDR A2, [A1]
    TST A2, A4 //if paused and change in slider switches
    MOV A2, #0
    STR A2, [A1] //clear was paused flag
    BXNE LR 

    LDR A1, =TIMER_CTRL_ADDR
    LDR A2, [A1]
    TST A2, #0x1 //paused?
    BXEQ LR //if paused do not rotate

rotate_first:
    PUSH {LR}
    BL rotate_message  // Rotate immediately
    POP {LR}

    PUSH {LR}
    //BL display_message
    POP {LR}

    BX LR 

pause_or_resume:
    LDR A1, =TIMER_CTRL_ADDR
    LDR A2, [A1]
    TST A2, #0x1 //paused?
    BICNE A2, A2, #0x1 //pause timer (clear enable bit)
    ORREQ A2, #0x1 //resume timer
    STR A2, [A1] 

    MOV A1, #0x0 // clear LEDs if paused
	PUSH {LR}
	BLNE write_LEDs_ASM
	POP {LR}   
    BXNE LR 

    LDR A2, =previous_sw_state
    LDR A3, [A2]
    PUSH {LR}
    BL read_slider_switches_ASM
    POP {LR}
    CMP A1, A3 //if changed slider switches
    MOVNE A4, #0 //rotate after
    MOVEQ A4, #1 //rotate immediately

    LDR A1, [V5]
    LDR A2, =previous_dir_state
    LDR A3, [A2]
    CMP A1, A3
    STR A1, [A2] //reset prev to current direction
    MOVNE A3, #1 //if changed direction rotate immediately
    MOVEQ A3, #0 //if not changed direction do not rotate
    TST A4, A3
    PUSH {LR}
    BLNE rotate_first // did not change sw and changed direction
    POP {LR}

    LDR A1, =was_paused
    MOV A2, #1
    STR A2, [A1]

    LDR A1, =TIMER_ADDR //get timer load value if resumed
    LDR A1, [A1]

    PUSH {LR}
    BL display_led
    POP {LR}

    BX LR

slider_switches:
    PUSH {LR}
	BL read_slider_switches_ASM
	POP {LR}

    LDR A2, =previous_sw_state
    LDR A3, [A2]
    CMP A1, A3 //if no change in slider switches
    BEQ IDLE

    STR A1, [A2] //store new slider switches state

    CMP A1, #0 //nothing selected display office
    PUSH {LR}
    BLEQ get_office
    BLNE get_message
    POP {LR}


    B IDLE

get_office:
    LDR A2, =office
    LDR A3, =office_size
    MOV A4, #0
    PUSH {LR}
    BL append_word
    POP {LR}

    LDR A3, =total_size
    STR A4, [A3] //store total length

    BX LR

get_message:
    MOV A4, #0 //store total length
    
    ANDS A2, A1, #1
    CMP A2, #0b0001 //selected ecse324
    LDREQ A2, =ecse324
    LDREQ A3, =ecse_size
    PUSH {LR}
    BLEQ append_word 
    POP {LR}

    ANDS A2, A1, #2
    CMP A2, #0b0010 //selected ecse325
    LDREQ A2, =ecse325
    LDREQ A3, =ecse_size
    PUSH {LR}
    BLEQ append_word 
    POP {LR}

    ANDS A2, A1, #4
    CMP A2, #0b0100 //selected code
    LDREQ A2, =code
    LDREQ A3, =code_cafe_size
    PUSH {LR}
    BLEQ append_word 
    POP {LR}

    ANDS A2, A1, #8
    CMP A2, #0b1000 //selected cafe
    LDREQ A2, =cafe
    LDREQ A3, =code_cafe_size
    PUSH {LR}
    BLEQ append_word 
    POP {LR}

    CMP A4, #4 //duplicate message to make it large enough
    PUSH {LR}
    BLEQ duplicate
    POP {LR}

    //only if selected more than 1 then add a space to the end
    CMP A4, #8
    BEQ end_append
    CMP A4, #0
    BEQ end_append
    PUSH {LR}
    BL add_space
    POP {LR}
end_append:
    LDR A3, =total_size
    STR A4, [A3] //store total length
    BX LR

append_word:
    PUSH {A1, V1}
    LDR V1, =message_buffer

    CMP A4, #0 // add space before appending word if not first word
    PUSH {LR}
    BLNE add_space
    POP {LR}

    MOV A1, #0
    LDR A3, [A3] //get length of word
    PUSH {LR}
    BL add_letters_loop
    POP {LR}

    POP {A1, V1}
    BX LR

add_letters_loop:
    CMP A3, A1 //if added all to buffer
    BXEQ LR

    PUSH {V2}
    LDRB V2, [A2, A1] //get letter
    STRB V2, [V1, A4] //add letter to buffer

    ADD A1, A1, #1
    ADD A4, A4, #1
    POP {V2}
    B add_letters_loop

add_space:
    PUSH {V1, V2}
    LDR V1, =message_buffer
    MOV V2, #0
    STRB V2, [V1, A4] //add space to buffer
    ADD A4, A4, #1 //add space length of 1
    POP {V1, V2}
    BX LR

duplicate:
    ANDS A2, A1, #4
    CMP A2, #0b0100 //selected code
    LDREQ A2, =code
    LDREQ A3, =code_cafe_size
    PUSH {LR}
    BLEQ duplicate_word 
    POP {LR}

    ANDS A2, A1, #8
    CMP A2, #0b1000 //selected cafe
    LDREQ A2, =cafe
    LDREQ A3, =code_cafe_size
    PUSH {LR}
    BLEQ duplicate_word 
    POP {LR}

    BX LR

duplicate_word:
    PUSH {A1, V1}
    LDR V1, =message_buffer

    MOV A1, #0
    LDR A3, [A3] //get length of word
    PUSH {LR}
    BL add_letters_loop
    POP {LR}

    POP {A1, V1}
    BX LR

CONFIG_GIC:
    PUSH {LR}
/* To configure the FPGA KEYS interrupt (ID 73):
* 1. set the target to cpu0 in the ICDIPTRn register
* 2. enable the interrupt in the ICDISERn register */
/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
/* NOTE: you can configure different interrupts
   by passing their IDs to R0 and repeating the next 3 lines */
    MOV R0, #73            // KEY port (Interrupt ID = 73)
    MOV R1, #1             // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT

    /* Configure Timer Interrupt (ID = 29) */
    MOV R0, #29            // Timer interrupt ID
    MOV R1, #1             // Target CPU0
    BL CONFIG_INTERRUPT    // Configure timer interrupt

/* configure the GIC CPU Interface */
    LDR R0, =0xFFFEC100    // base address of CPU Interface
/* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF        // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
/* Set the enable bit in the CPU Interface Control Register (ICCICR).
* This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
/* Set the enable bit in the Distributor Control Register (ICDDCR).
* This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =0xFFFED000
    STR R1, [R0]
    POP {PC}



/*
* Configure registers in the GIC for an individual Interrupt ID
* We configure only the Interrupt Set Enable Registers (ICDISERn) and
* Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
* values are used for other registers in the GIC
* Arguments: R0 = Interrupt ID, N
* R1 = CPU target
*/
CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
/* Configure Interrupt Set-Enable Registers (ICDISERn).
* reg_offset = (integer_div(N / 32) * 4
* value = 1 << (N mod 32) */
    LSR R4, R0, #3    // calculate reg_offset
    BIC R4, R4, #3    // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4    // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1        // enable
    LSL R2, R5, R2    // R2 = value
/* Using the register address in R4 and the value in R2 set the
* correct bit in the GIC register */
    LDR R3, [R4]      // read current register value
    ORR R3, R3, R2    // set the enable bit
    STR R3, [R4]      // store the new register value
/* Configure Interrupt Processor Targets Register (ICDIPTRn)
* reg_offset = integer_div(N / 4) * 4
* index = N mod 4 */
    BIC R4, R0, #3    // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4    // R4 = word address of ICDIPTR
    AND R2, R0, #0x3  // N mod 4
    ADD R4, R2, R4    // R4 = byte address in ICDIPTR
/* Using register address in R4 and the value in R2 write to
* (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, PC}


/*--- Undefined instructions --------------------------------------*/
SERVICE_UND:
    B SERVICE_UND
/*--- Software interrupts ----------------------------------------*/
SERVICE_SVC:
    B SERVICE_SVC
/*--- Aborted data reads ------------------------------------------*/
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA
/*--- Aborted instruction fetch -----------------------------------*/
SERVICE_ABT_INST:
    B SERVICE_ABT_INST
/*--- IRQ ---------------------------------------------------------*/
SERVICE_IRQ:
    PUSH {R0-R7, LR}
/* Read the ICCIAR from the CPU Interface */
    LDR R4, =0xFFFEC100
    LDR R5, [R4, #0x0C] // read from ICCIAR
/* NOTE: Check which interrupt has occurred (check interrupt IDs)
   Then call the corresponding ISR
   If the ID is not recognized, branch to UNEXPECTED
   See the assembly example provided in the DE1-SoC Computer Manual
   on page 46 */
Timer_check:
    CMP R5, #29 // check for interrupt timer 29
    BNE Pushbutton_check
    BL ARM_TIM_ISR
    B EXIT_IRQ

Pushbutton_check:
    CMP R5, #73
UNEXPECTED:
    BNE UNEXPECTED      // if not recognized, stop here
    BL KEY_ISR
EXIT_IRQ:
/* Write to the End of Interrupt Register (ICCEOIR) */
    STR R5, [R4, #0x10] // write to ICCEOIR
    POP {R0-R7, LR}
    SUBS PC, LR, #4
/*--- FIQ ---------------------------------------------------------*/
SERVICE_FIQ:
    B SERVICE_FIQ

KEY_ISR:
    PUSH {LR}
    BL read_PB_edgecp_ASM
    POP {LR}

    LDR A2, =PB_int_flag
    STR A1, [A2] //store content of pushbutton edge capture to pb_int_flag

    PUSH {LR}
    BL PB_clear_edgecp_ASM // clear the interrupt
    POP {LR}
END_KEY_ISR:
    BX LR

ARM_TIM_ISR:
    LDR A1, =tim_int_flag
    CMP A1, #1
    BXEQ LR //if still in action dont do anything

    MOV A2, #1
    STR A2, [A1] //store 1 to tim_int_flag

    PUSH {LR}
    BL ARM_TIM_clear_INT_ASM
    POP {LR}

    BX LR

display_led:
    LDR A2, =TIMER_CTRL_ADDR
    LDR A2, [A2]
    TST A2, #0x1 //paused?
    BXEQ LR //if paused don't display

    LDR A4, =0x03938700
    CMP A1, A4 // 0.3s
    MOVEQ A1, #0x7
    LDR A4, =0x05F5E100
    CMP A1, A4 // 0.5s
    MOVEQ A1, #0x1F
    LDR A4, =0x0BEBC200
    CMP A1, A4 // 1s
    LDREQ A1, =0x3FF
	PUSH {LR}
	BL write_LEDs_ASM
	POP {LR}

    BX LR

//TIMER
//Arguments: A1 = count value, A2 = control register value
ARM_TIM_config_ASM:
    LDR A3, =TIMER_ADDR
    STR A1, [A3] //load the count value
    LDR A3, =TIMER_CTRL_ADDR
    STR A2, [A3] //set the timer to be enabled

	PUSH {LR}
	BL display_led
	POP {LR}

    //display leds 
    BX LR

//return F in A1
ARM_TIM_read_INT_ASM:
    LDR A3, =TIMER_INT_ADDR
    LDR A1, [A3]
    AND A1, A1, #0x1 //mask bits except 0th bit
    BX LR

ARM_TIM_clear_INT_ASM:
    LDR A3, =TIMER_INT_ADDR
    MOV A1, #0x1
    STR A1, [A3]
    BX LR

//PUSH BUTTON
enable_PB_INT_ASM:
    LDR A2, =PB_ADDR_INT
    LDR A3, [A2] //read current interrupt mask
    ORR A3, A3, A1 //set the interrupt mask bits for the pushbuttons given by A1
    STR A3, [A2] //write back the updated interrupt mask
    BX LR

disable_PB_INT_ASM:
    LDR A2, =PB_ADDR_INT
    LDR A3, [A2] //read current interrupt mask
    BIC A3, A3, A1 //clear the interrupt mask bits for the pushbuttons given by A1
    STR A3, [A2] //write back the updated interrupt mask
    BX LR

read_PB_edgecp_ASM:
	LDR A2, =PB_ADDR_EC
	LDR A1, [A2] //read content of PB
	BX LR
	
PB_edgecp_is_pressed_ASM:
	LDR A2, =PB_ADDR_EC
	LDR A2, [A2]
	TST A2, A1
	MOVNE A1, #0x01 //is pushed
	MOVEQ A1, #0x00 //not pushed
	BX LR	
	
PB_clear_edgecp_ASM:

    //MOV R2, #0xF
    //STR R2, [R0, #0xC]     // clear the interrupt

	PUSH {LR}
	BL read_PB_edgecp_ASM
	POP {LR}
	STR A1, [A2]
	BX LR

//LED
write_LEDs_ASM:
    LDR A2, =LED_ADDR    // load the address of the LEDs' state
    STR A1, [A2]         // update LED state with the contents of A1
    BX  LR

//SLIDE SWITCHES
read_slider_switches_ASM:
    LDR A2, =SW_ADDR     // load the address of slider switch state
    LDR A1, [A2]         // read slider switch state 
	AND A1, A1, #0xF //keep only 0..3 bits 
    BX  LR

clear_slider_switches_ASM:
	LDR A3, =SW_ADDR 
	MOV A1, #0x00 
	STR A1, [A3]
	BX LR

//HEX DISPLAY
HEX_clear_ASM:
	LDR A3, =HEX0 
	MOV A4, #0x00 
	B HEX_write_all
	
HEX_flood_ASM:
	LDR A3, =HEX0 
	MOV A4, #0x7F
	B HEX_write_all
	
HEX_write_ASM: 
	LDR A3, =HEX0
    LDR A4, =message_buffer
	CMP A2, #0xffffffff
	MOVEQ A4, #0x40 //negative sign
	BEQ HEX_write_all
	
    //write specified message from A4
	LDRB A4, [A4, A2]
	B HEX_write_all
	
HEX_write_all:
	PUSH {LR}
	TST A1, #0x01 //if hex0 is selected
	MOV A2, #0
	BLNE display
	
	TST A1, #0x02 //hex1
	MOV A2, #1
	BLNE display	
	
	TST A1, #0x04  //hex2
	MOV A2, #2
	BLNE display
	
	TST A1, #0x08  //hex3
	MOV A2, #3
	BLNE display
	
	TST A1, #0x10  //hex4
	MOV A2, #16
	BLNE display
	
	TST A1, #0x20  //hex5
	MOV A2, #17
	BLNE display
	POP {LR}
	BX LR
	
display:
	STRB A4, [A3, A2]
	BX LR