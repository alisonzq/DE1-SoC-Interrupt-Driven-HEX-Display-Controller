@ task 2: pushbutton drivers
.equ LED_ADDR, 0xFF200000

// define any variables/memory space you need here
// your code starts here

.equ PB_ADDR, 0xFF200050
.equ PB_ADDR_EC, 0xFF20005C //edge capture
	
// your code ends here

.global _start
_start:

// test case #1: is data pressed on selected PBs?
// we only check PB 0,1,3 (PB 2 is ignored)
test_case_1:
    MOV R5, #0
    
    // check PB 0
    MOV R0, #0x1
    BL    PB_data_is_pressed_ASM
    EOR    R5, R0
    
    // check PB 1
    MOV R0, #0x2
    BL    PB_data_is_pressed_ASM
    LSL R0, #1
    EOR    R5, R0
    
    // check PB 3
    MOV R0, #0x8
    BL    PB_data_is_pressed_ASM
    LSL R0, #3
    EOR    R5, R0
    
// write the results to LEDs
    MOV R0, R5
    BL    write_LEDs_ASM
    B    test_case_1    // comment this instruction out to move to test case #2

// test case #2: is edgecapture pressed? (without PB clear)
test_case_2:
    BL    PB_clear_edgecp_ASM   // only clear the edgecapture here

test_loop_2:
    MOV R5, #0  // holding the state of LEDs

    // check PB 0
    MOV R0, #0x1
    BL    PB_edgecp_is_pressed_ASM
    EOR    R5, R0
    
    // check PB 1
    MOV R0, #0x2
    BL    PB_edgecp_is_pressed_ASM
    LSL R0, #1
    EOR    R5, R0
    
    // check PB 2
    MOV R0, #0x4
    BL    PB_edgecp_is_pressed_ASM
    LSL R0, #2
    EOR    R5, R0
    
    // check PB 3
    MOV R0, #0x8
    BL    PB_edgecp_is_pressed_ASM
    LSL R0, #3
    EOR    R5, R0
    
    // write the results to LEDs
    MOV R0, R5
    BL    write_LEDs_ASM
    B    test_loop_2 // comment this instruction out to move to test case #3

// test case #3: is edgecapture pressed? (with PB clear)
test_case_3:
    BL        PB_clear_edgecp_ASM

    MOV     R5, #0  // holding the status of LEDs
    
test_loop_3:
    
    // check PB 0
    MOV     R0, #0x1
    BL        PB_edgecp_is_pressed_ASM
    CMP     R0, #1
    EOREQ     R5, #0x1  // flip the corresponding LEDs if PB 0 is released
    BLEQ    PB_clear_edgecp_ASM
    
    // check PB 1
    MOV     R0, #0x2
    BL        PB_edgecp_is_pressed_ASM
    CMP     R0, #1
    EOREQ     R5, #0x2  // flip the corresponding LEDs if PB 1 is released
    BLEQ    PB_clear_edgecp_ASM
    
    // check PB 2
    MOV     R0, #0x4
    BL        PB_edgecp_is_pressed_ASM
    CMP     R0, #1
    EOREQ     R5, #0x4 // flip the corresponding LEDs if PB 2 is released
    BLEQ    PB_clear_edgecp_ASM
    
    // check PB 3
    MOV     R0, #0x8
    BL        PB_edgecp_is_pressed_ASM
    CMP     R0, #1
    EOREQ     R5, #0x8 // flip the corresponding LEDs if PB 3 is released
    BLEQ     PB_clear_edgecp_ASM
    
    // write the results to LEDs
    MOV     R0, R5
    BL        write_LEDs_ASM
    
    B       test_loop_3

end:
    B   end

// LEDs Driver
// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
write_LEDs_ASM:
    LDR A2, =LED_ADDR    // load the address of the LEDs' state
    STR A1, [A2]         // update LED state with the contents of A1
    BX  LR
    

// ===================================  drivers  ========================================


read_PB_data_ASM: 
	// your code starts here
	LDR A2, =PB_ADDR
	LDR R0, [A2] //read content of PB
	BX LR
    // your code ends here

PB_data_is_pressed_ASM:
	// your code starts here
	LDR A2, =PB_ADDR
	LDR A2, [A2]
	TST A2, R0
	MOVNE R0, #0x01 //is pushed
	MOVEQ R0, #0x00 //not pushed
	BX LR	
    // your code ends here

read_PB_edgecp_ASM:
	// your code starts here
	LDR A2, =PB_ADDR_EC
	LDR R0, [A2] //read content of PB
	BX LR
    // your code ends here
	
PB_edgecp_is_pressed_ASM:
	// your code starts here
	LDR A2, =PB_ADDR_EC
	LDR A2, [A2]
	TST A2, R0
	MOVNE R0, #0x01 //is pushed
	MOVEQ R0, #0x00 //not pushed
	BX LR	
    // your code ends here
	
PB_clear_edgecp_ASM:
	// your code starts here
	PUSH {LR}
	BL read_PB_edgecp_ASM
	POP {LR}
	
	STR R0, [A2]
	
	BX LR

// ===================================  driver helpers  ========================================
// you can define any additional subroutines in this area


    // your code ends here
    
