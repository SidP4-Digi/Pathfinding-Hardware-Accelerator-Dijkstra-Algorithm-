//------------------------------------------------------------------------------
// Dijkstra's Algorithm Accelerator for ET4351 project
//
// Authors:
//     Ang Li <Ang.Li@tudelft.nl>
//     Yizhuo Wu <Yizhuo.Wu@tudelft.nl>
//
// Created: December 22, 2024
// Version: 0.1.0
//
//------------------------------------------------------------------------------
module accelerator_pf_dijkstra #(
    parameter NODE_COUNT            = 16,                                      // Number of nodes in graph
    parameter NODE_WIDTH            = 8,                                       // Width of node data
    parameter NODE_WEIGHT_WIDTH     = 8,                                       // Width of node weight data
    parameter MEM_WIDTH             = 32,                                      // Width of memory data
    parameter MEM_DEPTH             = (NODE_COUNT*NODE_COUNT+3)/4,             // Depth of memory
    parameter ADDR_WIDTH            = $clog2(MEM_DEPTH)                        // Width of memory address
)(
    // Inputs
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    dijkstra_i_start,
    input  logic [NODE_WIDTH-1:0]   dijkstra_i_start_node,
    // input  logic [NODE_WIDTH-1:0]   dijkstra_i_end_node,
    // Outputs
    output logic                    dijkstra_o_done,
    output logic [NODE_WIDTH-1:0]   dijkstra_o_path_node,
    output logic                    dijkstra_o_path_node_valid,
    // Memory interface
    input  logic [MEM_WIDTH-1:0]    dijkstra_i_mem_data,
    output logic [ADDR_WIDTH-1:0]   dijkstra_o_mem_addr
);

    /*-------------------------------------------------------------------------
    // Parameters
    -------------------------------------------------------------------------*/
    // Queue size equals number of nodes since we might need to visit all nodes
    localparam QUEUE_SIZE    = NODE_COUNT;
    // Width needed to address the queue
    localparam PTR_WIDTH     = $clog2(QUEUE_SIZE);
    // 0xFF is used to indicate "no parent" since it's not a valid node index
    localparam PARENT_INIT_VAL = 8'hFF;

    // Maximum possible distance value - used to initialize distances
    localparam MAX_DISTANCE = 16'hFFFF;  // Using 16-bit for distances

    // FSM states for implementing Dijkstra's algorithm
    typedef enum logic [2:0] {
        IDLE,               // Wait for start signal
        DEQUEUE,           // Select next node to process
        CHECK_NEIGHBORS,    // Examine all neighbors of current node
        MIN_DISTANCE,      // Find the unvisited node with minimum distance
        SUCCESS,           // Target node found, prepare for path trace
        TRACE_PATH,        // Reconstruct path from end to start node
        TRACE_PATH_DONE    // Cleanup and wait for next operation
    } state_t;
    
    /*-------------------------------------------------------------------------
    // Key Algorithm Variables
    -------------------------------------------------------------------------*/
    state_t cur_state, next_state;

    // Core algorithm variables
    logic [NODE_WIDTH-1:0] current_node;        // Node being processed
    logic [NODE_WIDTH-1:0] end_node;        // Node being processed
    logic [NODE_WIDTH-1:0] neighbor_counter;    // Used to iterate through neighbors
    logic [NODE_WIDTH-1:0] i;                   // General purpose counter
    logic [NODE_WIDTH-1:0] parent [NODE_COUNT-1:0];  // Stores parent of each node for path reconstruction

    // Path tracing variables
    logic [$clog2(NODE_COUNT)-1:0] trace_idx;   // Index for path reconstruction

    // Memory interface variables for reading adjacency matrix
    logic [1:0] byte_sel;                       // Selects which byte of the 32-bit word to use
    logic [ADDR_WIDTH+2-1:0] full_addr;         // Complete memory address including byte selection
    
    // logic [NODE_WEIGHT_WIDTH-1:0] node_weight;  // Weight of current edge being examined
    logic [NODE_WEIGHT_WIDTH-1:0] node_weight [3:0];  // Weight of current edge being examined
    
    // Distance tracking for Dijkstra's algorithm
    logic [15:0] distances [NODE_COUNT-1:0];    // Stores shortest known distance to each node
    logic [NODE_WIDTH-1:0] min_distance_node;   // Node with current minimum distance
    logic [15:0] min_distance;                  // Current minimum distance value

    // logic [15:0] temp_distance;                 // Used for distance calculations
    logic [15:0] temp_distance [3:0];           // Used for distance calculations

    // Track which nodes have been fully processed
    logic [NODE_COUNT-1:0] visited;             // Bit vector of visited nodes


