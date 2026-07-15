@ task 3: stack-based calculator
calculator_stack: .space 16, 0x0    // define a stack for numbers

// define any variables/memory space you need here
// your code starts here
segments: 
.byte 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F
.byte 0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71

.equ HEX0, 0xFF200020
.equ PB_ADDR, 0xFF200050
.equ PB_ADDR_EC, 0xFF20005C //edge capture

.equ SW_ADDR, 0xFF200040 
.equ LED_ADDR, 0xFF200000

.text
// your code ends here

.global _start
_start:
    MOV R0, #0
    
// your code starts here
	MOV V1, #0 //number of elements in stack

	MOV R0, #0b111111
    BL HEX_clear_ASM    // clear all HEXs

 	BL PB_clear_edgecp_ASM // clear all push buttons

	BL clear_slider_switches_ASM //clear all switches and leds

	LDR V5, =calculator_stack

pb_loop:
	// check PB 0
    MOV     A1, #0x1
    BL      PB_edgecp_is_pressed_ASM
    CMP     A1, #1
    BEQ   	push_to_stack

    // check PB 1
    MOV     A1, #0x2
    BL      PB_edgecp_is_pressed_ASM
    CMP     A1, #1
    BEQ   	addition

    // check PB 2
    MOV     A1, #0x4
    BL      PB_edgecp_is_pressed_ASM
    CMP     A1, #1
    BEQ   	substraction

    // check PB 3
    MOV     A1, #0x8
    BL      PB_edgecp_is_pressed_ASM
    CMP     A1, #1
    BEQ   	reset
	
	B pb_loop

	
push_to_stack:
	PUSH {LR}
	BL read_slider_switches_ASM
	POP {LR}

	CMP V1, #16 //check if stack is full
	MOVGE R1, #0x1
	BGE stack_display

	STRB A1, [V5, V1] //store the number on the stack
	ADD V1, V1, #1 //keep track of number of elements in stack
	
	PUSH {LR}
	BL PB_clear_edgecp_ASM //clear after operation ends
	POP {LR}

	B pb_loop

addition:
	CMP V1, #2
	MOVLT R1, #0x0
	BLT stack_display

	SUB V1, V1, #1 //decrement the stack pointer
	LDRSB V2, [V5, V1] //load the top element of the stack
	SUB V1, V1, #1 //decrement the stack pointer
	LDRSB A4, [V5, V1] //load second top element of the stack
	ADD V2, V2, A4 //add the numbers
	STRB V2, [V5, V1]
	ADD V1, V1, #1 //increment the stack pointer

	B result_display

substraction:
	CMP V1, #2
	MOVLT R1, #0x0
	BLT stack_display

	SUB V1, V1, #1
	LDRSB V2, [V5, V1] //load the top element of the stack
	SUB V1, V1, #1 //decrement the stack pointe
	LDRSB A4, [V5, V1] //load second top element of the stack
	SUB V2, V2, A4 //substract the numbers
	STRB V2, [V5, V1]
	ADD V1, V1, #1 //increment the stack pointer

	B result_display

stack_display:
	MOV R0, #0b000001 //write either 0 or 1 to HEX0 depending on who calls
	PUSH {LR}
	BL HEX_write_ASM
	POP {LR}

    MOV R0, #0b111100 //clear all other hex
	PUSH {LR}
    BL HEX_clear_ASM
	POP {LR}

	MOV R0, #0b000010
	MOV R1, #0xe
	PUSH {LR}
	BL HEX_write_ASM
	POP {LR}

	PUSH {LR}
	BL PB_clear_edgecp_ASM //clear after operation ends
	POP {LR}

	B pb_loop

