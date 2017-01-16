% GNU Octave Script
% Prepare to compare and run performance analysis.
% Must be run in the graph500-2.1.4 reference implementation directory
% Code taken from graph500-2.1.4/octave
SCALE = 10;
edgefactor = 16;
NBFS = 64;
rand("seed", 103);
ij = kronecker_generator (SCALE, edgefactor);
filename = sprintf ('kron-%d-%d.el',SCALE,edgefactor);
dlmwrite (filename, ij', ' ')
G = kernel_1 (ij);
N = size (G, 1);
coldeg = full (gpstats (G));
search_key = randperm (N);
search_key(coldeg(search_key) == 0) = [];
if length (search_key) > NBFS,
  search_key = search_key(1:NBFS);
else
  NBFS = length (search_key);
end
search_key = search_key - 1;  
dlmwrite (sprintf ('kron-%d-%d.roots',SCALE,edgefactor), search_key, ' ')