/*-------------------------------------------------------------------------
    // FSM State Transition
    -------------------------------------------------------------------------*/
    always_ff @(posedge clk) begin
        if (rst) begin
            cur_state <= IDLE;
        end else begin
            cur_state <= next_state;
        end
    end

	
    /*-------------------------------------------------------------------------
    // FSM Data Processing - Core Dijkstra's Algorithm Implementation
    -------------------------------------------------------------------------*/
    always_ff @(posedge clk) begin
        if (rst) begin
            neighbor_counter <= '0;
            current_node <= '0;
            dijkstra_o_done <= 0;
            dijkstra_o_path_node <= PARENT_INIT_VAL;
            dijkstra_o_path_node_valid <= 0;
            trace_idx <= '0;
            for (int i = 0; i < NODE_COUNT; i++) begin
                parent[i] <= PARENT_INIT_VAL;
                distances[i] <= MAX_DISTANCE;
            end
            visited <= '0;
            min_distance <= MAX_DISTANCE;
            min_distance_node <= '0;
            i <= '0;
        end else begin
            
            case (cur_state)
                IDLE: begin
                    if (dijkstra_i_start) begin
                        // Initialize all distances to infinity (MAX_DISTANCE) except start node (distance = 0)
                        // Initialize all parents to invalid except start node
                        for (int i = 0; i < NODE_COUNT; i++) begin
                            distances[i] <= MAX_DISTANCE;
                            parent[i] <= PARENT_INIT_VAL;
                        end
                        distances[dijkstra_i_start_node] <= 0;
                        parent[dijkstra_i_start_node] <= dijkstra_i_start_node;
                        dijkstra_o_done <= 0;
                        current_node <= dijkstra_i_start_node;
                        neighbor_counter <= '0;
                        visited <= '0;
                        min_distance <= MAX_DISTANCE;
                        min_distance_node <= dijkstra_i_start_node;
                        i <= '0;
                        end_node <= dijkstra_i_start_node + 1;
                    end
                end
                
                DEQUEUE: begin
                    // Mark current node as visited and prepare to process its neighbors
                    // Reset minimum distance tracking for next iteration
                    visited[current_node] <= 1;
                    neighbor_counter <= '0;
                    current_node <= min_distance_node;
                    min_distance <= MAX_DISTANCE;
                    min_distance_node <= '0;
                    i <= '0;
                end
                
                CHECK_NEIGHBORS: begin
                    // For each neighbor:
                    // 1. Check if there's an edge (weight != 0) and node is unvisited
                    // 2. Calculate potential new distance through current node
                    // 3. Update distance and parent if new path is shorter
					//genvar j;
                    //generate
                        for(int j = 0; j < 4; j++) begin
                            if (node_weight[j] != 0 && !visited[neighbor_counter+j]) begin
                                if (temp_distance[j] < distances[neighbor_counter+j]) begin
                                    distances[neighbor_counter+j] <= temp_distance[j];
                                    parent[neighbor_counter+j] <= current_node;
                                end
                            end
                        end
                    //endgenerate
                    neighbor_counter <= neighbor_counter + 4;
                end

                MIN_DISTANCE: begin
                    // Find the unvisited node with the smallest distance
                    // This node will be processed next
                    if (!visited[i]) begin
                        if (distances[i] < min_distance) begin
                            min_distance <= distances[i];
                            min_distance_node <= i;
                        end
                    end
                    i <= i + 1;
                end
                
                SUCCESS: begin
                    dijkstra_o_path_node <= end_node;
                    dijkstra_o_path_node_valid <= 1;
                    trace_idx <= '0;
                    // dijkstra_o_done <= 0;
                end
                
                TRACE_PATH: begin
                    // Continue tracing back through parent nodes until we reach the start node
                    // or hit the maximum possible path length (NODE_COUNT)
                    if (dijkstra_o_path_node != dijkstra_i_start_node && trace_idx < NODE_COUNT) begin
                        // Output the parent of the current node and continue tracing
                        dijkstra_o_path_node <= parent[dijkstra_o_path_node];
                        dijkstra_o_path_node_valid <= 1;
                        trace_idx <= trace_idx + 1;
                    end else if (dijkstra_o_path_node == dijkstra_i_start_node || trace_idx == NODE_COUNT-1) begin
                        // Path tracing complete - either reached start node or max path length
                        if (end_node == NODE_COUNT-1) begin
                            dijkstra_o_done <= 1;
                            dijkstra_o_path_node <= PARENT_INIT_VAL;
                        end
                            dijkstra_o_path_node_valid <= 0;
                        // end else begin
                            end_node <= end_node +1;
                        //     dijkstra_o_path_node <= end_node+1;
                        //     dijkstra_o_path_node_valid <= 1;
                        //     trace_idx <= '0;
                        //     dijkstra_o_done <= 0;
                        // end
                    end
                end

                TRACE_PATH_DONE: begin
                    // Reset all algorithm state variables to prepare for next run
                    neighbor_counter <= '0;
                    current_node <= '0;
                    end_node <= '0;
                    dijkstra_o_path_node <= PARENT_INIT_VAL;
                    dijkstra_o_path_node_valid <= 0;
                    trace_idx <= '0;
                    for (int i = 0; i < NODE_COUNT; i++) begin
                        distances[i] <= MAX_DISTANCE;
                        parent[i] <= PARENT_INIT_VAL;
                    end
                    visited <= '0;
                    // Keep done signal high until start is deasserted
                    // This ensures proper handshaking with the host
                    if (!dijkstra_i_start) begin
                        dijkstra_o_done <= 0;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = cur_state;
        
        case (cur_state)
            IDLE: begin
                if (dijkstra_i_start) begin
                    // if (dijkstra_i_start_node == dijkstra_i_end_node) 
                    //     next_state = SUCCESS;
                    // else 
                        next_state = CHECK_NEIGHBORS;
                end
                // $display("dijkstra_i_start_node = %d, dijkstra_i_end_node = %d",dijkstra_i_start_node, dijkstra_i_end_node);
            end
            
            DEQUEUE: begin
                next_state = CHECK_NEIGHBORS;
            end
            
            CHECK_NEIGHBORS: begin
                // if (current_node == dijkstra_i_end_node) begin
                if (visited == 16'hFFFF) begin
                    next_state = SUCCESS;
                end else if (neighbor_counter == NODE_COUNT-4) begin
                    next_state = MIN_DISTANCE;
                end
				//$display("next_state = %d, neighbour counter = %d",next_state, neighbor_counter);
            end

            MIN_DISTANCE: begin
                if (i == NODE_COUNT-1) begin
                    next_state = DEQUEUE;
                end
            end
            
            SUCCESS: begin
                next_state = TRACE_PATH;
            end
            
            TRACE_PATH: begin
                // $display("end_node = %d, dijkstra_o_path_node = %d",end_node,dijkstra_o_path_node);
                if (dijkstra_o_path_node == dijkstra_i_start_node || trace_idx == NODE_COUNT-1) begin
                    if (end_node == NODE_COUNT-1) begin
                        next_state = TRACE_PATH_DONE;
                    end else begin
                        next_state = SUCCESS;
                    end
                end
            end
            
            TRACE_PATH_DONE: begin
                if (!dijkstra_i_start) begin
                    next_state = IDLE;
                end else begin
                    next_state = TRACE_PATH_DONE;
                end
                 
            end

            default: next_state = IDLE;
        endcase
    end
    
    /*-------------------------------------------------------------------------
    // Memory address and byte selection generation
    -------------------------------------------------------------------------*/
    always_comb begin
        if (cur_state == CHECK_NEIGHBORS) begin
            // Calculate full linear address
            full_addr = current_node * NODE_COUNT + neighbor_counter;
            
            // Split into word address and byte select
            dijkstra_o_mem_addr = full_addr[ADDR_WIDTH+2-1:2];  // Word address
            byte_sel = full_addr[1:0];               // Byte select
        end else begin
            dijkstra_o_mem_addr = '0;
            byte_sel = '0;
        end
    end

    /*-------------------------------------------------------------------------
    // Temporary distance Update
    -------------------------------------------------------------------------*/

    /*always_comb begin
        genvar j;
        generate
            for(j = 0; j < 4; j++) begin
                
            end
        endgenerate
    end
	*/
    // Byte selection: since the memory is 32-bit wide, we need to select the correct byte of the node weight
    // ** CAUTION: NEED TO BE UPDATED WHEN MEM_WIDTH OR NODE_WEIGHT_WIDTH IS CHANGED **

    genvar j;
    generate
            for(j = 0; j < 4; j++) begin
				always_comb begin
					node_weight[j] = dijkstra_i_mem_data[((j+1)*NODE_WEIGHT_WIDTH)-1:(j*NODE_WEIGHT_WIDTH)];
					temp_distance[j] = distances[current_node] + node_weight[j];
				end
            end
    endgenerate
	
	
endmodule
