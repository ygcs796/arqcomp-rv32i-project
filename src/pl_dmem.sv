// =============================================================================
// pl_dmem.sv
// Memoria de dados -- RV32I pipelined
//
// Capacidade : 256 palavras x 32 bits = 1 KB
// Init file  : data.mif   (sintese Quartus)
//              data.hex   (simulacao ModelSim via $readmemh)
//
// Leitura  : assincrona (combinatorial) -- disponivel no estagio MEM
// Escrita  : sincrona (posedge clk, gated por MemWrite & ~mmio_sel)
// Endereco : alu_result[9:2]  (endereco de palavra de 8 bits)
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [7:0]  addr,
    input  logic [31:0] WriteData,
    input  logic [2:0]  funct3,
    output logic [31:0] ReadData
);

    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    //STORES
    always@(posedge clk) begin
        if (MemWrite) begin
            case (funct3)
                3'h00: ram[addr][7:0] <= WriteData[7:0];   // SB
                3'h01: ram[addr][15:0] <= WriteData[15:0]; // SH
                3'h02: ram[addr] <= WriteData;             // SW
                default: ram[addr] <= WriteData;
            endcase
        end
    end

    //LOADS
    always_comb begin
        case (funct3)
            3'd00:   ReadData = {{24{ram[addr][7]}}, ram[addr][7:0]};   //LB
            3'd04:   ReadData = {24'b0, ram[addr][7:0]};              //LBU
            3'd01:   ReadData = {{16{ram[addr][15]}}, ram[addr][15:0]}; //LH
            3'd05:   ReadData = {16'b0, ram[addr][15:0]};             //LHU
            3'd02:   ReadData = ram[addr];                            //LW
            default: ReadData = ram[addr];
        endcase
    end

endmodule
