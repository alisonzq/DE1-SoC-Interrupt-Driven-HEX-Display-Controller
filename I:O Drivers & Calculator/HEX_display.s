@ task 1: HEX display drivers

// define any variables/memory space you need here
// your code starts here
.data
segments: 
.byte 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F
.byte 0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71

.equ HEX0, 0xFF200020

.text
// your code ends here

.global _start
_start:

// test case #1: flood selected segments
test_case_1:
    MOV R0, #0b111111
    BL HEX_clear_ASM    // clear all HEXs
    
    MOV R0, #0b111011
    BL HEX_flood_ASM    // flood HEX 5-3 and HEX 1-0
    
    MOV R0, #0b101010
    BL HEX_clear_ASM    // clear HEX 5, 3, 1

    B end // comment this out to go to test case #2
// end of test case #1

// test case #2: sequential writes to HEXs
test_case_2:
    MOV R0, #0b111111
    BL HEX_clear_ASM    // clear all HEXs
    
    MOV R4, #0x1       
    MOV R5, #7
    
// loop through HEX 0 to 5 and write 7 to C to them
loop_test_case:
    CMP R4, #0x20
    BGT    end      // change this line to 'BGT test_case_3' to go to test case #3
    
    MOV R0, R4
    MOV R1, R5
    BL  HEX_write_ASM
    
    LSL R4, #1
    ADD R5, #1
    B    loop_test_case
// end of test case #2

// test case #3: parallel and overlapping writes to HEXs
test_case_3:
    MOV R0, #0b111111
    BL HEX_clear_ASM    // clear all HEXs
    
    MOV R0, #0b010010
    MOV R1, #0xe
    BL  HEX_write_ASM   // write E to HEX 4, HEX 1
    
    MOV R0, #0b101001
    MOV R1, #0xffffffff
    BL  HEX_write_ASM   // write - sign to HEX 5, HEX 3, HEX 0
	
    MOV R0, #0b001100
    MOV R1, #0xc
    BL  HEX_write_ASM   // write C to HEX 3, HEX 2
    
    MOV R0, #0b000100
    MOV R1, #0x5
    BL  HEX_write_ASM   // write 5 to HEX 2

// end of test case #3

end:
    B     end

// ===================================  drivers  ========================================
	
HEX_clear_ASM:
	// your code starts here
	LDR A3, =HEX0 
	MOV A4, #0x00 

	B HEX_write_all
    // your code ends here
	
HEX_flood_ASM:
	// your code starts here
	LDR A3, =HEX0 
	MOV A4, #0x7F

	B HEX_write_all
    // your code ends here
	
HEX_write_ASM: 
	// your code starts here
	LDR A3, =HEX0
	LDR A4, =segments
	CMP R1, #0xffffffff
	MOVEQ A4, #0x40 //negative sign
	BEQ HEX_write_all
	
	LDRB A4, [A4, R1]
	B HEX_write_all
	
// ===================================  helper functions  ========================================
// you can define any additional subroutines in this area
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
    // your code ends here