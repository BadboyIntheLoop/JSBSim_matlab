#include <mex.h>

void mexFunction(int nlhs, mxArray *plhs[], /* Output variables */
                 int nrhs, const mxArray *prhs[]) /* Input variables */
{
    mexPrintf("Hello, world!\n"); /* Do something interesting */
    mexEvalString("x = linspace(0,5); for k = 1:200, plot(x, cos(x+k/20)); drawnow; end");
    return;
}
