.data
message: 
.byte 0x5c, 0x71, 0x71, 0x06, 0x39, 0x79   //o, F, F, l, C, E

segments: 
.byte 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F
.byte 0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71

.equ HEX0, 0xFF200020
.equ PB_ADDR, 0xFF200050
.equ PB_ADDR_EC, 0xFF20005C //edge capture
.equ PB_ADDR_INT, 0xFF200058 //interrupt mask
.equ TIMER_ADDR, 0xFFFEC600
.equ TIMER_CTRL_ADDR, 0xFFFEC608
.equ TIMER_INT_ADDR, 0xFFFEC60C

.text
.global _start

_start:
    LDR A1, =0x03938700 //load
    LDR A2, =0x7
    BL ARM_TIM_config_ASM



display_loop:
    PUSH {LR}
    BL rotate_message
    POP {LR}

    PUSH {LR}
    BL  display_message
    POP {LR}

    B display_loop

display_message:
    PUSH {LR}
    BL ARM_TIM_read_INT_ASM
    POP {LR}
    CMP A1, #0 //is interrupt set
    BEQ display_message

    PUSH {LR}
    BL ARM_TIM_clear_INT_ASM
    POP {LR}


    PUSH {V1, V2}
    MOV V2, #5
    MOV V1, #0b000001 //write to hex 0

loop_message:
    CMP V2, #0
    BLT return_display

    MOV A1, V1 // set hex display
    MOV A2, V2
    PUSH {LR}
    BL HEX_write_ASM
    POP {LR}

    LSL V1, V1, #1     //shift A1 to next hex display
    SUB V2, V2, #1

    B loop_message

return_display:
    POP {V1, V2}
    BX LR

rotate_message:
    PUSH {V1-V7}
    LDR V1, =message
    LDRB V2, [V1]
    LDRB V3, [V1, #1]
    LDRB V4, [V1, #2]
    LDRB V5, [V1, #3]
    LDRB V6, [V1, #4]
    LDRB V7, [V1, #5]

    STRB V2, [V1, #5] //move first char to end
    STRB V3, [V1]
    STRB V4, [V1, #1]
    STRB V5, [V1, #2]
    STRB V6, [V1, #3]
    STRB V7, [V1, #4]
    POP {V1-V7}
    BX LR


//PUSH BUTTONS
read_PB_data_ASM: 
	LDR A2, =PB_ADDR
	LDR A1, [A2] //read content of PB
	BX LR

PB_data_is_pressed_ASM:
	LDR A2, =PB_ADDR
	LDR A2, [A2]
	TST A2, A1
	MOVNE A1, #0x01 //is pushed
	MOVEQ A1, #0x00 //not pushed
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
	PUSH {LR}
	BL read_PB_edgecp_ASM
	POP {LR}
	STR A1, [A2]
	BX LR

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

//TIMER
//Arguments: A1 = count value, A2 = control register value
ARM_TIM_config_ASM:
    LDR A3, =TIMER_ADDR
    STR A1, [A3] //load the count value
    LDR A3, =TIMER_CTRL_ADDR
    STR A2, [A3] //set the timer to be enabled
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
	LDR A4, =message
	CMP A2, #0xffffffff
	MOVEQ A4, #0x40 //negative sign
	BEQ HEX_write_all
	
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