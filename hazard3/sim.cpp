#include <verilated.h> // Defines common routines
#include "Vm_topsim.h" // From Verilating "top.v"

Vm_topsim *top;           // Instantiation of module
vluint64_t main_time = 0; // Current simulation time
                          // This is a 64-bit integer to reduce wrap over issues and
                          // allow modulus. You can also use a double, if you wish.

double sc_time_stamp () { // Called by $time in Verilog
    return main_time;     // converts to double, to match
                          // what SystemC does
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv); // Remember args
    top = new Vm_topsim;                // Create instance

    // register
    uint32_t clk   = 0; 

    // vcd
    Verilated::traceEverOn(true);

    while (!Verilated::gotFinish()) {
        if ((main_time % 5) == 0) {
            clk = clk ? 0 : 1;
        }

        // Set some inputs
        top->clk   = clk;

        top->eval(); // Evaluate model
        main_time++; // Time passes...
    }
    top->final(); // Done simulating
    delete top;
}
