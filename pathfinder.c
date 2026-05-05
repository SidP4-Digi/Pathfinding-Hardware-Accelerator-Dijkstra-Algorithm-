#include "uart.h"
#include "flash.h"

// Define accelerator registers
#define reg_config_and_status  (*(volatile uint32_t*)0x03000000)
#define reg_start_end_node     (*(volatile uint32_t*)0x03000004)

#define ACCELERATOR_SRAM_START_ADDR		             0x03000010

// Define accelerator control/status (CSR) bits
#define MASK_CSR_RESET 1 << 0
#define MASK_CSR_ENABLE 1 << 1
#define MASK_CSR_DONE  1 << 2

// Define the NODE_COUNT
#define NODE_COUNT 16
#define NODE_MATRIX_SIZE NODE_COUNT * NODE_COUNT


void init_accelerator() {
    // 1. Initialize accelerator
    reg_config_and_status = 0;
    reg_start_end_node = 0;

    // 2. Reset accelerator
    reg_config_and_status = reg_config_and_status | MASK_CSR_RESET;  // set reset bit
    reg_config_and_status &= ~MASK_CSR_RESET; // clear reset bit
    
    // 3. Write the Graph node adjacency matrix to SRAM of accelerator
    // Each flash read returns 4 bytes, while each node weight is 1 byte
    // So we need NODE_MATRIX_SIZE/4 iterations to read all node weights from flash
    int iter_max = NODE_MATRIX_SIZE / 4;
    for (int i = 0; i < iter_max; i++) {
        // i * 4 because each entry (signed 32-bit integer) is 4 bytes
        uint32_t sram_address = ACCELERATOR_SRAM_START_ADDR + i*4;
        (*(volatile int*)(sram_address)) = read_dec_entry_from_flash(i);
    }
}

int read_dec_entry_from_accelerator_sram(int index) {
	// i * 4 because each entry (signed 32-bit integer) is 4 bytes
	uint32_t sram_address = ACCELERATOR_SRAM_START_ADDR + index*4;

	return (*(volatile int*)(sram_address));
}

void init_picosoc() {
	#define SRAM_ADDR_HEAD 0x00000000
	#define SRAM_ADDR_END  0x000003FF

    // Initilize SRAM (Otherwise the post-synthesis/layout simulation will fail, finished within 17192 cycles)
    volatile uint32_t* sram_addr = 0x00000000;
    for (sram_addr = 0; sram_addr <= (volatile uint32_t*) SRAM_ADDR_END; sram_addr += 4) {
        *sram_addr = 0;
    }

    // Initialize UART
    init_uart();
}

void accelerate_pathfinder(int start_node) { 
    // 1. Set the start_node and end_node
    // Only use the lower 16 bits of this register: 15:8 is the start_node, 7:0 is the end_node
    // reg_start_end_node = start_node << 8 | end_node;
    reg_start_end_node = start_node;

    // 2. Start accelerator
    reg_config_and_status |= MASK_CSR_ENABLE;

    // 3. Wait for accelerator to finish
    while (!(reg_config_and_status & MASK_CSR_DONE));

    // 4. Disable accelerator
    reg_config_and_status &= ~MASK_CSR_ENABLE;
}


// void print_adjacency_matrix(void) {
//     print_str("\nThe Graph node adjacency matrix:\n");
//     for (int i = 0; i < NODE_COUNT; i++) {
//         for (int j = 0; j < NODE_COUNT; j += 4) {
//             // Read 4 node weights at once since each SRAM read returns 4 bytes
//             int word = read_dec_entry_from_accelerator_sram(i * NODE_COUNT/4 + j/4);
            
//             // Extract and print each byte from the word
//             for (int k = 0; k < 4 && (j + k) < NODE_COUNT; k++) {
//                 // Shift and mask to get each byte
//                 int weight = (word >> (k * 8)) & 0xFF;
//                 print_hex(weight, 2);
//                 print_str(" ");
//             }
//         }
//         print_str("\n");
//     }
// }

void main(void)
{
    // Initialize PicoSoC
    init_picosoc();

    // Initialize accelerator and load matrix data
    init_accelerator();

	//--------------------------------------------------------------------
	// Run all test cases
	//--------------------------------------------------------------------
	// 1. Indicate that the pathfinding will be started
	print_char(-2);
	
	// 2. Run all test cases
	for (int i = 0; i < NODE_COUNT-1; i++) {
		// for (int j = i + 1; j < NODE_COUNT; j++) {
			accelerate_pathfinder(i);
		// }
	}

	// 3. Indicate that the pathfinding is finished
	print_char(-3);

	//--------------------------------------------------------------------
	// Print the adjacency matrix
	//--------------------------------------------------------------------
	// print_adjacency_matrix();

    // End of Program
    print_char(-1);
}

/*
 * Define the entry point of the program.
 */
__attribute__((section(".text.start")))
void _start(void)
{
	main();
}