result_display:
	MOV R0, #0b011111 //clear all hex
	PUSH {LR}
	BL HEX_clear_ASM
	POP {LR}

	TST V2, #0x80 //check if result is negative
	MVNNE V2, V2 //if negative, invert bits
	ADDNE V2, V2, #1 //add 1 to get 2s complement
	MOVNE R0, #0b010000 
	MOVNE R1, #0xffffffff
	PUSH {LR}
	BLNE HEX_write_ASM
	POP {LR}

	AND V2, V2, #0x7f //to calculate magnitude, remove sign bit (bit 7) 0111 1111

	//get digit for thousand
	MOV A1, #0
	MOV A4, V2
	MOV V3, #1000
	PUSH {LR}
	BL division_loop
	POP {LR}
	CMP A1, #0
	MOVEQ R1, #0x00 //if no digit, write 0
	MOVNE R1, A1 //else write the digit
	MULNE A1, A1, V3
	SUBNE V2, V2, A1 //remove thousand from the number
	MOV R0, #0b001000 //write to hex 4
	PUSH {LR}
	BL HEX_write_ASM
	POP {LR}

	//get digit for hundreds
	MOV A1, #0
	MOV A4, V2
	MOV V3, #100
	PUSH {LR}
	BL division_loop
	POP {LR}
	CMP A1, #0
	MOVEQ R1, #0x00 //if no digit, write 0 to A2
	MOVNE R1, A1
	MULNE A1, A1, V3
	SUBNE V2, V2, A1 //remove hundreds from the number
	MOV R0, #0b000100 //write to hex 3
	PUSH {LR}
	BL HEX_write_ASM
	POP {LR}

	//get digit for tens
	MOV A1, #0 //count number of times must substract
	MOV A4, V2
	MOV V3, #10
	PUSH {LR}
	BL division_loop
	POP {LR}
	CMP A1, #0
	MOVEQ R1, #0x00 //if no digit, write 0 to A2
	MOVNE R1, A1
	MULNE A1, A1, V3
	SUBNE V2, V2, A1 //remove tens from the number
	MOV R0, #0b000010
	PUSH {LR}
	BL HEX_write_ASM
	POP {LR}

	//get digit for ones
	MOV A1, #0
	MOV A4, V2
	MOV V3, #1 //get the ones by substracting 1 loop
	PUSH {LR}
	BL division_loop
	POP {LR}
	MOV R1, A1
	MOV R0, #0b000001
	PUSH {LR}
	BL HEX_write_ASM
	POP {LR}

	PUSH {LR}
	BL PB_clear_edgecp_ASM //clear after operation ends
	POP {LR}

	B pb_loop

division_loop:
	SUB A4, A4, V3
    CMP A4, #0
    BXLT LR
	ADD A1, A1, #1
    B division_loop

reset:
	PUSH {LR}
	BL PB_clear_edgecp_ASM
	POP {LR}

	B _start


read_slider_switches_ASM:
    LDR A2, =SW_ADDR     // load the address of slider switch state
    LDR A1, [A2]         // read slider switch state 
	AND A1, A1, #0xFF //keep only 0..7 bits 
	PUSH {LR}
	BL write_LEDs_ASM
	POP {LR}
    BX  LR

clear_slider_switches_ASM:
	LDR A3, =SW_ADDR 
	MOV A1, #0x00 
	STR A1, [A3]
	PUSH {LR}
	BL write_LEDs_ASM
	POP {LR}
	BX LR

write_LEDs_ASM:
    LDR A2, =LED_ADDR    // load the address of the LEDs' state
    STR A1, [A2]         // update LED state with the contents of A1
    BX  LR

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
	LDR A4, =segments
	CMP R1, #0xffffffff
	MOVEQ A4, #0x40 //negative sign
	BEQ HEX_write_all
	
	LDRB A4, [A4, R1]
	B HEX_write_all
	
HEX_write_all:
	PUSH {LR}
	TST R0, #0x01 //if hex0 is selected
	MOV A2, #0
	BLNE display
	
	TST R0, #0x02 //hex1
	MOV A2, #1
	BLNE display	
	
	TST R0, #0x04  //hex2
	MOV A2, #2
	BLNE display
	
	TST R0, #0x08  //hex3
	MOV A2, #3
	BLNE display
	
	TST R0, #0x10  //hex4
	MOV A2, #16
	BLNE display
	
	TST R0, #0x20  //hex5
	MOV A2, #17
	BLNE display
	POP {LR}
	BX LR
	
display:
	STRB A4, [A3, A2]
	BX LR
	
read_PB_data_ASM: 
	LDR A2, =PB_ADDR
	LDR R0, [A2] //read content of PB
	BX LR

PB_data_is_pressed_ASM:
	LDR A2, =PB_ADDR
	LDR A2, [A2]
	TST A2, R0
	MOVNE R0, #0x01 //is pushed
	MOVEQ R0, #0x00 //not pushed
	BX LR	

read_PB_edgecp_ASM:
	LDR A2, =PB_ADDR_EC
	LDR R0, [A2] //read content of PB
	BX LR
	
PB_edgecp_is_pressed_ASM:
	LDR A2, =PB_ADDR_EC
	LDR A2, [A2]
	TST A2, R0
	MOVNE R0, #0x01 //is pushed
	MOVEQ R0, #0x00 //not pushed
	BX LR	
	
PB_clear_edgecp_ASM:
	PUSH {LR}
	BL read_PB_edgecp_ASM
	POP {LR}
	STR R0, [A2]
	BX LR
// your code ends here    
// remember to copy and paste all the drivers/helper functions
// you have written for the previous tasks here