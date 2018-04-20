import numpy as np
import sys

#----------------------------------
commentstr = '#'
if len(sys.argv) >= 2:
    datafile = sys.argv[1]
if len(sys.argv) == 3:
    commentstr = sys.argv[2]
else:
    print("usage: python {} <edgelist file> [commentchar]".format(sys.argv[0]))
    sys.exit(1)
#---------------------------------------

g = np.loadtxt(datafile, dtype=str, comments=commentstr)	#read graph

rename={}
new=0

for i in range(0,len(g)):
	if g[i][0] not in rename:
		rename[g[i][0]]=new
		new=new+1
	if g[i][1] not in rename:
		rename[g[i][1]]=new
		new=new+1

for i in range(0,len(g)):
	g[i][0]=rename[g[i][0]]
	g[i][1]=rename[g[i][1]]

#G=nx.from_edgelist(g)			#convert to networkx
#nx.write_edgelist(G, "new_graph.txt" ,data = False) #write to file
with open('new_graph.txt', 'w') as file:
    file.writelines('\t'.join(str(j) for j in i) + '\n' for i in g)

